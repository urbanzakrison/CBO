/* Ordinary CBO seasons only. On Tour has its own unchanged lifecycle. */
(() => {
  const state = window.CBO_SEASONS = { activeYear:null, seasons:[], data:{}, ready:false };
  const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  window.cboSeasonEsc=escape;
  const rpc = async (name,args) => {
    const {data,error} = await window.CBO_SUPABASE_CLIENT.rpc(name,args);
    if(error || data?.ok !== true) throw new Error(error?.message || data?.error || 'Säsongsanropet misslyckades.');
    return data;
  };
  window.cboSeasonLive = year => state.data[String(year ?? selectedSeason)];
  window.cboUsesLiveSeason = year => Number(year ?? selectedSeason) >= 2026;
  window.cboActiveYear = () => state.activeYear ? String(state.activeYear) : '';
  window.cboLoadSeasons = async () => {
    const data = await rpc('cbo_seasons_status');
    const first = !state.ready;
    state.seasons = data.seasons;
    state.activeYear = data.active_year;
    state.ready = true;
    for(const s of data.seasons){
      const year=String(s.year);
      if(!DATA.seasons[year]) DATA.seasons[year]={year:s.year,status:s.status,players:[],results:[],officialLeaderboard:{total:[],attendance:[],net:[],gross:[],eff:[],top8:[]}};
      DATA.seasons[year].status=s.status;
      if(s.status==='AVSLUTAD' && s.champion_name && Number(year)>=2026){
        HISTORICAL_CHAMPIONS[year]={name:escape(s.champion_name),points:s.champion_points,basis:''};
        const old=CBO_CHAMPIONS.find(x=>x[0]===s.year);
        if(!old) CBO_CHAMPIONS.push([s.year,escape(s.champion_name),s.champion_points==null?'':s.champion_points+' p']);
      }
    }
    const selectable=data.seasons.filter(s=>s.status!=='FÖRBEREDD' && (s.year>=2021 || DATA.seasons[s.year]?.results?.length));
    if(first || !selectable.some(s=>String(s.year)===selectedSeason)) selectedSeason=String(data.active_year ?? selectable[0]?.year ?? '');
    const options=selectable.map(s=>`<option value="${s.year}">${s.year}</option>`).join('');
    for(const id of ['seasonSelect','roundSeasonSelect','playerSeasonSelect','statsSeason']){
      const el=document.getElementById(id); if(el){const previous=el.value;el.innerHTML=options;el.value=first?selectedSeason:(selectable.some(s=>String(s.year)===previous)?previous:selectedSeason);}
    }
    document.getElementById('homeTotalTitle').textContent='Totalen '+(data.active_year ?? '—');
    window.cboRenderSeasonAdmin();
    return state;
  };
  window.cboRenderSeasonAdmin = () => {
    const el=document.getElementById('seasonManagementBody');
    if(!el)return;
    if(!window.CBO_CURRENT_PLAYER?.is_admin){el.textContent='Adminbehörighet krävs.';return;}
    if(!state.ready){el.textContent='Säsongsstatus kunde inte verifieras. Läs om sidan.';return;}
    const next=Math.max(...state.seasons.map(s=>s.year))+1;
    el.innerHTML=`<p>Aktiv säsong: <strong>${state.activeYear ?? 'Ingen'}</strong></p>`+
      ['FÖRBEREDD','AVSLUTAD'].map(status=>`<h3>${status==='FÖRBEREDD'?'Förberedda säsonger':'Avslutade säsonger'}</h3>`+
        (state.seasons.filter(s=>s.status===status).map(s=>`<div class="row"><strong>${s.year}</strong>${s.can_activate?`<button type="button" class="secondary" data-activate-year="${s.year}">Aktivera säsong</button>`:''}</div>`).join('')||'<p class="sub">Inga</p>')).join('')+
      `<button type="button" class="primary" id="newSeasonButton">Ny säsong · ${next}</button>`;
    document.getElementById('newSeasonButton').onclick=()=>mutate('create',next);
    el.querySelectorAll('[data-activate-year]').forEach(button=>button.onclick=()=>mutate('activate',Number(button.dataset.activateYear)));
  };
  let busy=false;
  async function mutate(action,year){
    if(busy || !window.CBO_CURRENT_PLAYER?.is_admin)return;
    const active=state.activeYear;
    const message=action==='create'
      ? `Skapa säsong ${year} som FÖRBEREDD?\n\n${active} fortsätter vara aktiv. Inga resultat flyttas. Aktiva ordinarie medlemmar läggs till; TEST-medlemmar undantas.`
      : `Aktivera säsong ${year}?\n\nSäsong ${active} avslutas och slutställningen fryses. Champion fastställs enligt Totalen om ingen officiell champion redan finns. Historiska resultat bevaras. Nya ordinarie CBO-omgångar registreras i ${year}.\n\nDetta är ett separat säsongsskifte.`;
    if(!confirm(message))return;
    if(action==='activate' && prompt(`Skriv AKTIVERA ${year} för att bekräfta säsongsskiftet.`)!==`AKTIVERA ${year}`)return;
    busy=true;
    const status=document.getElementById('seasonManagementStatus');
    document.querySelectorAll('#seasonManagementBody button').forEach(b=>b.disabled=true);
    status.textContent='Sparar och verifierar…';
    try{
      await rpc(action==='create'?'cbo_season_create':'cbo_season_activate',action==='create'?{p_year:year}:{p_year:year,p_expected_active_year:active});
      if(action==='activate'){state.ready=false;state.data={};}
      await window.CBO_LOAD_LIVE_LEADERBOARD();
      const expected=action==='create'?'FÖRBEREDD':'PÅGÅENDE';
      if(!state.seasons.some(s=>s.year===year&&s.status===expected))throw new Error('Åtgärden kan ha sparats men kunde inte verifieras. Läs om innan nytt försök.');
      status.textContent=`Verifierat: ${year} är ${expected}. Aktiv säsong: ${state.activeYear}.`;
    }catch(e){status.textContent=e.message;}
    finally{busy=false;window.cboRenderSeasonAdmin();}
  }
})();
