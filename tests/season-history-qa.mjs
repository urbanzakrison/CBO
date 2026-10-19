// Isolated, read-only-source historical parity test. Never connects to Supabase.
// Input contains competition data only; do not include credentials/auth identities.
import {PGlite} from '@electric-sql/pglite';
import {readFile,writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const root=new URL('../',import.meta.url);
const read=f=>readFile(new URL(f,root),'utf8');
const input=process.env.CBO_QA_HISTORY_FILE;
if(!input)throw new Error('Set CBO_QA_HISTORY_FILE to a local, sanitized competition-data export.');
const source=JSON.parse(await readFile(input,'utf8'));
const db=new PGlite();
const hash=x=>createHash('sha256').update(JSON.stringify(x)).digest('hex');
async function insert(table,rows){
 const allowed={players:['id','name','active','is_admin','is_test','current_hcp_index'],seasons:['id','year','status','official_champion_player_id','official_champion_points','created_at','champion_metric','champion_value','champion_note'],season_players:['season_id','player_id','start_hcp'],rounds:['id','season_id','round_no','played_on','course','par9','official','recap','created_at'],round_results:['round_id','player_id','playing_hcp','net','gross','placement','points']};
 for(const row of rows||[]){const columns=allowed[table].filter(c=>Object.hasOwn(row,c));await db.query(`insert into ${table}(${columns.join(',')}) values(${columns.map((_,i)=>'$'+(i+1)).join(',')})`,columns.map(c=>row[c]));}
}
async function rpc(name,args=[]){return (await db.query(`select ${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) value`,args)).rows[0].value;}
async function table(table,order){return (await db.query(`select * from ${table} order by ${order}`)).rows;}
async function standings(payload,legacy=false){
 const w={CBO_SEASONS:{data:{}},CBO_SUPABASE_CLIENT:{rpc:async()=>({data:payload,error:null})}};
 const context={window:w,document:{getElementById:()=>null},console:{info(){},error(){}},cboUsesLiveSeason:()=>true,selectedSeason:'2026',cboActiveYear:()=> '2026'};
 vm.createContext(context);
 const script=legacy?execFileSync('git',['show','c7952ce0e92225ede30831d09e7b1dfc1779bdf1:live-leaderboard.js'],{cwd:new URL('../',import.meta.url),encoding:'utf8'}):await read('live-leaderboard.js');
 vm.runInContext(script,context);
 if(legacy)await w.CBO_LOAD_LIVE_LEADERBOARD();else await w.CBO_LOAD_SEASON_YEAR(2026);
 return JSON.parse(JSON.stringify(legacy?w.CBO_LIVE_LEADERBOARD:w.CBO_SEASONS.data['2026'].leaderboard));
}
try{
 await db.exec(await read('tests/fixtures/schema.sql'));
 await db.exec(await read('tests/fixtures/production-functions.sql'));
 await insert('players',source.players);await insert('seasons',source.seasons);await insert('season_players',source.season_players);await insert('rounds',source.rounds);await insert('round_results',source.results);
 const admin=source.players.find(p=>p.active&&p.is_admin);assert.ok(admin);
 const localUser='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 await db.query('insert into auth.users values($1)',[localUser]);await db.query('insert into player_credentials values($1,$2)',[admin.id,localUser]);
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[localUser]);
 const originalPayload=await rpc('cbo_live_leaderboard_data',[2026]);
 assert.equal(originalPayload.ok,true);
 const originalStandings=await standings(originalPayload,true);
 const beforeRounds=await table('rounds','season_id,round_no');const beforeResults=await table('round_results','round_id,player_id');
 const beforeSeasons=(await table('seasons','year')).filter(s=>s.year<2026);
 const beforeStats={};for(const y of [2021,2022,2023,2024,2025,2026])beforeStats[y]=await rpc('cbo_season_stats',[y]);
 await db.exec(await read('22_season_management_v1.sql'));
 assert.deepEqual(await standings(await rpc('cbo_season_data',[2026])),originalStandings);
 await rpc('cbo_season_create',[2027]);
 assert.equal((await rpc('cbo_seasons_status')).active_year,2026);
 assert.deepEqual(await standings(await rpc('cbo_season_data',[2026])),originalStandings);
 await rpc('cbo_season_activate',[2027,2026]);
 const afterStandings=await standings(await rpc('cbo_season_data',[2026]));assert.deepEqual(afterStandings,originalStandings);
 assert.deepEqual(await table('rounds','season_id,round_no'),beforeRounds);
 assert.deepEqual(await table('round_results','round_id,player_id'),beforeResults);
 assert.deepEqual((await table('seasons','year')).filter(s=>s.year<2026),beforeSeasons);
 for(const y of [2021,2022,2023,2024,2025,2026])assert.deepEqual(await rpc('cbo_season_stats',[y]),beforeStats[y]);
 await db.exec('update players set current_hcp_index=54');
 assert.deepEqual(await standings(await rpc('cbo_season_data',[2026])),originalStandings);
 const report={baselineCommit:'c7952ce0e92225ede30831d09e7b1dfc1779bdf1',environment:'isolated PGlite; sanitized read-only production export; synthetic local auth identity',source:{seasons:source.seasons.length,rounds:source.rounds.length,results:source.results.length},checks:{allSix2026Categories:'identical before installation, after preparation, after activation and after HCP change',roundRows:'identical',resultRows:'identical',champions2011to2025:'identical',stats2021to2026:'identical'},hashes:{standings2026:hash(originalStandings),roundRows:hash(beforeRounds),resultRows:hash(beforeResults),priorSeasons:hash(beforeSeasons),stats:hash(beforeStats)}};
 await writeFile(new URL('test-results/history-qa.json',root),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
}finally{await db.close();}
