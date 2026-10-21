// Operational reads only. No member login, writes, deployment or keep-alive claim.
import {readFile, writeFile, appendFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';

export const FRONTEND = 'https://urbanzakrison.github.io/CBO/';
export const DATABASE = 'https://lwymnhmwrinzuvmoqqif.supabase.co/rest/v1/rpc/is_cbo_member';
const transient = new Set([408, 429, 500, 502, 503, 504]);
const pause = ms => new Promise(r => setTimeout(r, ms));

export function publicKey(config) {
  const url = config.match(/window\.CBO_SUPABASE_URL\s*=\s*"([^"]+)"/);
  const key = config.match(/window\.CBO_SUPABASE_PUBLISHABLE_KEY\s*=\s*"([^"]+)"/);
  if (url?.[1] !== 'https://lwymnhmwrinzuvmoqqif.supabase.co' || !/^sb_publishable_[A-Za-z0-9_-]+$/.test(key?.[1] || '')) {
    throw new Error('INVALID_PUBLIC_CONFIG');
  }
  return key[1];
}

async function boundedText(response, maxBytes) {
  const reader = response.body?.getReader();
  if (!reader) return '';
  let size = 0;
  const chunks = [];
  try {
    while (true) {
      const {value, done} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBytes) throw new Error('RESPONSE_TOO_LARGE');
      chunks.push(value);
    }
  } finally {
    await reader.cancel().catch(() => {});
  }
  return Buffer.concat(chunks).toString('utf8');
}

export async function probe({service, url, init, validate, maxBytes}, {
  fetchImpl = fetch, timeoutMs = 15000, maxAttempts = 3, retryDelayMs = 1000
} = {}) {
  if (!Number.isInteger(maxAttempts) || maxAttempts < 1 || maxAttempts > 3 || timeoutMs < 1 || timeoutMs > 15000) throw new Error('INVALID_PROBE_LIMITS');
  const started = performance.now();
  let result;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    let status = null, retry = false, error = null;
    const signal = AbortSignal.timeout(timeoutMs);
    try {
      const response = await fetchImpl(url, {...init, redirect:'error', signal});
      status = response.status;
      if (status !== 200) {
        await response.body?.cancel();
        error = `HTTP_${status}`;
        retry = transient.has(status);
      } else {
        const text = await boundedText(response, maxBytes);
        if (!validate(text, response.headers)) error = 'UNEXPECTED_CONTENT';
      }
    } catch (e) {
      // Never emit exception text, response bodies, URLs or request headers.
      error = signal.aborted ? 'TIMEOUT' : e.message === 'RESPONSE_TOO_LARGE' ? 'RESPONSE_TOO_LARGE' : 'NETWORK_OR_TLS_ERROR';
      retry = error !== 'RESPONSE_TOO_LARGE';
    }
    result = {service, status:error ? 'FAIL' : 'PASS', httpStatus:status,
      elapsedMs:Math.round(performance.now()-started), attempts:attempt, error};
    if (!error || !retry || attempt === maxAttempts) return result;
    await pause(retryDelayMs);
  }
  return result;
}

export async function healthCheck(key, options = {}) {
  const checks = await Promise.all([
    probe({service:'frontend', url:FRONTEND, init:{method:'GET', headers:{Accept:'text/html'}}, maxBytes:1024*1024,
      validate:(s,h) => /text\/html/i.test(h.get('content-type') || '') &&
        ['<html', 'Classic Boys Open', 'loginGolfId', 'auth-client.js', 'season-management.js'].every(marker => s.includes(marker))}, options),
    probe({service:'supabase_database', url:DATABASE,
      init:{method:'POST', headers:{apikey:key, 'Content-Type':'application/json', Accept:'application/json'}, body:'{}'}, maxBytes:32,
      validate:(s,h) => /application\/json/i.test(h.get('content-type') || '') && s.trim() === 'false'}, options)
  ]);
  return {utc:new Date().toISOString(), status:checks.every(c=>c.status==='PASS') ? 'PASS' : 'FAIL', checks};
}

// Faults are offline and only permitted during local/PR QA, never schedule/dispatch.
export function simulationFetch(fault) {
  if (!['frontend','supabase','timeout'].includes(fault)) throw new Error('INVALID_QA_FAULT');
  return async (url, {signal}) => {
    if (fault === 'timeout') return new Promise((_,reject) => {
      signal.addEventListener('abort',()=>reject(new Error('private timeout detail')), {once:true});
    });
    if ((fault==='frontend' && url===FRONTEND) || (fault==='supabase' && url===DATABASE)) {
      return new Response('private upstream error', {status:503});
    }
    return url===FRONTEND ? new Response('<html>Classic Boys Open loginGolfId auth-client.js season-management.js', {headers:{'Content-Type':'text/html'}})
      : new Response('false', {headers:{'Content-Type':'application/json'}});
  };
}

export async function main(args = process.argv.slice(2)) {
  let report;
  try {
    const simulated = args.length === 2 && args[0] === '--simulate';
    if (args.length && !simulated) throw new Error('INVALID_ARGUMENTS');
    if (simulated && process.env.GITHUB_ACTIONS && process.env.GITHUB_EVENT_NAME !== 'pull_request') throw new Error('QA_ONLY');
    const key = simulated ? 'sb_publishable_synthetic' : publicKey(await readFile(new URL('../config.js', import.meta.url), 'utf8'));
    // Keep the process alive during offline timeout tests (AbortSignal timers are unref'ed).
    const keepAlive = setInterval(()=>{}, 1000);
    try {
      report = await healthCheck(key, simulated ? {fetchImpl:simulationFetch(args[1]), timeoutMs:30, retryDelayMs:1} : {});
    } finally { clearInterval(keepAlive); }
    report.mode = simulated ? 'ISOLATED_FAULT_QA' : 'READ_ONLY_LIVE';
  } catch {
    report = {utc:new Date().toISOString(), status:'FAIL', checks:[], error:'CONFIG_OR_ARGUMENT_ERROR'};
  }
  console.log(JSON.stringify(report));
  // Only sanitized metadata is retained, never a response, key or exception.
  if (process.env.GITHUB_STEP_SUMMARY) await appendFile(process.env.GITHUB_STEP_SUMMARY,
    `## CBO Winter Health — ${report.status}\n\nUTC: ${report.utc}\n\n` +
    '| Service | Result | HTTP | Total ms | Attempts | Error |\n|---|---|---|---|---|---|\n' +
    report.checks.map(c=>`| ${c.service} | ${c.status} | ${c.httpStatus ?? 'none'} | ${c.elapsedMs} | ${c.attempts} | ${c.error ?? 'none'} |`).join('\n')+'\n');
  if (process.env.CBO_HEALTH_REPORT) await writeFile(process.env.CBO_HEALTH_REPORT, JSON.stringify(report,null,2)+'\n', {mode:0o600});
  return report.status === 'PASS' ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) process.exitCode = await main();
