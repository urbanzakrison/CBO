// Free ephemeral local Supabase only. Refuses hosted APIs and unexpected DB ports.
import {createClient} from '@supabase/supabase-js';
import pg from 'pg';
import {chromium} from 'playwright';
import {createServer} from 'node:http';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
import {randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
const root=resolve(import.meta.dirname,'..');
const info=JSON.parse(await readFile(process.env.CBO_QA_LOCAL_STATUS_FILE,'utf8'));
const api=info.API_URL||info.api_url,dburl=info.DB_URL||info.db_url;
const anon=info.ANON_KEY||info.PUBLISHABLE_KEY,service=info.SERVICE_ROLE_KEY||info.SECRET_KEY;
if(!api||!dburl||!anon||!service)throw Error('Local CLI status lacks required API/DB/key fields; keys present: '+Object.keys(info).join(','));
const au=new URL(api),du=new URL(dburl);
if(!['127.0.0.1','localhost'].includes(au.hostname)||au.port!=='54321'||!['127.0.0.1','localhost'].includes(du.hostname)||du.port!=='54322')throw Error('Refusing non-local Supabase target.');
for(const secret of [service,anon])if(process.env.GITHUB_ACTIONS)console.log('::add-mask::'+secret);
const read=f=>readFile(resolve(root,f),'utf8');
const db=new pg.Client({connectionString:dburl});await db.connect();
const make=key=>createClient(api,key,{auth:{autoRefreshToken:false,persistSession:false,detectSessionInUrl:false}});
const administrator=make(service),accounts=[];
let browser,server;
async function rpc(client,name,args={}){const r=await client.rpc(name,args);if(r.error)throw Error(name+': '+r.error.message);return r.data;}
async function reloadSchema(){await db.query("notify pgrst,'reload schema'");}
async function waitRpc(client){const end=Date.now()+15000;while(Date.now()<end){const r=await client.rpc('cbo_seasons_status');if(!r.error)return;await new Promise(r=>setTimeout(r,250));}throw Error('Local PostgREST did not expose season RPCs');}
try{
 // Reuse only the ordinary-CBO public subset. Platform roles/auth are supplied by real local Supabase.
 const fixture=await read('tests/fixtures/schema.sql');
 await db.query(fixture.slice(fixture.indexOf('create table public.players')));
 await db.query('alter table players add column auth_user_id uuid references auth.users(id)');
 await db.query(await read('tests/fixtures/production-functions.sql'));
 await db.query("create function public.is_cbo_admin() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.players where auth_user_id=auth.uid() and active and is_admin)$$");
 for(const table of ['seasons','season_players','rounds','round_results']){
  await db.query(`alter table public.${table} enable row level security; revoke all on public.${table} from public,anon; grant select,insert,update,delete on public.${table} to authenticated; create policy "members read" on public.${table} for select to authenticated using(public.is_cbo_member()); create policy "admin writes" on public.${table} for all to authenticated using(public.is_cbo_admin()) with check(public.is_cbo_admin())`);
 }
 await db.query('revoke all on public.player_credentials from public,anon,authenticated');
 await db.query('alter table public.player_credentials enable row level security');
 await db.query("insert into seasons(year,status) values(2025,'AVSLUTAD'),(2026,'PÅGÅENDE')");
 for(let i=0;i<5;i++){
  const golf='990101'+String(901+i),email=golf+'@cbo.local',password=randomBytes(24).toString('base64url');
  const created=await administrator.auth.admin.createUser({email,password,email_confirm:true});if(created.error)throw created.error;
  const id=created.data.user.id,client=make(anon);const login=await client.auth.signInWithPassword({email,password});if(login.error)throw login.error;
  if(i<4){await db.query('insert into players(id,name,is_admin,auth_user_id,current_hcp_index) values($1,$2,$3,$1,$4)',[id,i===0?'QA Admin':`QA Member ${i}`,i===0,10+i]);await db.query('insert into player_credentials values($1,$1)',[id]);}
  accounts.push({id,client,email,password,golf});
 }
 const admin=accounts[0].client,member=accounts[1].client,unknown=accounts[4].client;
 const initialPayload=accounts.slice(0,4).map((p,i)=>({name:i===0?'QA Admin':`QA Member ${i}`,shcp:10+i,net:35+i,gross:45+i}));
 await reloadSchema();
 // Original publisher baseline before installation, actual admin JWT.
 for(let i=0;i<30;i++){const r=await admin.rpc('cbo_publish_round',{p_round_no:1,p_played_on:'2026-05-01',p_course:'QA Hamra',p_par9:36,p_recap:'QA 2026',p_results:initialPayload});if(!r.error){assert.equal(r.data.ok,true);break;}if(i===29)throw r.error;await new Promise(r=>setTimeout(r,250));}
 const before=await rpc(admin,'cbo_live_leaderboard_data',{p_year:2026});
 await db.query(await read('22_season_management_v1.sql'));await reloadSchema();await waitRpc(admin);
 const policies=(await db.query("select relname,relrowsecurity from pg_class where oid in ('public.seasons'::regclass,'public.season_players'::regclass,'public.rounds'::regclass,'public.round_results'::regclass,'public.cbo_season_snapshots'::regclass)")).rows;assert.ok(policies.every(r=>r.relrowsecurity));
 const functions=(await db.query("select proname,proconfig,has_function_privilege('anon',oid,'EXECUTE') anon_execute,has_function_privilege('authenticated',oid,'EXECUTE') member_execute from pg_proc where pronamespace='public'::regnamespace and proname in ('cbo_seasons_status','cbo_season_create','cbo_season_data','cbo_season_activate')")).rows;
 assert.equal(functions.length,4);for(const f of functions){assert.equal(f.anon_execute,false);assert.equal(f.member_execute,true);assert.ok(f.proconfig.some(c=>c==='search_path=""'||c==='search_path='));}
 assert.ok((await member.rpc('cbo_season_create',{p_year:2027})).error);
 assert.ok((await unknown.rpc('cbo_season_create',{p_year:2027})).error);
 assert.ok((await unknown.rpc('cbo_seasons_status')).error);
 assert.ok((await make(anon).rpc('cbo_seasons_status')).error);
 assert.ok((await member.from('seasons').insert({year:2040,status:'FÖRBEREDD'})).error);
 assert.ok((await member.from('cbo_season_snapshots').select('*')).error);
 // User-editable metadata must never elevate a member to admin.
 await member.auth.updateUser({data:{is_admin:true}});
 assert.ok((await member.rpc('cbo_season_create',{p_year:2027})).error);
 // Run the actual browser auth-client against real local Auth/PostgREST.
 const bundle=await read('node_modules/@supabase/supabase-js/dist/umd/supabase.js');
 server=createServer(async(req,res)=>{
  try{
   if(req.url==='/config.js'){res.setHeader('Content-Type','application/javascript');res.end(`window.CBO_SUPABASE_URL=${JSON.stringify(api)};window.CBO_SUPABASE_PUBLISHABLE_KEY=${JSON.stringify(anon)};`);return;}
   const path=resolve(root,'.'+new URL(req.url,'http://local').pathname.replace(/\/$/,'/index.html'));
   if(!path.startsWith(root+'/')){res.writeHead(403).end();return;}
   res.setHeader('Content-Type',({'.html':'text/html','.js':'application/javascript','.json':'application/json'})[extname(path)]||'text/plain');res.end(await readFile(path));
  }catch{res.writeHead(404).end();}
 });await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin=`http://127.0.0.1:${server.address().port}`;
 browser=await chromium.launch({headless:true});
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true,serviceWorkers:'block'});
 await context.route('**/*',route=>{
  const u=route.request().url();if(u.includes('cdn.jsdelivr.net/npm/@supabase/'))return route.fulfill({contentType:'application/javascript',body:bundle});
  if(!u.startsWith(origin+'/')&&!u.startsWith(api+'/'))return route.abort();return route.continue();
 });
 const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(origin);
 await page.locator('#loginGolfId').fill(accounts[0].golf);
 await page.locator('#loginCode').fill(accounts[0].password);
 await page.evaluate(()=>cboLogin());await page.waitForFunction(()=>window.CBO_LIVE_READY===true);
 assert.equal(await page.locator('#adminNavButton').isVisible(),true);
 await page.evaluate(()=>showPage('admin'));page.once('dialog',d=>d.accept());await page.locator('#newSeasonButton').click();
 await page.waitForFunction(()=>document.getElementById('seasonManagementStatus').textContent.includes('Verifierat: 2027'));
 assert.equal((await rpc(admin,'cbo_seasons_status')).active_year,2026);
 assert.equal(await page.locator('#seasonSelect option[value="2027"]').count(),0);
 page.on('dialog',d=>d.accept(d.type()==='prompt'?'AKTIVERA 2027':undefined));await page.locator('[data-activate-year="2027"]').click();
 await page.waitForFunction(()=>document.getElementById('seasonManagementStatus').textContent.includes('Verifierat: 2027 är PÅGÅENDE'));
 assert.equal((await rpc(admin,'cbo_seasons_status')).active_year,2027);
 assert.deepEqual(await rpc(admin,'cbo_season_data',{p_year:2026}),before);
 assert.ok((await member.rpc('cbo_season_activate',{p_year:2027,p_expected_active_year:2026})).error);
 await page.evaluate(()=>showPage('leaderboard'));assert.match(await page.locator('#leaderRows').innerText(),/Ingen publicerad/);
 const published=await rpc(admin,'cbo_publish_round',{p_round_no:1,p_played_on:'2027-05-01',p_course:'QA Hamra',p_par9:36,p_recap:'QA 2027',p_results:initialPayload});assert.equal(published.ok,true);
 assert.equal((await rpc(admin,'cbo_publish_round',{p_round_no:1,p_played_on:'2027-05-02',p_course:'QA Hamra',p_par9:36,p_recap:'',p_results:initialPayload})).ok,false);
 await page.evaluate(()=>CBO_LOAD_LIVE_LEADERBOARD());await page.evaluate(()=>showPage('rounds'));assert.equal(await page.evaluate(()=>rounds().length),1);
 await page.evaluate(()=>changeSeason('2026'));assert.equal(await page.evaluate(()=>rounds().length),1);
 await page.evaluate(()=>showPage('home'));
 const memberContext=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});
 await memberContext.route('**/*',route=>{const u=route.request().url();if(u.includes('cdn.jsdelivr.net/npm/@supabase/'))return route.fulfill({contentType:'application/javascript',body:bundle});if(!u.startsWith(origin+'/')&&!u.startsWith(api+'/'))return route.abort();return route.continue();});
 const memberPage=await memberContext.newPage();await memberPage.goto(origin);await memberPage.locator('#loginGolfId').fill(accounts[1].golf);await memberPage.locator('#loginCode').fill(accounts[1].password);await memberPage.evaluate(()=>cboLogin());await memberPage.waitForFunction(()=>window.CBO_LIVE_READY===true);assert.equal(await memberPage.locator('#adminNavButton').isVisible(),false);
 assert.deepEqual(errors,[]);
 const report={environment:'ephemeral local Supabase in free standard public GitHub runner',auth:'real independent admin/member/unknown Auth sessions and actual browser auth-client',checks:['admin/member login','DB authorization unaffected by member user_metadata','anonymous and unknown denied','RLS denies member table writes','snapshot table inaccessible','new RPC EXECUTE/search_path audited','prepare does not change active year','explicit UI activation','empty new leaderboard','round 1 in 2027','duplicate rejected','2026 payload identical','member admin UI hidden'],managedSecurityAdvisors:'NOT RUN: hosted management service; local catalog audit only',paidAPIs:'NOT RUN',productionAccess:false};
 await mkdir(resolve(root,'test-results'),{recursive:true});await writeFile(resolve(root,'test-results/supabase-local-qa.json'),JSON.stringify(report,null,2)+'\n');console.log('PASS '+JSON.stringify(report));
 await context.close();await memberContext.close();
}finally{
 if(browser)await browser.close();if(server)await new Promise(r=>server.close(r));
 for(const account of accounts){await account.client.auth.signOut();await administrator.auth.admin.deleteUser(account.id).catch(()=>{});}
 await db.end();
}
