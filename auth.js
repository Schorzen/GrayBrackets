// GrayBrackets accounts: shared login state for every page.
// Needs supabase-config.js, and the supabase-js library loaded before this file.
(function () {
  const cfg = window.GB_SUPABASE || {};
  const configured = typeof cfg.url === 'string' && cfg.url.startsWith('https://') &&
                     typeof cfg.publishableKey === 'string' && !cfg.publishableKey.startsWith('PASTE_');
  const client = configured && window.supabase ? window.supabase.createClient(cfg.url, cfg.publishableKey) : null;

  const ready = (async () => {
    if (!client) return { client: null, user: null, configured };
    try {
      const { data } = await client.auth.getSession();
      return { client, user: data.session ? data.session.user : null, configured };
    } catch (e) {
      return { client, user: null, configured };
    }
  })();

  window.gbAuth = { configured, client, ready };

  function reveal() { document.documentElement.classList.remove('gb-checking'); }

  ready.then(({ user }) => {
    // Pages marked data-requires-login send visitors without an account to the login page.
    const needsLogin = document.body && document.body.dataset.requiresLogin === 'true';
    if (needsLogin && configured && !user) {
      const here = location.pathname.split('/').pop() + location.search;
      location.replace('account.html?next=' + encodeURIComponent(here));
      return;
    }
    reveal();

    // Header link: "Log in" or "My account"
    document.querySelectorAll('[data-auth-link]').forEach(a => {
      if (!configured) { a.hidden = true; return; }
      a.textContent = user ? 'My account' : 'Log in';
      a.href = 'account.html';
    });
  });

  // Never leave a page hidden if something above fails.
  setTimeout(reveal, 4000);
})();
