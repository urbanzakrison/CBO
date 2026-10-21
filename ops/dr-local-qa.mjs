// Destructive restore drill ONLY in the fixed, ephemeral loopback CI stack.
// No hosted export path; no production data; no backup artifacts uploaded.
import {createClient} from '@supabase/supabase-js';
import pg from 'pg';
import assert from 'node:assert/strict';
import {readFile,writeFile,mkdtemp,mkdir,chmod,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {randomBytes} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {crypt,manifest,verify,sha256} from './dr-bundle.mjs';
const container='supabase_db_cbo-winter-v2-qa';
const info=JSON.parse(await readFile(process.env.CBO_DR_LOCAL_STATUS_FILE,'utf8'));
const api=info.API_URL,dburl=info.DB_URL,anon=info.ANON_KEY,service=info.SERVICE_ROLE_KEY;
const au=new URL(api),du=new URL(dburl);
if(process.env.GITHUB_ACTIONS!=='true'||process.env.GITHUB_EVENT_NAME!=='pull_request'||au.origin!=='http://127.0.0.1:54321'||du.hostname!=='127.0.0.1'||du.port!=='54322'||du.pathname!=='/postgres')throw Error('REFUSING_NON_ISOLATED_TARGET');
for(const secret of [anon,service]){assert.ok(secret);console.log('::add-mask::'+secret);}
function docker(args,input){
 const result=spawnSync('docker',['exec','-i',container,...args],{input,encoding:null,maxBuffer:64*1024*1024,timeout:60000});
 if(result.status!==0){
  const error=result.stderr?.toString()||'';
  // Whitelisted categories only; SQL/COPY detail and user values never reach logs.
  const code=/permission denied|must be superuser/i.test(error)?'PG_PERMISSION':/foreign key/i.test(error)?'PG_FOREIGN_KEY':/already exists/i.test(error)?'PG_OBJECT_EXISTS':'PG_COMMAND';
  throw Error(code);
 }return result.stdout;
}
const inspect=spawnSync('docker',['inspect','--format','{{.Name}}',container],{encoding:'utf8'});
assert.equal(inspect.stdout.trim(),'/'+container);
const make=key=>createClient(api,key,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
const adminApi=make(service),anonymous=make(anon),accounts=[];
const db=new pg.Client({connectionString:dburl});await db.connect();
const dir=await mkdtemp(join(tmpdir(),'cbo-dr-synthetic-'));await chmod(dir,0o700);
const fixture=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const checked=async response=>{if(response.error)throw Error('SYNTHETIC_API_OPERATION_FAILED');return response.data;};
const rpc=async(client,name,args={})=>checked(await client.rpc(name,args));
async function waitSchema(client){
 await db.query("notify pgrst,'reload schema'");
 for(let i=0;i<60;i++){const r=await client.rpc('cbo_seasons_status');if(!r.error)return;await new Promise(r=>setTimeout(r,250));}throw Error('LOCAL_SCHEMA_CACHE_TIMEOUT');
}
const bucket='cbo-clubhouse';
const policySql="create policy dr_member_images on storage.objects for all to authenticated using(bucket_id='cbo-clubhouse' and public.is_cbo_member()) with check(bucket_id='cbo-clubhouse' and public.is_cbo_member());";
let imagePath;
let stage='seed';
try{
 const schema=await fixture('tests/fixtures/schema.sql');await db.query(schema.slice(schema.indexOf('create table public.players')));
 await db.query('alter table players add column auth_user_id uuid references auth.users(id); alter table player_credentials add column golf_id text; alter table player_credentials add column code_hash text');
 await db.query(await fixture('tests/fixtures/production-functions.sql'));
 await db.query("create function public.is_cbo_admin() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.players where auth_user_id=auth.uid() and active and is_admin)$$");
 for(const table of ['players','seasons','season_players','rounds','round_results']){
  await db.query(`alter table public.${table} enable row level security; revoke all on public.${table} from public,anon; grant select on public.${table} to authenticated; create policy dr_members_read on public.${table} for select to authenticated using(public.is_cbo_member())`);
 }
 await db.query('alter table public.player_credentials enable row level security; revoke all on public.player_credentials from public,anon,authenticated');
 for(let i=0;i<5;i++){
  const email=`winter-dr-${i}@cbo.local`,password=randomBytes(32).toString('base64url');
  const created=await checked(await adminApi.auth.admin.createUser({email,password,email_confirm:true}));
  const client=make(anon);await checked(await client.auth.signInWithPassword({email,password}));
  const id=created.user.id;accounts.push({id,email,password,client});
  if(i<4){await db.query('insert into players(id,name,is_admin,auth_user_id,current_hcp_index) values($1,$2,$3,$1,$4)',[id,`Synthetic ${i}`,i===0,10+i]);await db.query('insert into player_credentials(player_id,auth_user_id,golf_id,code_hash) values($1,$1,$2,$3)',[id,`SYNTHETIC-${i}`,sha256(Buffer.from(password))]);}
 }
 const administrator=accounts[0].client,member=accounts[1].client,unknown=accounts[4].client;
 await db.query("insert into seasons(year,status) values(2026,'PÅGÅENDE')");
 await db.query(await fixture('22_season_management_v1.sql'));await waitSchema(administrator);
 const payload=accounts.slice(0,4).map((a,i)=>({name:`Synthetic ${i}`,shcp:10+i,net:34+i,gross:44+i}));
 assert.equal((await rpc(administrator,'cbo_publish_round',{p_round_no:1,p_played_on:'2026-05-01',p_course:'Synthetic',p_par9:36,p_recap:'Synthetic',p_results:payload})).ok,true);
 await rpc(administrator,'cbo_season_create',{p_year:2027});await rpc(administrator,'cbo_season_activate',{p_year:2027,p_expected_active_year:2026});
 const history=await rpc(administrator,'cbo_season_data',{p_year:2026});
 await db.query("create table public.cbo_clubhouse_messages(id uuid primary key,player_id uuid references players(id),body text,image_path text); create table public.cbo_clubhouse_reactions(message_id uuid references cbo_clubhouse_messages(id),player_id uuid references players(id),emoji text,primary key(message_id,player_id)); alter table cbo_clubhouse_messages enable row level security; alter table cbo_clubhouse_reactions enable row level security; grant select on cbo_clubhouse_messages,cbo_clubhouse_reactions to authenticated; create policy member_messages on cbo_clubhouse_messages for select to authenticated using(public.is_cbo_member()); create policy member_reactions on cbo_clubhouse_reactions for select to authenticated using(public.is_cbo_member());");
 await db.query(policySql);
 await checked(await adminApi.storage.createBucket(bucket,{public:false,allowedMimeTypes:['image/png']}));
 imagePath=accounts[1].id+'/synthetic.png';
 const image=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j5ioAAAAASUVORK5CYII=','base64');
 await checked(await member.storage.from(bucket).upload(imagePath,image,{contentType:'image/png'}));
 await db.query('insert into cbo_clubhouse_messages values($1,$2,$3,$4)',[accounts[0].id,accounts[1].id,'Synthetic private message',imagePath]);
 await db.query("insert into cbo_clubhouse_reactions values($1,$2,'👍')",[accounts[0].id,accounts[1].id]);
 async function state(){
  const names=['players','player_credentials','seasons','season_players','rounds','round_results','cbo_season_snapshots','cbo_clubhouse_messages','cbo_clubhouse_reactions'];
  const state={};for(const name of names)state[name]=(await db.query(`select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) rows from public.${name} t`)).rows[0].rows;
  state.catalog=(await db.query("select 'policy' kind,schemaname||'.'||tablename||'.'||policyname name,qual||coalesce(with_check,'') definition from pg_policies where schemaname='public' union all select 'function',proname,pg_get_functiondef(oid) from pg_proc where pronamespace='public'::regnamespace union all select 'index',indexname,indexdef from pg_indexes where schemaname='public' order by 1,2,3")).rows;
  return state;
 }
 stage='dump';const before=await state();
 const publicDump=docker(['pg_dump','-U','postgres','-d','postgres','-Fc','--schema=public','--no-owner']);
 const authUsers=docker(['pg_dump','-U','postgres','-d','postgres','-Fc','--data-only','--table=auth.users','--no-owner','--no-privileges']);
 const authIdentities=docker(['pg_dump','-U','postgres','-d','postgres','-Fc','--data-only','--table=auth.identities','--no-owner','--no-privileges']);
 const downloaded=Buffer.from(await (await checked(await member.storage.from(bucket).download(imagePath))).arrayBuffer());assert.equal(sha256(downloaded),sha256(image));
 const files={'public.dump':publicDump,'auth-users.dump':authUsers,'auth-identities.dump':authIdentities,'private-image.png':downloaded,'storage-policy.sql':Buffer.from(policySql),'bucket.json':Buffer.from(JSON.stringify({id:bucket,public:false,path:imagePath,contentType:'image/png'}))};
 const fileManifest=manifest(files);
 // Synthetic bundle only: bounded in-memory JSON, not the production streaming design.
 const plain=Buffer.from(JSON.stringify({manifest:fileManifest,files:Object.fromEntries(Object.entries(files).map(([n,b])=>[n,b.toString('base64')]))}));
 stage='encrypt';const home=join(dir,'gnupg');await mkdir(home,{mode:0o700});const key=randomBytes(32).toString('base64url');
 const encrypted=await crypt(plain,key,home);assert.ok(!encrypted.includes(Buffer.from(accounts[0].email)));
 const copyA=join(dir,'copy-a.gpg'),copyB=join(dir,'copy-b.gpg');
 await writeFile(copyA,encrypted,{mode:0o600,flag:'wx'});await writeFile(copyB,encrypted,{mode:0o600,flag:'wx'});
 assert.equal(sha256(await readFile(copyA)),sha256(await readFile(copyB)));
 const unsealed=JSON.parse((await crypt(await readFile(copyB),key,home,true)).toString());
 const restored=Object.fromEntries(Object.entries(unsealed.files).map(([n,b])=>[n,Buffer.from(b,'base64')]));verify(restored,unsealed.manifest);
 // Simulate loss: remove image and bucket through Storage API, drop application schema,
 // remove all test Auth users. Platform-managed schemas remain installed.
 stage='erase';await checked(await adminApi.storage.from(bucket).remove([imagePath]));await checked(await adminApi.storage.deleteBucket(bucket));
 await db.query('drop schema public cascade; truncate auth.users cascade');
 assert.equal((await db.query('select count(*)::int n from auth.users')).rows[0].n,0);
 stage='restore-auth-users';docker(['pg_restore','-U','postgres','-d','postgres','--exit-on-error','--single-transaction','--data-only'],restored['auth-users.dump']);
 stage='restore-auth-identities';docker(['pg_restore','-U','postgres','-d','postgres','--exit-on-error','--single-transaction','--data-only'],restored['auth-identities.dump']);
 stage='restore-public';docker(['pg_restore','-U','postgres','-d','postgres','--exit-on-error','--single-transaction','--no-owner'],restored['public.dump']);
 await db.query(restored['storage-policy.sql'].toString());await waitSchema(administrator);
 // Old sessions are intentionally invalidated. Password login must work from restored hashes.
 stage='restore-login';for(const account of accounts){account.client=make(anon);await checked(await account.client.auth.signInWithPassword({email:account.email,password:account.password}));}
 const recoveredMember=accounts[1].client,recoveredUnknown=accounts[4].client;
 stage='restore-storage';const meta=JSON.parse(restored['bucket.json']);await checked(await adminApi.storage.createBucket(meta.id,{public:meta.public,allowedMimeTypes:[meta.contentType]}));
 await checked(await recoveredMember.storage.from(meta.id).upload(meta.path,restored['private-image.png'],{contentType:meta.contentType}));
 stage='verify';assert.deepEqual(await state(),before);
 assert.deepEqual(await rpc(accounts[0].client,'cbo_season_data',{p_year:2026}),history);
 assert.equal((await rpc(accounts[0].client,'cbo_seasons_status')).active_year,2027);
 const privateRead=Buffer.from(await (await checked(await recoveredMember.storage.from(bucket).download(imagePath))).arrayBuffer());assert.equal(sha256(privateRead),sha256(image));
 assert.ok((await anonymous.storage.from(bucket).download(imagePath)).error);assert.ok((await recoveredUnknown.storage.from(bucket).download(imagePath)).error);
 await db.query("notify pgrst,'reload schema'");await new Promise(r=>setTimeout(r,1000));
 assert.equal((await checked(await recoveredMember.from('cbo_clubhouse_messages').select('id'))).length,1);
 assert.equal((await checked(await recoveredUnknown.from('cbo_clubhouse_messages').select('id'))).length,0);
 assert.ok((await recoveredMember.rpc('cbo_season_create',{p_year:2028})).error);
 assert.ok((await recoveredMember.from('player_credentials').select('*')).error);
 assert.ok((await anonymous.from('player_credentials').select('*')).error);
 assert.equal((await checked(await recoveredUnknown.from('players').select('id'))).length,0);
 console.log(JSON.stringify({status:'PASS',environment:'ephemeral loopback Supabase; synthetic only',checks:['real pg_dump/pg_restore schema and data','Auth users and identities restored; five new password logins','membership and credential-hash relations identical','2026 snapshot, champion, rounds, results and six-category payload identical','2027 active unchanged','public functions, RLS policies and indexes identical','clubhouse messages/reactions/image references identical','private PNG bytes restored via Storage API','member can read; anonymous and unknown cannot','member cannot create season','GnuPG encryption; manifest; two ciphertext copies equal'],limitations:['not a production backup','same platform stack, application schema recreated; not a second hosted project','synthetic users+identities only, no MFA/SSO/Vault/production secrets','two local test copies, not independent offsite copies','no real provider alert or email receipt'],productionAccess:false}));
}catch(error){
 const category=['PG_PERMISSION','PG_FOREIGN_KEY','PG_OBJECT_EXISTS','PG_COMMAND'].includes(error.message)?error.message:'CHECK_FAILED';
 console.error('FAIL ISOLATED_DR_QA stage='+stage+' category='+category+' (details suppressed to protect credentials and dump contents)');process.exitCode=1;
}finally{
 await db.end();await rm(dir,{recursive:true,force:true});
}
