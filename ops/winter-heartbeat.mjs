// Opt-in only. No API key, payload, redirects, response bodies or secret URLs in logs.
import {readFile,appendFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {probe} from './winter-health.mjs';

export function validPingUrl(value) {
 return typeof value==='string' && /^https:\/\/hc-ping\.com\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value);
}
export function verifiedPass(report,now=Date.now()) {
 return report?.mode==='LIVE' && report.status==='PASS' && Number.isFinite(Date.parse(report.utc)) &&
  now-Date.parse(report.utc)>=0 && now-Date.parse(report.utc)<5*60*1000 &&
  report.checks?.length===2 && ['frontend','supabase_database'].every(service=>
   report.checks.some(c=>c.service===service && c.status==='PASS' && c.httpStatus===200 && !c.error));
}
export async function heartbeat({enabled,url,report,now=Date.now()},options={}) {
 if(enabled!=='true')return {status:'NOT_ENABLED',sent:false};
 if(!verifiedPass(report,now))return {status:'FAIL',sent:false,error:'HEALTH_NOT_VERIFIED'};
 if(!validPingUrl(url))return {status:'FAIL',sent:false,error:'MISSING_OR_INVALID_PING_URL'};
 const result=await probe({service:'independent_heartbeat',url,init:{method:'POST',body:'',headers:{Accept:'text/plain'}},maxBytes:32,
  validate:body=>body==='OK'},options);
 return {...result,sent:result.status==='PASS'};
}
export async function main(env=process.env) {
 let result;
 try {
  if(env.GITHUB_ACTIONS!=='true'||env.GITHUB_EVENT_NAME!=='schedule'||env.GITHUB_REF!=='refs/heads/main'||env.GITHUB_REPOSITORY!=='urbanzakrison/CBO')throw Error();
  const report=env.CBO_HEALTHCHECKS_ENABLED==='true'?JSON.parse(await readFile(env.CBO_HEALTH_REPORT,'utf8')):null;
  result=await heartbeat({enabled:env.CBO_HEALTHCHECKS_ENABLED,url:env.CBO_HEALTHCHECKS_PING_URL,report});
 }catch{result={status:'FAIL',sent:false,error:'HEARTBEAT_CONFIGURATION_ERROR'};}
 console.log(JSON.stringify({utc:new Date().toISOString(),...result}));
 if(env.GITHUB_STEP_SUMMARY)await appendFile(env.GITHUB_STEP_SUMMARY,`\nIndependent heartbeat: ${result.status}. Provider acceptance is not proof of alert delivery or receipt.\n`);
 return result.status==='FAIL'?1:0;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))process.exitCode=await main();
