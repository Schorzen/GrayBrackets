// GrayBrackets final page: project submission status and form.
(async function () {
  const COURSE = 'html-css';
  const $ = id => document.getElementById(id);
  const box = $('project-status');
  const form = $('project-form');
  if (!box || !window.gbAuth) return;
  const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const day = d => new Date(d).toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' });
  const ERRORS = {
    pass_exam_first: 'Pass the final exam first, then submit your project.',
    already_pending: 'Your project is already waiting for review.',
    already_certified: 'You already have a certificate for this course.',
    bad_links: 'Both links must be full addresses starting with https://',
    not_logged_in: 'Please log in again.'
  };

  const { client, user } = await window.gbAuth.ready;
  if (!client || !user) { box.innerHTML = '<p>Log in to submit your project.</p>'; return; }

  async function load() {
    const [exam, cert, subs] = await Promise.all([
      client.from('exam_attempts').select('score,total').eq('course', COURSE).eq('passed', true).limit(1),
      client.from('certificates').select('id,issued_at').eq('course', COURSE).limit(1),
      client.from('project_submissions').select('status,feedback,created_at,live_url').eq('course', COURSE).order('created_at', { ascending: false }).limit(1)
    ]);
    const passed = exam.data && exam.data[0];
    const certificate = cert.data && cert.data[0];
    const latest = subs.data && subs.data[0];
    form.hidden = true;

    if (certificate) {
      box.innerHTML = `
        <div class="status ok"><strong>You're certified!</strong>&nbsp;Issued ${esc(day(certificate.issued_at))}.</div>
        <p>Certificate ID: <code>${esc(certificate.id)}</code></p>
        <div class="btn-row">
          <a class="btn btn-dark" href="certificate.html?id=${encodeURIComponent(certificate.id)}">View your certificate</a>
          <a class="btn btn-outline" href="verify.html?id=${encodeURIComponent(certificate.id)}">Verification page</a>
        </div>`;
      return;
    }
    if (!passed) {
      box.innerHTML = '<p class="muted">Project submission opens after you pass the final exam.</p>';
      return;
    }
    if (latest && latest.status === 'pending') {
      box.innerHTML = `<div class="status" style="background:#EEF2FF;border:1px solid #C7D2FE;color:#1E2A5A"><strong>Submitted ${esc(day(latest.created_at))}.</strong>&nbsp;Your project is waiting for review. You'll see the result here.</div>
        <p class="muted" style="font-size:15px">Live site: <a href="${esc(latest.live_url)}" target="_blank" rel="noopener">${esc(latest.live_url)}</a></p>`;
      return;
    }
    box.innerHTML = latest && latest.status === 'rejected'
      ? `<div class="status bad"><strong>Almost there.</strong>&nbsp;Your project needs a few changes before it can be approved.</div>
         ${latest.feedback ? `<p><strong>Reviewer's note:</strong> ${esc(latest.feedback)}</p>` : ''}
         <p>Update your project, then submit it again below.</p>`
      : `<p>You passed the exam with <strong>${passed.score} of ${passed.total}</strong>. Submit your project to get your certificate.</p>`;
    form.hidden = false;
  }

  form.addEventListener('submit', async e => {
    e.preventDefault();
    if (!form.reportValidity()) return;
    const msg = $('project-message');
    const btn = form.querySelector('button[type=submit]');
    btn.disabled = true;
    const { error } = await client.rpc('submit_project', {
      p_course: COURSE, p_live_url: $('live-url').value.trim(), p_code_url: $('code-url').value.trim()
    });
    btn.disabled = false;
    if (error) {
      msg.hidden = false; msg.className = 'feedback bad';
      msg.textContent = ERRORS[(error.message || '').trim()] || ('Something went wrong. Details: ' + (error.message || error.code || 'no connection'));
      return;
    }
    msg.hidden = true;
    form.reset();
    load();
  });

  try { await load(); } catch (e) { box.innerHTML = '<p>Could not load your project status. Check your connection and refresh.</p>'; }
})();
