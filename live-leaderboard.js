/* CBO 3.6 – clean live leaderboard.
   Live-era season data comes only from the server RPC cbo_live_leaderboard_data.
   No silent fallback to embedded leaderboard data. */
(() => {
  const n = v => (v === null || v === undefined || v === '') ? null : Number(v);

  function buildStats(players, results) {
    const map = new Map();
    for (const p of players || []) {
      if (p?.id != null && p?.name) {
        map.set(String(p.id), {
          name:p.name,
          current_hcp: n(p.current_hcp),
          hcp_source: p.hcp_source || 'missing',
          points:0,
          attendance:0,
          nets:[],
          grosses:[]
        });
      }
    }
    for (const r of results || []) {
      const s = map.get(String(r.player_id));
      if (!s) continue;
      const pts = n(r.points), net = n(r.net), gross = n(r.gross);
      s.points += Number.isFinite(pts) ? pts : 0;
      s.attendance += 1;
      if (Number.isFinite(net)) s.nets.push(net);
      if (Number.isFinite(gross)) s.grosses.push(gross);
    }
    return [...map.values()].map(s => {
      s.net = s.nets.length ? s.nets.reduce((a,b)=>a+b,0)/s.nets.length : null;
      s.gross = s.grosses.length ? s.grosses.reduce((a,b)=>a+b,0)/s.grosses.length : null;
      s.eff = s.attendance ? s.points/s.attendance : null;
      s.top8 = s.nets.length >= 8
        ? s.nets.slice().sort((a,b)=>a-b).slice(0,8).reduce((a,b)=>a+b,0)/8
        : null;
      return s;
    });
  }

  function category(stats, key, asc=false, require8=false) {
    return stats
      .filter(x => x[key] != null && (!require8 || x.top8 != null))
      .sort((a,b) => {
        const primary = asc ? a[key]-b[key] : b[key]-a[key];
        if (primary !== 0) return primary;

        // Official CBO tie-break for Totalen:
        // equal competition points -> lower current HCP ranks higher.
        if (key === 'points') {
          const ah = Number.isFinite(a.current_hcp) ? a.current_hcp : Number.POSITIVE_INFINITY;
          const bh = Number.isFinite(b.current_hcp) ? b.current_hcp : Number.POSITIVE_INFINITY;
          if (ah !== bh) return ah - bh;
        }

        return String(a.name || '').localeCompare(String(b.name || ''), 'sv');
      })
      .map(x => ({
        name:x.name,
        value:x[key],
        attendance:x.attendance,
        current_hcp:x.current_hcp,
        hcp_source:x.hcp_source
      }));
  }

  function setError(message) {
    window.CBO_LIVE_READY = false;
    window.CBO_LIVE_ERROR = message || 'Okänt live-fel';
    window.CBO_LIVE_STATS = null;
    window.CBO_LIVE_LEADERBOARD = null;
    const badge = document.getElementById('leaderSource');
    if (badge) {
      badge.textContent = 'SUPABASE · LIVE-FEL';
      badge.title = window.CBO_LIVE_ERROR;
    }
    const rows = document.getElementById('leaderRows');
    if (rows && cboUsesLiveSeason(selectedSeason)) {
      rows.innerHTML = `<div class="unavailable"><strong>Live-data kunde inte hämtas.</strong><br>${String(window.CBO_LIVE_ERROR).replace(/[<>&]/g,'')}</div>`;
    }
  }

  async function loadYear(year) {
    const sb = window.CBO_SUPABASE_CLIENT;
    const badge = document.getElementById('leaderSource');
    if (!sb) {
      setError('Supabase-klienten saknas.');
      return;
    }
    if (badge) badge.textContent = 'SUPABASE · HÄMTAR';

    try {
      const { data, error } = await sb.rpc('cbo_season_data', { p_year: Number(year) });
      if (error) throw new Error(error.message || 'RPC-anropet misslyckades.');
      if (!data || data.ok !== true) throw new Error(data?.error || 'Servern returnerade ingen live-data.');

      const players = Array.isArray(data.players) ? data.players : [];
      const results = Array.isArray(data.results) ? data.results : [];
      const liveRoundsRaw = Array.isArray(data.rounds) ? data.rounds : [];
      const stats = Number(year)>2026 && !results.length ? [] : buildStats(players, results);
      if (Number(year)>2026) DATA.seasons[String(year)].players=players.map(p=>({name:p.name,startHcp:p.start_hcp}));

      const playerById = new Map(players.map(p => [String(p.id), p.name]));
      const resultsByRound = new Map();
      for (const r of results) {
        const key = String(r.round_id);
        if (!resultsByRound.has(key)) resultsByRound.set(key, []);
        resultsByRound.get(key).push({
          name: playerById.get(String(r.player_id)) || 'Okänd spelare',
          shcp: n(r.playing_hcp),
          net: n(r.net),
          gross: n(r.gross),
          points: n(r.points)
        });
      }
      const rounds = liveRoundsRaw.map(r => ({
        id: r.id,
        round: Number(r.round_number),
        date: r.played_on || '',
        course: r.course || '',
        par9: n(r.par9) || 36,
        official: String(r.official) === 'true',
        recap: r.recap || '',
        results: resultsByRound.get(String(r.id)) || []
      })).sort((a,b) => b.round - a.round);

      const leaderboard = {
        total: category(stats,'points',false),
        attendance: category(stats,'attendance',false),
        net: category(stats,'net',true),
        gross: category(stats,'gross',true),
        eff: category(stats,'eff',false),
        top8: category(stats,'top8',true,true)
      };
      window.CBO_SEASONS.data[String(year)]={rounds,stats,leaderboard};
      if(String(year)===cboActiveYear()){window.CBO_LIVE_ROUNDS=rounds;window.CBO_LIVE_STATS=stats;window.CBO_LIVE_LEADERBOARD=leaderboard;}
      window.CBO_LIVE_READY = true;
      window.CBO_LIVE_ERROR = '';

      if (badge) badge.textContent = `SUPABASE · LIVE · ${results.length} RESULTAT`;


      console.info('CBO 3.6 live', {
        rounds: data.round_count,
        results: data.result_count,
        leader: leaderboard.total[0]
      });
    } catch (e) {
      console.error('CBO 3.6 live error', e);
      setError(e?.message || String(e));
      throw e;
    }
  }

  window.CBO_LOAD_SEASON_YEAR = async year => {
    if(!window.CBO_SEASONS.data[String(year)]) await loadYear(year);
  };
  let loading=null;
  window.CBO_LOAD_LIVE_LEADERBOARD = () => {
    if(loading)return loading;
    loading=(async()=>{
      try{
        await window.cboLoadSeasons();
        const active=cboActiveYear();
        if(active) await loadYear(active);
        if(cboUsesLiveSeason(selectedSeason) && selectedSeason!==active) await loadYear(selectedSeason);
        renderAll();
      }catch(e){setError(e.message);}
      finally{loading=null;}
    })();
    return loading;
  };
})();
