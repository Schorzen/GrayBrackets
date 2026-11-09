// GrayBrackets lesson page behavior: code editor, quizzes, progress, copy deterrent.
(function () {
  const TOTAL = 6;
  const KEY = 'gb-course01-done';
  const lesson = Number(document.body.dataset.lesson);

  // --- Progress (saved in this browser only, until student accounts exist) ---
  function loadDone() {
    try { return new Set(JSON.parse(localStorage.getItem(KEY) || '[]')); } catch (e) { return new Set(); }
  }
  function saveDone(set) {
    try { localStorage.setItem(KEY, JSON.stringify([...set])); } catch (e) {}
  }
  function renderProgress() {
    const done = loadDone();
    const pct = Math.round((done.size / TOTAL) * 100);
    const fill = document.getElementById('progress-fill');
    const text = document.getElementById('progress-text');
    const bar = fill && fill.parentElement;
    if (fill) fill.style.width = pct + '%';
    if (text) text.textContent = pct + '%';
    if (bar) bar.setAttribute('aria-valuenow', pct);
    document.querySelectorAll('[data-lesson-link]').forEach(a => {
      const n = Number(a.dataset.lessonLink);
      const mark = a.querySelector('.mark');
      a.classList.toggle('is-done', done.has(n));
      if (mark) mark.textContent = done.has(n) ? '✓' : (n === lesson ? '●' : '○');
      a.classList.toggle('todo', !done.has(n) && n !== lesson);
    });
  }
  renderProgress();

  // --- Code editor ---
  const editor = document.getElementById('code-editor');
  const preview = document.getElementById('preview');
  if (editor && preview) {
    const starter = editor.defaultValue;
    const run = () => {
      preview.srcdoc = '<!doctype html><meta charset="utf-8"><base href="' + location.href.replace(/[^/]*$/, '') + '" target="_blank">' +
        '<style>body{font-family:Georgia,serif;padding:12px;margin:0;color:#12213A}table{border-collapse:collapse}th,td{padding:4px 10px}</style>' +
        editor.value;
    };
    run();
    document.getElementById('run-code').addEventListener('click', run);
    document.getElementById('reset-code').addEventListener('click', () => { editor.value = starter; run(); });

    // Tab inserts two spaces. Press Esc first if you want Tab to leave the editor.
    let escaped = false;
    editor.addEventListener('keydown', e => {
      if (e.key === 'Escape') { escaped = true; return; }
      if (e.key === 'Tab' && !e.shiftKey && !e.altKey && !e.ctrlKey && !e.metaKey) {
        if (escaped) { escaped = false; return; }
        e.preventDefault();
        editor.setRangeText('  ', editor.selectionStart, editor.selectionEnd, 'end');
      } else {
        escaped = false;
      }
    });
  }

  // --- Quiz (practice only; the real exam will be checked on a server) ---
  const quiz = document.getElementById('quiz');
  if (quiz) {
    quiz.addEventListener('submit', e => {
      e.preventDefault();
      const sets = [...quiz.querySelectorAll('fieldset[data-answer]')];
      let correct = 0, answered = 0;
      sets.forEach(fs => {
        const picked = fs.querySelector('input:checked');
        const fb = fs.querySelector('.feedback');
        fb.hidden = false;
        if (!picked) { fb.className = 'feedback bad'; fb.textContent = 'Pick an answer first.'; return; }
        answered++;
        if (picked.value === fs.dataset.answer) { correct++; fb.className = 'feedback ok'; fb.textContent = fs.dataset.ok; }
        else { fb.className = 'feedback bad'; fb.textContent = fs.dataset.bad; }
      });
      const summary = document.getElementById('quiz-summary');
      summary.hidden = false;
      if (correct === sets.length) {
        const done = loadDone(); done.add(lesson); saveDone(done); renderProgress();
        summary.className = 'feedback ok';
        summary.textContent = lesson < TOTAL
          ? 'Ang galing! Lesson complete. Go on to the next lesson when you are ready.'
          : 'Ang galing! You finished every lesson. Head to the final exam and project.';
      } else {
        summary.className = 'feedback bad';
        summary.textContent = `${correct} of ${sets.length} correct. Review the lesson and try again.`;
      }
    });
  }

  // --- Copy deterrent on lesson text only (code examples stay copyable) ---
  document.querySelectorAll('.protected').forEach(el => {
    ['contextmenu', 'copy', 'cut', 'dragstart'].forEach(ev => el.addEventListener(ev, e => e.preventDefault()));
  });

  document.querySelectorAll('.year').forEach(e => { e.textContent = new Date().getFullYear(); });
})();
