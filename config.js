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

// CBO 4.6.x – isolated recovery for Clubhouse reaction Realtime.
// If the original reaction channel exists but never reached JOINED/SUBSCRIBED,
// clear it and let the existing Clubhouse open flow create a fresh channel.
(function cboClubhouseReactionRealtimeRecovery(){
  async function recover(){
    try{
      if(typeof CBO_CLUBHOUSE_REACTIONS_CHANNEL==="undefined") return;
      const channel=CBO_CLUBHOUSE_REACTIONS_CHANNEL;
      if(!channel) return;

      const state=String(channel.state||'').toLowerCase();
      if(state==='joined'||state==='joining') return;

      if(window.CBO_SUPABASE_CLIENT && typeof window.CBO_SUPABASE_CLIENT.removeChannel==='function'){
        try{ await window.CBO_SUPABASE_CLIENT.removeChannel(channel); }catch(_){ }
      }
      CBO_CLUBHOUSE_REACTIONS_CHANNEL=null;

      if(document.getElementById('clubhouse')?.classList.contains('active') && typeof cboClubhouseOpen==='function'){
        cboClubhouseOpen().catch(()=>{});
      }
    }catch(e){
      console.warn('Klubbhuset reaction Realtime recovery misslyckades',e);
    }
  }

  document.addEventListener('click',function(event){
    const target=event.target;
    if(!target || typeof target.closest!=='function') return;
    if(!target.closest('button[data-page="clubhouse"]')) return;
    setTimeout(recover,1200);
  });

  document.addEventListener('visibilitychange',function(){
    if(document.visibilityState==='visible') setTimeout(recover,1200);
  });
})();
