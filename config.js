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
