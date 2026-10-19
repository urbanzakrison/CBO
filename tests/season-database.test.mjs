import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
const ids=Array.from({length:6},(_,i)=>`00000000-0000-0000-0000-${String(i+1).padStart(12,'0')}`);
async function setup(){
 const db=new PGlite();
 await db.exec(await read('./fixtures/schema.sql'));
 await db.exec(await read('./fixtures/production-functions.sql'));
 await db.exec(await read('../22_season_management_v1.sql'));
 for(let i=0;i<6;i++){
  await db.query('insert into auth.users values($1)',[ids[i]]);
  await db.query('insert into players(id,name,is_admin,is_test,current_hcp_index) values($1,$2,$3,$4,$5)',[ids[i],`Player ${i}`,i===0,i===5,10+i]);
  await db.query('insert into player_credentials values($1,$1)',[ids[i]]);
 }
 await db.exec("insert into seasons(year,status) values(2025,'AVSLUTAD'),(2026,'PÅGÅENDE');");
 await as(db,ids[0]);return db;
}
async function as(db,id){await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id||'']);}
async function rpc(db,name,args=[]){const r=await db.query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) result`,args);return r.rows[0].result;}
const payload=JSON.stringify(ids.slice(0,4).map((_,i)=>({name:`Player ${i}`,net:35+i,gross:45+i,shcp:10+i})));
async function publish(db,no,date){return rpc(db,'cbo_publish_round',[no,date,'Test course',36,'Test recap',payload]);}

test('create, activate, preserve history, publish and repeat in 2028',async()=>{
 const db=await setup();
 try{
  const old=await publish(db,1,'2026-05-01');assert.equal(old.ok,true);
  const before=(await db.query('select * from round_results order by player_id')).rows;
  const live=await rpc(db,'cbo_season_data',[2026]);
  assert.equal((await rpc(db,'cbo_season_create',[2027])).status,'FÖRBEREDD');
  assert.equal((await rpc(db,'cbo_seasons_status')).active_year,2026);
  assert.equal((await db.query('select count(*)::int n from season_players')).rows[0].n,5);
  await assert.rejects(rpc(db,'cbo_season_create',[2027]),/finns redan/);
  await assert.rejects(rpc(db,'cbo_season_create',[2030]),/Nästa/);
  assert.deepEqual((await rpc(db,'cbo_season_data',[2027])).results,[]);
  assert.equal((await publish(db,1,'2027-05-01')).ok,false);
  await assert.rejects(rpc(db,'cbo_season_activate',[2027,2025]),/ändrats/);
  assert.equal((await rpc(db,'cbo_seasons_status')).active_year,2026);
  assert.equal((await rpc(db,'cbo_season_activate',[2027,2026])).active_year,2027);
  await assert.rejects(rpc(db,'cbo_season_activate',[2027,2026]),/ändrats/);
  assert.deepEqual(await rpc(db,'cbo_season_data',[2026]),live);
  assert.deepEqual((await db.query('select * from round_results order by player_id')).rows,before);
  assert.equal((await db.query('select official_champion_player_id id from seasons where year=2026')).rows[0].id,ids[0]);
  assert.deepEqual((await rpc(db,'cbo_season_data',[2027])).rounds,[]);
  assert.equal((await publish(db,1,'2027-05-01')).ok,true);
  assert.equal((await publish(db,1,'2027-05-02')).ok,false);
  assert.equal((await publish(db,2,'2027-05-01')).ok,false);
  assert.equal((await publish(db,2,'2026-05-02')).ok,false);
  await db.exec('update players set current_hcp_index=50');
  assert.deepEqual(await rpc(db,'cbo_season_data',[2026]),live);
  assert.equal((await rpc(db,'cbo_season_create',[2028])).status,'FÖRBEREDD');
  assert.equal((await rpc(db,'cbo_season_activate',[2028,2027])).active_year,2028);
  assert.equal((await publish(db,1,'2028-05-01')).ok,true);
  await assert.rejects(db.exec("update seasons set status='PÅGÅENDE' where year=2026"),/unique/);
 }finally{await db.close();}
});

test('non-admin, unknown and anonymous callers cannot mutate seasons',async()=>{
 const db=await setup();
 try{
  await rpc(db,'cbo_season_create',[2027]);
  await db.exec('set role authenticated');
  for(const id of [ids[1],'99999999-9999-9999-9999-999999999999',null]){
   await as(db,id);
   await assert.rejects(rpc(db,'cbo_season_create',[2028]),/Adminbehörighet/);
   await assert.rejects(rpc(db,'cbo_season_activate',[2027,2026]),/Adminbehörighet/);
   if(id===ids[1])assert.equal((await rpc(db,'cbo_seasons_status')).active_year,2026);
   else await assert.rejects(rpc(db,'cbo_seasons_status'),/medlemskap/);
   await assert.rejects(db.exec('select * from cbo_season_snapshots'),/permission denied/);
  }
  await db.exec('reset role; set role anon');
  await assert.rejects(rpc(db,'cbo_seasons_status'),/permission denied/);
 }finally{await db.close();}
});

test('activation rolls back completely if snapshot write fails',async()=>{
 const db=await setup();
 try{
  await publish(db,1,'2026-05-01');await rpc(db,'cbo_season_create',[2027]);
  await db.exec("alter table cbo_season_snapshots add constraint fail_test check (false)");
  await assert.rejects(rpc(db,'cbo_season_activate',[2027,2026]),/fail_test/);
  assert.equal((await rpc(db,'cbo_seasons_status')).active_year,2026);
  assert.equal((await db.query("select status from seasons where year=2027")).rows[0].status,'FÖRBEREDD');
  assert.equal((await db.query('select count(*)::int n from cbo_season_snapshots')).rows[0].n,0);
 }finally{await db.close();}
});


test('existing champion is preserved; inactive admin denied; invalid year rejected',async()=>{
 const db=await setup();
 try{
  await assert.rejects(rpc(db,'cbo_season_create',[1800]),/Ogiltigt/);
  await assert.rejects(rpc(db,'cbo_season_create',[null]),/Ogiltigt/);
  await publish(db,1,'2026-05-01');
  await db.query("update seasons set official_champion_player_id=$1,official_champion_points=70,champion_metric='Manual verified',champion_value=70 where year=2026",[ids[1]]);
  await rpc(db,'cbo_season_create',[2027]);
  await db.query('update players set active=false where id=$1',[ids[0]]);
  await assert.rejects(rpc(db,'cbo_season_activate',[2027,2026]),/Adminbehörighet/);
  await db.query('update players set active=true where id=$1',[ids[0]]);
  await rpc(db,'cbo_season_activate',[2027,2026]);
  const row=(await db.query('select official_champion_player_id,official_champion_points,champion_metric from seasons where year=2026')).rows[0];
  assert.deepEqual(row,{official_champion_player_id:ids[1],official_champion_points:'70',champion_metric:'Manual verified'});
  const future=await rpc(db,'cbo_season_data',[2027]);
  assert.equal(future.players.some(p=>p.id===ids[5]),false);
 }finally{await db.close();}
});

test('rollback restores release before use and refuses data-destructive rollback',async()=>{
 const db=await setup();
 try{
  await db.exec(await read('../23_season_management_rollback.sql'));
  assert.equal((await db.query("select to_regprocedure('public.cbo_season_create(integer)') as f")).rows[0].f,null);
  assert.equal((await publish(db,1,'2026-05-01')).ok,true);
 }finally{await db.close();}
 const used=await setup();
 try{
  await rpc(used,'cbo_season_create',[2027]);
  await assert.rejects(used.exec(await read('../23_season_management_rollback.sql')),/Rollback stoppad/);
  await used.exec('rollback');
  assert.equal((await rpc(used,'cbo_seasons_status')).active_year,2026);
 }finally{await used.close();}
});


test('existing champion with incomplete metadata stays exact',async()=>{
 const db=await setup();
 try{
  await publish(db,1,'2026-05-01');
  await db.query('update seasons set official_champion_player_id=$1 where year=2026',[ids[1]]);
  const before=(await db.query('select official_champion_player_id,official_champion_points,champion_metric,champion_value,champion_note from seasons where year=2026')).rows[0];
  await rpc(db,'cbo_season_create',[2027]);await rpc(db,'cbo_season_activate',[2027,2026]);
  assert.deepEqual((await db.query('select official_champion_player_id,official_champion_points,champion_metric,champion_value,champion_note from seasons where year=2026')).rows[0],before);
 }finally{await db.close();}
});

test('unresolved champion tie blocks activation atomically; lower HCP resolves it',async()=>{
 const db=await setup();
 try{
  await publish(db,1,'2026-05-01');
  await db.exec('update round_results set points=4,playing_hcp=10; update players set current_hcp_index=10');
  await rpc(db,'cbo_season_create',[2027]);
  await assert.rejects(rpc(db,'cbo_season_activate',[2027,2026]),/Delad förstaplats/);
  assert.equal((await rpc(db,'cbo_seasons_status')).active_year,2026);
  assert.equal((await db.query('select count(*)::int n from cbo_season_snapshots')).rows[0].n,0);
  await db.query('update round_results set playing_hcp=9 where player_id=$1',[ids[1]]);
  await rpc(db,'cbo_season_activate',[2027,2026]);
  assert.equal((await db.query('select official_champion_player_id id from seasons where year=2026')).rows[0].id,ids[1]);
 }finally{await db.close();}
});
