import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFile} from 'node:fs/promises';
import {heartbeat,validPingUrl,verifiedPass} from './winter-heartbeat.mjs';
const url='https://hc-ping.com/11111111-2222-4333-8444-555555555555'; // fictional; never contacted
const now=Date.parse('2026-10-21T12:00:00Z');
const report={mode:'READ_ONLY_LIVE',status:'PASS',utc:new Date(now).toISOString(),checks:['frontend','supabase_database'].map(service=>({service,status:'PASS',httpStatus:200,error:null}))};
const base={enabled:'true',url,report,now};
test('verified PASS sends empty POST to exact provider, no redirect or payload',async()=>{
 let calls=0;const r=await heartbeat(base,{fetchImpl:async(u,init)=>{calls++;assert.equal(u,url);assert.equal(init.method,'POST');assert.equal(init.body,'');assert.equal(init.redirect,'error');assert.deepEqual(init.headers,{Accept:'text/plain'});return new Response('OK');}});
 assert.equal(calls,1);assert.equal(r.sent,true);assert.ok(!JSON.stringify(r).includes(url));
});
test('heartbeat consumes the unchanged v1 report mode',async()=>{
 const source=await readFile(new URL('./winter-health.mjs',import.meta.url),'utf8');
 assert.ok(source.includes("report.mode = simulated ? 'ISOLATED_FAULT_QA' : 'READ_ONLY_LIVE'"));
 assert.equal(verifiedPass(report,now),true);
});
test('FAIL, simulated, stale, future, missing or incomplete health never sends success',async()=>{
 for(const r of [null,{}, {...report,status:'FAIL'},{...report,mode:'ISOLATED_FAULT_QA'},{...report,checks:[]},{...report,utc:new Date(now-300001).toISOString()},{...report,utc:new Date(now+1).toISOString()}]){
  assert.equal(verifiedPass(r,now),false);const result=await heartbeat({...base,report:r},{fetchImpl:()=>assert.fail('must not contact provider')});assert.equal(result.sent,false);assert.equal(result.status,'FAIL');
 }
});
test('disabled integration does not require secret; enabled missing secret fails closed',async()=>{
 assert.equal((await heartbeat({enabled:'',url:null})).status,'NOT_ENABLED');
 assert.equal((await heartbeat({...base,url:''})).error,'MISSING_OR_INVALID_PING_URL');
});
test('rejects SSRF, credentials, ports, query, fragments, paths, auto-create and whitespace',async()=>{
 for(const bad of ['',url+'/',url+'/fail',url+'?create=1',url+'#x',url.replace('https:','http:'),url.replace('hc-ping.com','hc-ping.com.evil.invalid'),url.replace('hc-ping.com','user@hc-ping.com'),url.replace('hc-ping.com','hc-ping.com:443'),' '+url,'https://127.0.0.1/'+url.split('/').at(-1)]){
  assert.equal(validPingUrl(bad),false);assert.equal((await heartbeat({...base,url:bad},{fetchImpl:()=>assert.fail()})).status,'FAIL');
 }
});
test('HTTP 200 unknown check and rate limiting are not successful pings',async()=>{
 for(const body of ['OK (not found)','OK (rate limited)','<html>OK','SECRET_BODY']){
  const r=await heartbeat(base,{fetchImpl:async()=>new Response(body)});assert.equal(r.status,'FAIL');assert.equal(r.attempts,1);assert.ok(!JSON.stringify(r).includes(body));
 }
});
test('bounded retries, timeout, response size and exceptions never expose URL',async()=>{
 const keep=setInterval(()=>{},1000);
 try{
  for(const fetchImpl of [async()=>new Response('SECRET',{status:503}),async()=>{throw Error(url);},async(_,{signal})=>new Promise((_,reject)=>signal.addEventListener('abort',()=>reject(Error(url))))]){
   const r=await heartbeat(base,{fetchImpl,retryDelayMs:0,timeoutMs:10});assert.equal(r.status,'FAIL');assert.equal(r.attempts,3);assert.ok(!JSON.stringify(r).includes(url));
  }
 }finally{clearInterval(keep);}
 const big=await heartbeat(base,{fetchImpl:async()=>new Response('s'.repeat(33))});assert.equal(big.attempts,1);assert.equal(big.error,'RESPONSE_TOO_LARGE');
});
test('CLI refuses PR/manual/non-GitHub invocation even with a secret',()=>{
 for(const event of ['pull_request','workflow_dispatch','']){
  const r=spawnSync(process.execPath,['ops/winter-heartbeat.mjs'],{encoding:'utf8',env:{...process.env,GITHUB_ACTIONS:'true',GITHUB_EVENT_NAME:event,CBO_HEALTHCHECKS_PING_URL:url,GITHUB_STEP_SUMMARY:''}});
  assert.equal(r.status,1);assert.ok(!r.stdout.includes(url));assert.match(r.stdout,/HEARTBEAT_CONFIGURATION_ERROR/);
 }
});
test('scheduled CLI stays disabled without opt-in and fails safely without report when enabled',()=>{
 for(const enabled of ['', 'true']){
  const r=spawnSync(process.execPath,['ops/winter-heartbeat.mjs'],{encoding:'utf8',env:{...process.env,GITHUB_ACTIONS:'true',GITHUB_EVENT_NAME:'schedule',GITHUB_REF:'refs/heads/main',GITHUB_REPOSITORY:'urbanzakrison/CBO',CBO_HEALTHCHECKS_ENABLED:enabled,CBO_HEALTHCHECKS_PING_URL:url,CBO_HEALTH_REPORT:'/nonexistent-synthetic-health-report',GITHUB_STEP_SUMMARY:''}});
  assert.equal(r.status,enabled?1:0);assert.equal(JSON.parse(r.stdout).status,enabled?'FAIL':'NOT_ENABLED');assert.ok(!r.stdout.includes(url));assert.equal(r.stderr,'');
 }
});
