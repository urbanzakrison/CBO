// Run outside this repository's scheduler. Public GitHub metadata only; no token.
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
export const WORKFLOW_API = 'https://api.github.com/repos/urbanzakrison/CBO/actions/workflows/cbo-winter-health.yml';
export function assess(workflow, runs, now = Date.now()) {
  if (workflow?.state !== 'active') return {status:'FAIL', error:'WORKFLOW_DISABLED_OR_MISSING'};
  const scheduled = (runs?.workflow_runs || []).filter(r=>r.event==='schedule' && r.head_branch==='main')
    .sort((a,b)=>Date.parse(b.created_at)-Date.parse(a.created_at));
  const last = scheduled[0];
  if (!last) return {status:'FAIL',error:'NO_SCHEDULED_RUN'};
  const ageHours = (now-Date.parse(last.created_at))/3600000;
  if (!Number.isFinite(ageHours) || ageHours < 0 || ageHours > 48) return {status:'FAIL',error:'SCHEDULE_STALE'};
  if (last.status !== 'completed' || last.conclusion !== 'success') return {status:'FAIL',error:'LATEST_SCHEDULE_NOT_SUCCESSFUL'};
  return {status:'PASS',error:null,lastScheduledUtc:last.created_at,ageHours:Math.round(ageHours*10)/10};
}
export async function main() {
  let result;
  try {
    const get = async url => {
      const r = await fetch(url,{redirect:'error',signal:AbortSignal.timeout(10000),headers:{Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28'}});
      if (r.status !== 200) throw new Error('API_UNAVAILABLE');
      const text = await r.text();
      if (text.length>1024*1024) throw new Error('API_UNAVAILABLE');
      return JSON.parse(text);
    };
    const [workflow,runs] = await Promise.all([get(WORKFLOW_API),get(WORKFLOW_API+'/runs?event=schedule&per_page=5')]);
    result = assess(workflow,runs);
  } catch { result={status:'FAIL',error:'GITHUB_API_UNAVAILABLE_OR_NOT_INSTALLED'}; }
  console.log(JSON.stringify({utc:new Date().toISOString(),service:'winter_scheduler',...result}));
  return result.status==='PASS' ? 0 : 1;
}
if (process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) process.exitCode=await main();
