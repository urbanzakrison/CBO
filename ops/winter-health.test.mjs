import {test} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync,spawnSync} from 'node:child_process';
import {readFile} from 'node:fs/promises';
import {FRONTEND,DATABASE,publicKey,probe,healthCheck,simulationFetch} from './winter-health.mjs';
import {assess} from './winter-watchdog.mjs';
const html='<html>Classic Boys Open loginGolfId auth-client.js season-management.js';
const key='sb_publishable_synthetic';
const fast={retryDelayMs:0};
const healthy=async url=>url===FRONTEND ? new Response(html,{headers:{'Content-Type':'text/html'}})
  : new Response('false',{headers:{'Content-Type':'application/json'}});

test('live request contract: fixed destinations; no credentials; anonymous boolean',async()=>{
 const calls=[];
 const report=await healthCheck(key,{fetchImpl:async(url,init)=>{calls.push({url,init});return healthy(url);}});
 assert.equal(report.status,'PASS');assert.ok(!Number.isNaN(Date.parse(report.utc)));
 assert.deepEqual(calls.map(c=>c.url),[FRONTEND,DATABASE]);
 assert.equal(calls[0].init.method,'GET');assert.equal(calls[1].init.method,'POST');
 assert.equal(calls[1].init.body,'{}');assert.equal(calls[1].init.headers.apikey,key);
 assert.equal(calls[1].init.headers.Authorization,undefined);
 assert.equal(calls[1].init.redirect,'error');
 assert.equal(JSON.stringify(report).includes(key),false);
});
test('HTTP 200 generic error page is a failure, no retry',async()=>{
 const report=await healthCheck(key,{fetchImpl:async u=>u===FRONTEND?new Response('<html>Error',{headers:{'Content-Type':'text/html'}}):healthy(u)});
 assert.equal(report.status,'FAIL');assert.equal(report.checks[0].error,'UNEXPECTED_CONTENT');assert.equal(report.checks[0].attempts,1);
});
test('frontend HTTP failure gives FAIL with exactly three attempts',async()=>{
 const r=await healthCheck(key,{...fast,fetchImpl:simulationFetch('frontend')});
 assert.equal(r.status,'FAIL');assert.equal(r.checks[0].httpStatus,503);assert.equal(r.checks[0].attempts,3);assert.equal(r.checks[1].status,'PASS');
});
test('database HTTP failure gives FAIL independently',async()=>{
 const r=await healthCheck(key,{...fast,fetchImpl:simulationFetch('supabase')});
 assert.equal(r.checks[0].status,'PASS');assert.equal(r.checks[1].error,'HTTP_503');assert.equal(r.checks[1].attempts,3);
});
test('database requires exact false JSON; rejects member data, true and Auth-only page',async()=>{
 for(const body of ['true','[]','{"name":"PRIVATE_MEMBER"}','{"status":"healthy"}','<html>healthy']){
  const r=await healthCheck(key,{fetchImpl:async u=>u===DATABASE?new Response(body,{headers:{'Content-Type':'application/json'}}):healthy(u)});
  assert.equal(r.status,'FAIL');assert.equal(r.checks[1].attempts,1);assert.equal(JSON.stringify(r).includes('PRIVATE_MEMBER'),false);
 }
});
test('deadline includes response streaming and retries stop at three',async()=>{
 let calls=0;
 const r=await probe({service:'test',url:FRONTEND,init:{},maxBytes:100,validate:()=>true},{...fast,timeoutMs:15,fetchImpl:async(_,{signal})=>{
  calls++;
  return new Response(new ReadableStream({start(controller){
   const timer=setTimeout(()=>controller.close(),5000);
   signal.addEventListener('abort',()=>{clearTimeout(timer);controller.error(new Error('PRIVATE_TOKEN'));},{once:true});
  }}));
 }});
 assert.equal(r.status,'FAIL');assert.equal(r.error,'TIMEOUT');assert.equal(calls,3);assert.ok(r.elapsedMs<2000);
 assert.equal(JSON.stringify(r).includes('PRIVATE_TOKEN'),false);
});
test('network exception and excessive response never leak body or exception',async()=>{
 const r=await healthCheck(key,{...fast,fetchImpl:async()=>{throw new Error('SECRET_AUTH_HEADER');}});
 assert.equal(r.status,'FAIL');assert.ok(r.checks.every(x=>x.attempts===3));assert.equal(JSON.stringify(r).includes('SECRET_AUTH'),false);
 const tooBig=await probe({service:'test',url:FRONTEND,init:{},maxBytes:2,validate:()=>true},{...fast,fetchImpl:healthy});
 assert.equal(tooBig.error,'RESPONSE_TOO_LARGE');assert.equal(tooBig.attempts,1);
});
test('transient recovery succeeds; permanent HTTP and redirects are not followed',async()=>{
 let calls=0;
 const spec={service:'test',url:FRONTEND,init:{},maxBytes:100,validate:s=>s===html};
 const r=await probe(spec,{...fast,fetchImpl:async()=>++calls===1?new Response('',{status:503}):healthy(FRONTEND)});
 assert.equal(r.status,'PASS');assert.equal(r.attempts,2);
 for(const status of [301,401,403,404]){
  const fail=await probe(spec,{...fast,fetchImpl:async()=>new Response('private',{status})});
  assert.equal(fail.status,'FAIL');assert.equal(fail.attempts,1);
 }
});
test('config only accepts the existing project and publishable key format',()=>{
 assert.equal(publicKey(`window.CBO_SUPABASE_URL="https://lwymnhmwrinzuvmoqqif.supabase.co";window.CBO_SUPABASE_PUBLISHABLE_KEY="${key}";`),key);
 for(const invalid of ['','service_role','sb_secret_abc','eyJhbGciOi']) assert.throws(()=>publicKey(`window.CBO_SUPABASE_URL="https://lwymnhmwrinzuvmoqqif.supabase.co";window.CBO_SUPABASE_PUBLISHABLE_KEY="${invalid}";`));
 assert.throws(()=>publicKey('window.CBO_SUPABASE_URL="https://other.invalid";'));
});
test('offline CLI fault produces nonzero status and sanitized log; production simulation blocked',()=>{
 for(const fault of ['frontend','supabase','timeout']){
  const r=spawnSync(process.execPath,['ops/winter-health.mjs','--simulate',fault],{encoding:'utf8',env:{...process.env,GITHUB_ACTIONS:'true',GITHUB_EVENT_NAME:'pull_request',GITHUB_STEP_SUMMARY:'',CBO_HEALTH_REPORT:''}});
  assert.equal(r.status,1);const report=JSON.parse(r.stdout);assert.equal(report.status,'FAIL');assert.equal(report.mode,'ISOLATED_FAULT_QA');
  assert.ok(!/private|publishable|apikey|Bearer|token|Authorization/i.test(r.stdout));
 }
 const blocked=spawnSync(process.execPath,['ops/winter-health.mjs','--simulate','frontend'],{encoding:'utf8',env:{...process.env,GITHUB_ACTIONS:'true',GITHUB_EVENT_NAME:'schedule',GITHUB_STEP_SUMMARY:'',CBO_HEALTH_REPORT:''}});
 assert.equal(blocked.status,1);assert.equal(JSON.parse(blocked.stdout).error,'CONFIG_OR_ARGUMENT_ERROR');
});
test('independent watchdog detects disabled, missing, stale and failed schedules',()=>{
 const now=Date.parse('2026-10-21T12:00:00Z');
 const good={event:'schedule',head_branch:'main',created_at:'2026-10-21T06:23:00Z',status:'completed',conclusion:'success'};
 assert.equal(assess({state:'active'},{workflow_runs:[good]},now).status,'PASS');
 assert.equal(assess({state:'disabled_inactivity'},{workflow_runs:[good]},now).status,'FAIL');
 for(const runs of [[],[{...good,event:'workflow_dispatch'}],[{...good,created_at:'2026-10-18T06:23:00Z'}],[{...good,conclusion:'failure'}],[{...good,status:'in_progress'}],[{...good,created_at:'invalid'}]])assert.equal(assess({state:'active'},{workflow_runs:runs},now).status,'FAIL');
});
test('PR change scope excludes every app, auth, database and On Tour file',()=>{
 const base=process.env.CBO_WINTER_BASE_SHA || execFileSync('git',['merge-base','origin/main','HEAD'],{encoding:'utf8'}).trim();
 const changed=execFileSync('git',['diff','--name-only',base,'HEAD'],{encoding:'utf8'}).trim().split('\n').filter(Boolean);
 for(const f of changed)assert.ok(f.startsWith('ops/')||f==='docs/WINTER_OPERATIONS_V1.md'||f==='.github/workflows/cbo-winter-health.yml',f);
});
test('workflow has daily UTC schedule, manual trigger, no write/deploy/secrets',async()=>{
 const w=await readFile(new URL('../.github/workflows/cbo-winter-health.yml',import.meta.url),'utf8');
 assert.match(w,/cron: '23 6 \* \* \*'/);assert.match(w,/workflow_dispatch:/);assert.match(w,/contents: read/);
 assert.ok(!/secrets\.|write|deploy|supabase.*(key|token)/i.test(w));assert.match(w,/timeout-minutes: 4/);assert.match(w,/visibility == 'public'/);
});
