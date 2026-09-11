/* CBO 3.5 – Supabase Auth + role gating + live leaderboard */
(() => {
  let sb = null;
  let currentPlayer = null;

  const $ = (id) => document.getElementById(id);
  const status = (txt, cls='wait') => {
    const el = $('dbStatus'); if (!el) return;
    el.textContent = txt; el.className = cls;
  };
  const showLoginError = (msg='') => {
    const el = $('loginError'); if (!el) return;
    el.textContent = msg; el.classList.toggle('show', !!msg);
  };
  const normalizeLoginId = (v) => {
    const raw=String(v||'').trim();
    const digits=raw.replace(/\D/g,'');
    if (digits.length===9) return digits;
    const alias=raw.toLowerCase();
    return /^[a-z0-9._-]{3,32}$/.test(alias) ? alias : '';
  };

  function configOk(){
    return window.CBO_SUPABASE_URL && !String(window.CBO_SUPABASE_URL).includes('PASTE_') &&
           window.CBO_SUPABASE_PUBLISHABLE_KEY && !String(window.CBO_SUPABASE_PUBLISHABLE_KEY).includes('PASTE_');
  }

  async function fetchCurrentPlayer(){
    const { data, error } = await sb.rpc('cbo_current_player');
    if (error) throw error;
    const row = Array.isArray(data) ? data[0] : data;
    if (!row) throw new Error('Kontot är inte kopplat till en aktiv CBO-spelare.');
    return { player_id: row.player_id, name: row.name, is_admin: row.is_admin === true };
  }

  function applyRole(player){
    currentPlayer = player;
    window.CBO_CURRENT_PLAYER = player;
    const adminBtn = $('adminNavButton');
    if (adminBtn) adminBtn.style.display = player.is_admin ? '' : 'none';
    const signed = $('signedInAs'); if (signed) signed.textContent = `Inloggad som ${player.name}`;
    const n = $('currentUserName'); if (n) n.textContent = player.name;
    const r = $('currentUserRole'); if (r) r.textContent = player.is_admin ? 'Inloggad · Admin' : 'Inloggad · Spelare';
    const logoutBtn = $('globalLogoutButton'); if (logoutBtn) logoutBtn.style.display = '';
    status(`SUPABASE · INLOGGAD · ${player.name}`, 'live');
    $('loginScreen')?.classList.add('hidden');
    if (typeof window.CBO_LOAD_LIVE_LEADERBOARD === 'function') window.CBO_LOAD_LIVE_LEADERBOARD();

    if (!player.is_admin && document.getElementById('admin')?.classList.contains('active')) {
      window.__cboOriginalShowPage?.('home', document.querySelector('.nav button[data-page="home"]'));
    }
  }

  function clearRole(){
    currentPlayer = null; window.CBO_CURRENT_PLAYER = null;
    const adminBtn = $('adminNavButton'); if (adminBtn) adminBtn.style.display = 'none';
    const logoutBtn = $('globalLogoutButton'); if (logoutBtn) logoutBtn.style.display = 'none';
    $('loginScreen')?.classList.remove('hidden');
    status('SUPABASE · VÄNTAR PÅ INLOGGNING', 'wait');
  }

  // Hard role guard: even a direct call showPage('admin') is denied to normal players.
  if (typeof window.showPage === 'function') {
    window.__cboOriginalShowPage = window.showPage;
    window.showPage = function(id, btn){
      if (id === 'admin' && !currentPlayer?.is_admin) {
        alert('Adminfunktionen är endast tillgänglig för tävlingsledaren.');
        return;
      }
      return window.__cboOriginalShowPage(id, btn);
    };
  }

  window.cboLogin = async function(){
    showLoginError('');
    if (!sb) { showLoginError('Supabase är inte konfigurerat i config.js.'); return; }
    const loginId = normalizeLoginId($('loginGolfId')?.value);
    const code = $('loginCode')?.value || '';
    if (!loginId || code.length < 8) { showLoginError('Kontrollera Golf-ID/profil och CBO-kod.'); return; }
    status('SUPABASE · LOGGAR IN', 'wait');
    const email = `${loginId}@cbo.local`;
    const { error } = await sb.auth.signInWithPassword({ email, password: code });
    if (error) {
      status('SUPABASE · INLOGGNING MISSLYCKADES', 'err');
      showLoginError('Fel Golf-ID eller CBO-kod, eller så är kontot ännu inte kopplat till CBO.');
      return;
    }
    try {
      const p = await fetchCurrentPlayer(); applyRole(p);
      if ($('loginCode')) $('loginCode').value = '';
    } catch(e) {
      await sb.auth.signOut(); clearRole(); showLoginError(e.message || 'CBO-kopplingen kunde inte verifieras.');
    }
  };

  window.cboLogout = async function(){
    if (sb) await sb.auth.signOut();
    clearRole();
    if (typeof window.__cboOriginalShowPage === 'function') window.__cboOriginalShowPage('home', document.querySelector('.nav button[data-page="home"]'));
  };

  async function boot(){
    // Admin hidden by default until role is verified.
    const adminBtn = $('adminNavButton'); if (adminBtn) adminBtn.style.display = 'none';
    if (!configOk() || !window.supabase?.createClient) {
      status('SUPABASE · KONFIG SAKNAS', 'err');
      showLoginError('Supabase är inte konfigurerat i config.js.');
      return;
    }
    sb = window.supabase.createClient(window.CBO_SUPABASE_URL, window.CBO_SUPABASE_PUBLISHABLE_KEY);
    window.CBO_SUPABASE_CLIENT = sb;
    const { data: { session } } = await sb.auth.getSession();
    if (!session) { clearRole(); return; }
    try { applyRole(await fetchCurrentPlayer()); }
    catch(e) { await sb.auth.signOut(); clearRole(); showLoginError('Kontot kunde inte verifieras mot CBO.'); }
  }

  boot();
})();
