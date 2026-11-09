# GrayBrackets

Free web development courses in English and Taglish, with free verifiable certificates.

## Pages

- `index.html` — homepage with the learning path and a Practice button for each course
- `lesson.html` — sample lesson with a live code editor and a quick quiz
- `verify.html` — certificate verification (`verify.html?id=GB-FE-2026-7Q4K9`)
- `certificate.html` — printable sample certificate (Download as PDF uses the browser's print)

## Practice books (external, linked only)

| Course | Practice link |
|---|---|
| HTML & CSS Foundations | https://developer.mozilla.org/en-US/docs/Learn_web_development |
| Responsive Design | https://web.dev/learn/design/welcome |
| JavaScript Essentials | https://eloquentjavascript.net/ |
| Full-Stack Projects | https://fullstackopen.com/en/ |

These are linked, not copied. They belong to their authors.

## Put it live with GitHub Pages

1. Push these files to the `main` branch of a public repository.
2. In the repository, go to **Settings → Pages**.
3. Under **Build and deployment**, choose **Deploy from a branch**, then `main` and `/ (root)`, and save.
4. After a minute or two, the site is live at `https://<username>.github.io/<repository>/`.

## Before launch

- Fill in `[Signature]` and `[Founder Name]` on the certificate.
- Move certificate records and exam answers to a database (for example Supabase). Right now they are sample data inside the page.

## Student accounts (Supabase)

- `supabase-config.js` holds the Project URL and **publishable** key (safe to be public). Never put the secret key here.
- `setup.sql` creates the `lesson_progress` table with Row Level Security. Run it once in Supabase → SQL Editor.
- `account.html` handles sign up, log in, password reset and log out.
- Lesson 1 is a free preview. Lessons 2–6 and the final page ask for a free account once Supabase is connected.
- Until the config is filled in, the site works without accounts and saves progress on the device.

## Final exam

- `exam.sql` creates the exam tables, the 20 questions, and two server functions: `get_exam` (questions without answers) and `submit_exam` (grades on the server, 80% to pass, 15-minute wait after a failed try). Run it once in Supabase → SQL Editor. Re-running it replaces the questions.
- `exam.html` is the exam page. Students must finish all 6 lessons first.
