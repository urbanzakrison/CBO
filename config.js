// CBO 3.2 – fylls i lokalt. Skicka inte nyckeln i chatten.
window.CBO_SUPABASE_URL = "https://lwymnhmwrinzuvmoqqif.supabase.co";
window.CBO_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_7OxIpZoLDJGUCg27sJhXcg_oorKGJ_t";

// CBO 4.6.x – refresh Spelare/CBO-mästare when the page is actually opened.
// Keeps the fix isolated from auth, leaderboard and other verified flows.
(function cboPlayersPageOpenRefresh(){
  function refreshPlayersPage(event){
    const target=event.target;
    if(!target || typeof target.closest!=="function") return;
    const btn=target.closest('button[data-page="players"]');
    if(!btn) return;
    if(typeof window.renderPlayers==="function") window.renderPlayers();
    if(typeof window.renderChampionHistory==="function") window.renderChampionHistory();
  }

  document.addEventListener("pointerup",refreshPlayersPage);
  document.addEventListener("click",function(event){
    if(event.detail===0) refreshPlayersPage(event);
  });
})();

// CBO 4.6.x – member self-service entry point under Notiser on Hem.
// UI-only link to the already isolated min-profil.html flow.
(function cboAddMemberProfileLink(){
  function mount(){
    const card=document.getElementById("notificationCard");
    if(!card || document.getElementById("memberProfileButton")) return;

    const button=document.createElement("button");
    button.id="memberProfileButton";
    button.className="secondary";
    button.type="button";
    button.textContent="Min profil";
    button.addEventListener("click",function(){
      window.location.href="min-profil.html";
    });
    card.appendChild(button);
  }

  if(document.readyState==="loading") document.addEventListener("DOMContentLoaded",mount,{once:true});
  else mount();
})();

// CBO 4.6.x – reaction refresh fallback.
// Postgres Changes remains enabled, but while Klubbhuset is open we verify the
// compact reaction feed periodically. A changed signature triggers one normal
// Clubhouse reload, so other members see reactions without reloading the app.
(function cboClubhouseReactionRefreshFallback(){
  let lastSignature=null;
  let busy=false;

  function signature(rows){
    return JSON.stringify((Array.isArray(rows)?rows:[])
      .map(r=>[String(r.message_id||''),String(r.emoji||''),Number(r.reaction_count||0),!!r.reacted_by_me])
      .sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b))));
  }

  async function tick(){
    if(busy || document.visibilityState==='hidden') return;
    if(!document.getElementById('clubhouse')?.classList.contains('active')){
      lastSignature=null;
      return;
    }
    if(!window.CBO_SUPABASE_CLIENT) return;

    busy=true;
    try{
      const {data,error}=await window.CBO_SUPABASE_CLIENT.rpc('cbo_clubhouse_reactions_feed');
      if(error) throw error;
      const next=signature(data);
      if(lastSignature===null){
        lastSignature=next;
        return;
      }
      if(next!==lastSignature){
        lastSignature=next;
        if(typeof cboClubhouseLoad==='function') await cboClubhouseLoad();
      }
    }catch(e){
      console.warn('Klubbhuset reaction refresh misslyckades',e);
    }finally{
      busy=false;
    }
  }

  window.addEventListener('load',()=>{
    setInterval(tick,1500);
  });
})();

// CBO 4.6.x – unread refresh fallback.
// Existing Realtime remains primary. This only re-checks unread state when the
// app is visible so background/resume and late auth initialization cannot leave
// the navigation badge stale. It never marks Clubhouse messages as read.
(function cboClubhouseUnreadRefreshFallback(){
  let busy=false;

  async function refresh(){
    if(busy || document.visibilityState==='hidden') return;
    if(document.getElementById('clubhouse')?.classList.contains('active')) return;
    if(typeof cboClubhouseRefreshUnread!=='function') return;

    busy=true;
    try{
      await cboClubhouseRefreshUnread();
    }catch(e){
      console.warn('Klubbhuset unread refresh misslyckades',e);
    }finally{
      busy=false;
    }
  }

  window.addEventListener('load',()=>{
    setTimeout(refresh,1800);
    setTimeout(refresh,4500);
    setInterval(refresh,3000);
  });

  document.addEventListener('visibilitychange',()=>{
    if(document.visibilityState==='visible') setTimeout(refresh,250);
  });
})();

// CBO 4.6.x – message refresh fallback.
// Realtime remains primary. While Klubbhuset is open, compare a compact
// signature of the feed and reload only when a message has actually changed.
(function cboClubhouseMessageRefreshFallback(){
  let lastSignature=null;
  let busy=false;

  function signature(rows){
    return JSON.stringify((Array.isArray(rows)?rows:[]).map(r=>[
      String(r.id||''),
      String(r.created_at||''),
      String(r.edited_at||''),
      String(r.deleted_at||''),
      String(r.body||''),
      String(r.image_path||'')
    ]));
  }

  async function tick(){
    if(busy || document.visibilityState==='hidden') return;
    if(!document.getElementById('clubhouse')?.classList.contains('active')){
      lastSignature=null;
      return;
    }
    if(!window.CBO_SUPABASE_CLIENT) return;

    busy=true;
    try{
      const {data,error}=await window.CBO_SUPABASE_CLIENT.rpc('cbo_clubhouse_feed',{p_limit:100});
      if(error) throw error;
      const next=signature(data);
      if(lastSignature===null){
        lastSignature=next;
        return;
      }
      if(next!==lastSignature){
        lastSignature=next;
        if(typeof cboClubhouseLoad==='function') await cboClubhouseLoad();
      }
    }catch(e){
      console.warn('Klubbhuset message refresh misslyckades',e);
    }finally{
      busy=false;
    }
  }

  window.addEventListener('load',()=>{
    setInterval(tick,1500);
  });
})();
