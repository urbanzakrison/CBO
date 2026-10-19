// Real browser + isolated PostgreSQL. No external service receives test writes.
import {chromium} from 'playwright';
import {PGlite} from '@electric-sql/pglite';
import {createServer} from 'node:http';
import {readFile,mkdir} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
import assert from 'node:assert/strict';
const root=resolve(import.meta.dirname,'..');
const db=new PGlite();
for(const file of ['tests/fixtures/schema.sql','tests/fixtures/production-functions.sql','22_season_management_v1.sql'])await db.exec(await readFile(resolve(root,file),'utf8'));
const names=['Urban Zakrison','Johan Fagerholm','Magnus Blennerud','Magnus Jerkfelt'];
const ids=names.map((_,i)=>`00000000-0000-0000-0000-${String(i+1).padStart(12,'0')}`);
for(let i=0;i<names.length;i++){
 await db.query('insert into auth.users values($1)',[ids[i]]);
 await db.query('insert into players(id,name,is_admin,current_hcp_index) values($1,$2,$3,$4)',[ids[i],names[i],i===0,10+i]);
 await db.query('insert into player_credentials values($1,$1)',[ids[i]]);
}
await db.exec("insert into seasons(year,status) values(2025,'AVSLUTAD'),(2026,'PÅGÅENDE')");
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[ids[0]]);
await db.query('select cbo_publish_round($1,$2,$3,$4,$5,$6)',[1,'2026-05-01','Test Hamra',36,'Bara 2026',JSON.stringify(names.map((name,i)=>({name,shcp:10+i,net:35+i,gross:45+i})))]);
const server=createServer(async(req,res)=>{
 try{
  if(req.url==='/test-rpc'){
   let body='';for await(const chunk of req)body+=chunk;
   const {name,args}=JSON.parse(body);
   let data;
   if(['cbo_current_player','cbo_seasons_status','cbo_season_data','cbo_season_create','cbo_season_activate','cbo_season_stats','cbo_publish_round','cbo_round_duplicate_check'].includes(name)){
    const values=Object.values(args||{});
    const q=`select public.${name}(${values.map((_,i)=>'$'+(i+1)).join(',')}) result`;
    if(name==='cbo_current_player') data=(await db.query('select * from cbo_current_player()')).rows;
    else data=(await db.query(q,values)).rows[0].result;
   }else data=[];
   res.setHeader('Content-Type','application/json');res.end(JSON.stringify({data,error:null}));return;
  }
  const path=resolve(root,'.'+new URL(req.url,'http://local').pathname.replace(/\/$/,'/index.html'));
  if(!path.startsWith(root+'/')){res.writeHead(403).end();return;}
  res.setHeader('Content-Type',({'.html':'text/html','.js':'application/javascript','.png':'image/png','.json':'application/json'})[extname(path)]||'text/plain');
  res.end(await readFile(path));
 }catch(e){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({data:null,error:{message:e.message}}));}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const url=`http://127.0.0.1:${server.address().port}`;
const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_EXECUTABLE_PATH||undefined,args:['--no-sandbox','--disable-dev-shm-usage','--disable-gpu','--no-zygote']});
try{
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true,serviceWorkers:'block'});
 await context.route('**/*',async route=>{
  if(route.request().url().includes('cdn.jsdelivr.net/npm/@supabase/'))return route.fulfill({contentType:'application/javascript',body:'window.supabase={createClient:()=>window.TEST_SB};'});
  if(!route.request().url().startsWith(url))return route.abort();
  return route.continue();
 });
 await context.addInitScript(()=>{
  window.TEST_CALLS=[];
  const chain={on(){return this},subscribe(){return this}};
  window.TEST_SB={
   rpc:async(name,args)=>{window.TEST_CALLS.push({name,args});return fetch('/test-rpc',{method:'POST',body:JSON.stringify({name,args})}).then(r=>r.json())},
   auth:{getSession:async()=>({data:{session:{user:{id:'00000000-0000-0000-0000-000000000001'}}}}),signOut:async()=>({error:null})},
   channel:()=>Object.create(chain),removeChannel:async()=>{},functions:{invoke:async()=>({data:{ok:true},error:null})}
  };
 });
 const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(url);await page.waitForFunction(()=>window.CBO_LIVE_READY===true);
 assert.match(await page.locator('#heroStatus').innerText(),/2026/);
 const originalHistory=await page.evaluate(()=>({leader:JSON.stringify(DATA.seasons['2025'].officialLeaderboard),rounds:DATA.seasons['2025'].results.length}));
 await page.evaluate(()=>showPage('admin'));
 assert.equal(await page.locator('#newRoundNo').inputValue(),'2');
 page.once('dialog',d=>d.accept());await page.locator('#newSeasonButton').click();
 await page.waitForFunction(()=>document.getElementById('seasonManagementStatus').textContent.includes('Verifierat: 2027'));
 assert.equal(await page.locator('#seasonSelect option[value="2027"]').count(),0);
 assert.match(await page.locator('#heroStatus').innerText(),/2026/);
 assert.equal((await page.evaluate(()=>TEST_CALLS)).filter(c=>c.name==='cbo_season_activate').length,0);
 page.on('dialog',async d=>d.accept(d.type()==='prompt'?'AKTIVERA 2027':undefined));
 await page.locator('[data-activate-year="2027"]').click();
 await page.waitForFunction(()=>document.getElementById('seasonManagementStatus').textContent.includes('Verifierat: 2027 är PÅGÅENDE'));
 await page.evaluate(()=>showPage('home'));
 assert.match(await page.locator('#heroStatus').innerText(),/2027/);
 assert.match(await page.locator('#homeTop').innerText(),/Ingen publicerad/);
 assert.equal(await page.locator('#kansliCard').innerText(),'');
 await page.evaluate(()=>showPage('leaderboard'));
 assert.match(await page.locator('#leaderRows').innerText(),/Ingen publicerad/);
 for(const cat of ['total','attendance','net','gross','eff','top8'])assert.equal(await page.evaluate(c=>leaderboard(c).length,cat),0);
 await page.evaluate(async()=>{showPage('statistics');await cboLoadSeasonStats();});
 assert.equal(await page.evaluate(()=>cboStatsResults('2027').length),0);
 assert.equal((await page.evaluate(()=>TEST_CALLS.filter(c=>c.name==='cbo_season_stats').at(-1))).args.p_year,2027);
 await page.evaluate(()=>showPage('leaderboard'));
 await page.evaluate(()=>changeSeason('2026'));
 assert.equal(await page.evaluate(()=>rounds().length),1);
 assert.match(await page.locator('#seasonChampion').innerText(),/Urban Zakrison/);
 await page.evaluate(()=>changeSeason('2025'));
 assert.deepEqual(await page.evaluate(()=>({leader:JSON.stringify(DATA.seasons['2025'].officialLeaderboard),rounds:DATA.seasons['2025'].results.length})),originalHistory);
 await page.evaluate(()=>changeSeason('2027'));
 await page.evaluate(()=>showPage('admin'));
 assert.equal(await page.locator('#newRoundNo').inputValue(),'1');
 assert.match(await page.locator('#newSeasonButton').innerText(),/2028/);
 // Exercise the actual GameBook review → guest exclusion → duplicate check → publisher.
 await page.evaluate(names=>{
  document.getElementById('newDate').value='2027-05-01';document.getElementById('newCourse').value='Test Hamra 2027';
  cboConfirmRoundDate();
  renderGameBookReview([
   {name:names[0],shcp:20,net:35},{name:names[1],shcp:10,net:35},
   {name:names[2],shcp:12,net:37},{name:names[3],shcp:13,net:38},
   {name:'Guest QA',shcp:0,net:20}
  ]);
  applyGameBookReview();window.TEST_DRAFT_COPY=JSON.parse(JSON.stringify(draftPreview));
 },names);
 assert.equal(await page.evaluate(()=>draftPreview.results.length),4);
 assert.deepEqual(await page.evaluate(()=>draftPreview.results.map(p=>p.points)),[4,3,2,1]);
 assert.match(await page.locator('#previewCard').innerText(),/GÄST · 0 p/);
 await page.evaluate(()=>saveDraft());
 await page.waitForFunction(()=>window.CBO_SEASONS.data['2027']?.rounds.length===1);
 const persisted=(await db.query('select rr.player_id,rr.points,rr.playing_hcp from round_results rr join rounds r on r.id=rr.round_id join seasons s on s.id=r.season_id where s.year=2027 order by rr.points desc')).rows;
 assert.deepEqual(persisted.map(r=>r.player_id),[ids[1],ids[0],ids[2],ids[3]]);
 assert.deepEqual(persisted.map(r=>Number(r.points)),[4,3,2,1]);
 assert.deepEqual(persisted.map(r=>Number(r.playing_hcp)),[10,20,12,13]);
 await page.evaluate(()=>{draftPreview=window.TEST_DRAFT_COPY;return saveDraft();});
 assert.equal((await db.query('select count(*)::int n from rounds r join seasons s on s.id=r.season_id where s.year=2027')).rows[0].n,1);
 assert.equal((await db.query('select r.round_no from rounds r join seasons s on s.id=r.season_id where s.year=2027')).rows[0].round_no,1);
 // Mobile admin card must fit viewport. Keep a review screenshot as an intermediate.
 await page.evaluate(()=>showPage('admin'));
 assert.equal(await page.locator('#seasonManagement').evaluate(e=>e.getBoundingClientRect().right<=window.innerWidth),true);
 await mkdir(resolve(root,'test-results'),{recursive:true});
 await page.locator('#seasonManagement').screenshot({path:resolve(root,'test-results/season-admin-mobile.png')});
 await page.evaluate(()=>showPage('clubhouse'));
 await page.waitForTimeout(100);
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[ids[1]]);
 await page.reload();await page.waitForFunction(()=>window.CBO_LIVE_READY===true);
 assert.equal(await page.locator('#adminNavButton').isVisible(),false);
 await page.evaluate(()=>showPage('admin'));
 assert.equal(await page.locator('#admin').evaluate(e=>e.classList.contains('active')),false);
 assert.deepEqual(errors,[]);
 console.log('PASS mobile: create 2027, explicit activation, empty views, 2025 history, frozen 2026, GameBook review with guest exclusion/SHCP tie-break/4-3-2-1 points/duplicate rejection, round 1 publication, 2028 proposal; no uncaught browser errors.');
 await context.close();
}finally{await browser.close();await new Promise(r=>server.close(r));await db.close();}
