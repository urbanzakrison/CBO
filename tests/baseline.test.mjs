import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import vm from 'node:vm';
const root=new URL('../',import.meta.url);
const read=p=>readFile(new URL(p,root),'utf8');
const hash=s=>createHash('sha256').update(s).digest('hex');
test('historical data, champions, auth, push/PWA and On Tour match verified main',async()=>{
 const expected=JSON.parse(await read('tests/fixtures/baseline-hashes.json'));
 const html=await read('index.html');
 const actual={embeddedData:html.split('\n').find(l=>l.startsWith('const DATA=')),historicalChampions:html.split('\n').find(l=>l.startsWith('const HISTORICAL_CHAMPIONS=')),onTourAdminScript:html.match(/<script id="onTourAdminDestinationScript">([\s\S]*?)<\/script>/)[1]};
 for(const file of ['auth-client.js','sw.js','on-tour.html','on-tour-preview.html'])actual[file]=await read(file);
 for(const [key,value] of Object.entries(actual))assert.equal(hash(value),expected[key],key);
});
test('all inline and changed external JavaScript parses',async()=>{
 const html=await read('index.html');
 for(const [,body] of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g))new vm.Script(body);
 for(const file of ['live-leaderboard.js','season-management.js'])new vm.Script(await read(file));
});
