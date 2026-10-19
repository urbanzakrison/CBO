// Real PostgreSQL multi-connection QA. Only an ephemeral loopback cbo_qa database is accepted.
import pg from 'pg';
import assert from 'node:assert/strict';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
const url=process.env.CBO_QA_DATABASE_URL;
if(!url)throw Error('CBO_QA_DATABASE_URL is required.');
const target=new URL(url);
if(!['127.0.0.1','localhost','[::1]'].includes(target.hostname)||target.pathname!=='/cbo_qa')throw Error('Refusing non-loopback/non-cbo_qa database.');
const clients=[];const read=f=>readFile(new URL('../'+f,import.meta.url),'utf8');
async function connect(){const c=new pg.Client({connectionString:url});await c.connect();clients.push(c);await c.query("set statement_timeout='15s'; set lock_timeout='10s'");return c;}
const observer=await connect(),a=await connect(),b=await connect();
const aid=(await a.query('select pg_backend_pid() id')).rows[0].id;
const bid=(await b.query('select pg_backend_pid() id')).rows[0].id;
assert.notEqual(aid,bid);
const ids=Array.from({length:5},(_,i)=>`00000000-0000-0000-0000-${String(i+1).padStart(12,'0')}`);
const args=(no,date)=>[no,date,'QA course',36,'QA only',JSON.stringify(ids.slice(0,4).map((_,i)=>({name:`QA ${i}`,shcp:10+i,net:35+i,gross:45+i})))];
const pub=(c,no,date)=>c.query('select cbo_publish_round($1,$2,$3,$4,$5,$6) value',args(no,date));
const create=c=>c.query('select cbo_season_create(2027) value');
const activate=c=>c.query('select cbo_season_activate(2027,2026) value');
const value=r=>r.rows[0].value;
const pending=p=>p.then(result=>({result}),error=>({error}));
const results=[];
async function blocked(pid){
 const deadline=Date.now()+7000;
 while(Date.now()<deadline){
  const r=await observer.query("select count(*)::int n from pg_locks where pid=$1 and locktype='advisory' and not granted",[pid]);
  if(r.rows[0].n)return;
  await new Promise(r=>setTimeout(r,25));
 }
 throw Error(`Connection ${pid} did not wait on the lifecycle advisory lock`);
}
async function assertActive(year){const rows=(await observer.query("select year from seasons where status='PÅGÅENDE'")).rows;assert.deepEqual(rows,[{year}]);}
async function reset(){
 for(const c of [a,b])await c.query('rollback; reset role');
 await observer.query('truncate cbo_season_snapshots,round_results,rounds,season_players,seasons,player_credentials,players,auth.users cascade');
 for(let i=0;i<ids.length;i++){
  await observer.query('insert into auth.users values($1)',[ids[i]]);
  await observer.query('insert into players(id,name,is_admin,current_hcp_index) values($1,$2,$3,$4)',[ids[i],`QA ${i}`,i===0,10+i]);
  await observer.query('insert into player_credentials values($1,$1)',[ids[i]]);
 }
 await observer.query("insert into seasons(year,status) values(2025,'AVSLUTAD'),(2026,'PÅGÅENDE')");
 for(const c of [observer,a,b])await c.query("select set_config('request.jwt.claim.sub',$1,false)",[ids[0]]);
 assert.equal(value(await pub(observer,1,'2026-05-01')).ok,true);
}
async function scenario(name,fn){await reset();await fn();results.push({name,status:'PASS'});console.log('PASS '+name);}
try{
 await observer.query(await read('tests/fixtures/schema.sql'));
 await observer.query(await read('tests/fixtures/production-functions.sql'));
 await observer.query(await read('22_season_management_v1.sql'));
 await scenario('two concurrent creates: exactly one prepared season',async()=>{
  await a.query('begin');assert.equal(value(await create(a)).ok,true);
  const other=pending(create(b));await blocked(bid);await a.query('commit');
  assert.match((await other).error?.message||'',/finns redan/);
  assert.equal((await observer.query('select count(*)::int n from seasons where year=2027')).rows[0].n,1);await assertActive(2026);
 });
 await scenario('two concurrent activations: exactly one succeeds',async()=>{
  await create(observer);await a.query('begin');assert.equal(value(await activate(a)).active_year,2027);
  const other=pending(activate(b));await blocked(bid);await a.query('commit');
  assert.match((await other).error?.message||'',/ändrats/);await assertActive(2027);
  assert.equal((await observer.query('select count(*)::int n from cbo_season_snapshots')).rows[0].n,1);
 });
 await scenario('publication holds lock first: activation snapshot includes committed round',async()=>{
  await create(observer);await a.query('begin');assert.equal(value(await pub(a,2,'2026-06-01')).ok,true);
  const other=pending(activate(b));await blocked(bid);await a.query('commit');assert.equal(value((await other).result).active_year,2027);
  const snap=value(await observer.query('select cbo_season_data(2026) value'));
  assert.equal(snap.rounds.length,2);assert.equal(snap.results.length,8);await assertActive(2027);
 });
 await scenario('activation holds lock first: stale publication rejected without partial rows',async()=>{
  await create(observer);await a.query('begin');await activate(a);
  const other=pending(pub(b,2,'2026-06-01'));await blocked(bid);await a.query('commit');
  const reply=value((await other).result);assert.equal(reply.ok,false);assert.match(reply.error,/aktiva säsongen/);
  assert.equal((await observer.query('select count(*)::int n from rounds')).rows[0].n,1);
  assert.equal((await observer.query('select count(*)::int n from round_results')).rows[0].n,4);
  assert.equal(value(await pub(observer,1,'2027-05-01')).ok,true);await assertActive(2027);
 });
 await scenario('concurrent duplicate round number serialized and rejected',async()=>{
  await a.query('begin');assert.equal(value(await pub(a,2,'2026-06-01')).ok,true);
  const other=pending(pub(b,2,'2026-06-02'));await blocked(bid);await a.query('commit');
  const reply=value((await other).result);assert.equal(reply.ok,false);assert.match(reply.error,/Omgångsnumret/);
  assert.equal((await observer.query('select count(*)::int n from rounds')).rows[0].n,2);
 });
 await scenario('concurrent duplicate date serialized and rejected',async()=>{
  await a.query('begin');assert.equal(value(await pub(a,2,'2026-06-01')).ok,true);
  const other=pending(pub(b,3,'2026-06-01'));await blocked(bid);await a.query('commit');
  const reply=value((await other).result);assert.equal(reply.ok,false);assert.match(reply.error,/Datumet/);
  assert.equal((await observer.query('select count(*)::int n from rounds')).rows[0].n,2);
 });
 await scenario('rolled-back activation leaves no partial state or snapshot',async()=>{
  await create(observer);await a.query('begin');await activate(a);await a.query('rollback');await assertActive(2026);
  assert.equal((await observer.query('select count(*)::int n from cbo_season_snapshots')).rows[0].n,0);
  assert.equal((await observer.query('select status from seasons where year=2027')).rows[0].status,'FÖRBEREDD');
 });
 await scenario('ordinary role and anonymous EXECUTE restrictions',async()=>{
  await create(observer);await a.query('set role authenticated');await a.query("select set_config('request.jwt.claim.sub',$1,false)",[ids[1]]);
  await assert.rejects(create(a),/Adminbehörighet/);await assert.rejects(activate(a),/Adminbehörighet/);
  await assert.rejects(a.query('select * from cbo_season_snapshots'),/permission denied/);
  await a.query('reset role; set role anon');await assert.rejects(a.query('select cbo_seasons_status()'),/permission denied/);
  await a.query('reset role');await assertActive(2026);
 });
 const report={engine:(await observer.query('select version() value')).rows[0].value,sessionPids:[aid,bid],independentSessions:true,scope:'isolated PostgreSQL; synthetic identities; not Supabase Auth/hosted advisors',tests:results};
 await mkdir(new URL('../test-results/',import.meta.url),{recursive:true});await writeFile(new URL('../test-results/postgres-qa.json',import.meta.url),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
}finally{await Promise.allSettled(clients.map(c=>c.end()));}
