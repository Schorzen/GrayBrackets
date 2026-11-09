-- GrayBrackets final exam setup.
-- Paste all of this into Supabase: SQL Editor -> New query -> Run.
-- Students never see the answers: questions are read through get_exam(),
-- and grading happens on the server in submit_exam().

-- 1. Questions (no direct access for students)
create table if not exists public.exam_questions (
  id int generated always as identity primary key,
  course text not null,
  lesson int not null,
  question text not null,
  options jsonb not null,   -- [{"v":"a","t":"..."}, ...]
  correct text not null
);
alter table public.exam_questions enable row level security;
revoke all on public.exam_questions from anon, authenticated;

-- 2. Attempts (students can read their own; only submit_exam() writes)
create table if not exists public.exam_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  course text not null,
  score int not null,
  total int not null,
  passed boolean not null,
  created_at timestamptz not null default now()
);
create index if not exists exam_attempts_user_course on public.exam_attempts (user_id, course, created_at desc);
alter table public.exam_attempts enable row level security;
revoke all on public.exam_attempts from anon, authenticated;
grant select on public.exam_attempts to authenticated;
drop policy if exists "Students read own attempts" on public.exam_attempts;
create policy "Students read own attempts"
  on public.exam_attempts for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- 3. Get the exam (questions in random order, without answers)
create or replace function public.get_exam(p_course text)
returns table (id int, question text, options jsonb)
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_logged_in'; end if;
  if (select count(*) from public.lesson_progress lp where lp.user_id = uid and lp.course = p_course)
     < (select count(distinct q.lesson) from public.exam_questions q where q.course = p_course) then
    raise exception 'finish_lessons';
  end if;
  return query
    select q.id, q.question, q.options
    from public.exam_questions q
    where q.course = p_course
    order by random();
end;
$$;

-- 4. Submit and grade (80% to pass; 15-minute wait after a failed try)
create or replace function public.submit_exam(p_course text, p_answers jsonb)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  v_total int;
  v_score int;
  v_passed boolean;
  v_last_fail timestamptz;
  v_review int[];
begin
  if uid is null then raise exception 'not_logged_in'; end if;
  if (select count(*) from public.lesson_progress lp where lp.user_id = uid and lp.course = p_course)
     < (select count(distinct q.lesson) from public.exam_questions q where q.course = p_course) then
    raise exception 'finish_lessons';
  end if;

  select max(a.created_at) into v_last_fail
  from public.exam_attempts a
  where a.user_id = uid and a.course = p_course and not a.passed;
  if v_last_fail is not null and v_last_fail > now() - interval '15 minutes' then
    raise exception 'cooldown';
  end if;

  select count(*), count(*) filter (where q.correct = p_answers ->> q.id::text)
    into v_total, v_score
  from public.exam_questions q
  where q.course = p_course;

  select coalesce(array_agg(distinct q.lesson order by q.lesson), '{}')
    into v_review
  from public.exam_questions q
  where q.course = p_course and q.correct is distinct from (p_answers ->> q.id::text);

  v_passed := v_total > 0 and v_score * 100 >= v_total * 80;

  insert into public.exam_attempts (user_id, course, score, total, passed)
  values (uid, p_course, v_score, v_total, v_passed);

  return jsonb_build_object('score', v_score, 'total', v_total, 'passed', v_passed, 'review_lessons', to_jsonb(v_review));
end;
$$;

revoke execute on function public.get_exam(text) from public, anon;
revoke execute on function public.submit_exam(text, jsonb) from public, anon;
grant execute on function public.get_exam(text) to authenticated;
grant execute on function public.submit_exam(text, jsonb) to authenticated;

-- 5. HTML & CSS Foundations questions (re-running this file replaces them)
delete from public.exam_questions where course = 'html-css';
insert into public.exam_questions (course, lesson, question, options, correct) values
('html-css', 1, 'What does a web browser do?',
 '[{"v":"a","t":"Stores every website permanently on your phone"},{"v":"b","t":"Downloads a website''s files and shows them on your screen"},{"v":"c","t":"Writes the website''s code for you"}]', 'b'),
('html-css', 1, 'Which language makes buttons and menus respond when you tap them?',
 '[{"v":"a","t":"HTML"},{"v":"b","t":"CSS"},{"v":"c","t":"JavaScript"}]', 'c'),
('html-css', 1, 'Which language gives a web page its structure?',
 '[{"v":"a","t":"HTML"},{"v":"b","t":"CSS"},{"v":"c","t":"JavaScript"}]', 'a'),
('html-css', 2, 'What does <!doctype html> tell the browser?',
 '[{"v":"a","t":"The page title"},{"v":"b","t":"That this is a modern HTML page"},{"v":"c","t":"Where the body starts"}]', 'b'),
('html-css', 2, 'Where does the <title> element go?',
 '[{"v":"a","t":"Inside <head>"},{"v":"b","t":"Inside <body>"},{"v":"c","t":"After </html>"}]', 'a'),
('html-css', 2, 'What is the usual file name for a website''s home page?',
 '[{"v":"a","t":"home.txt"},{"v":"b","t":"index.html"},{"v":"c","t":"main.css"}]', 'b'),
('html-css', 2, 'Which of these is a complete paragraph element?',
 '[{"v":"a","t":"<p>Hello</p>"},{"v":"b","t":"<p>Hello"},{"v":"c","t":"Hello</p>"}]', 'a'),
('html-css', 3, 'Which heading level is the smallest?',
 '[{"v":"a","t":"<h1>"},{"v":"b","t":"<h3>"},{"v":"c","t":"<h6>"}]', 'c'),
('html-css', 3, 'Which tag marks text as important?',
 '[{"v":"a","t":"<strong>"},{"v":"b","t":"<em>"},{"v":"c","t":"<h6>"}]', 'a'),
('html-css', 3, 'You want a section title to look smaller. What is the best approach?',
 '[{"v":"a","t":"Use <h5> just because it is smaller"},{"v":"b","t":"Keep the correct heading level and change the size with CSS"},{"v":"c","t":"Use a <p> instead of a heading"}]', 'b'),
('html-css', 4, 'Which code creates a working link?',
 '[{"v":"a","t":"<a href=\"https://example.com\">Example</a>"},{"v":"b","t":"<link>https://example.com</link>"},{"v":"c","t":"<img href=\"https://example.com\">"}]', 'a'),
('html-css', 4, 'Which attribute makes a link open in a new tab?',
 '[{"v":"a","t":"href=\"_new\""},{"v":"b","t":"target=\"_blank\""},{"v":"c","t":"alt=\"tab\""}]', 'b'),
('html-css', 4, 'What is the best alt text for a photo of a jeepney?',
 '[{"v":"a","t":"image"},{"v":"b","t":"jeepney.jpg"},{"v":"c","t":"Red jeepney parked in front of a sari-sari store"}]', 'c'),
('html-css', 4, 'Which tag has no closing tag?',
 '[{"v":"a","t":"<img>"},{"v":"b","t":"<a>"},{"v":"c","t":"<p>"}]', 'a'),
('html-css', 5, 'You are writing the steps of a recipe in order. Which tag fits best?',
 '[{"v":"a","t":"<ul>"},{"v":"b","t":"<ol>"},{"v":"c","t":"<table>"}]', 'b'),
('html-css', 5, 'Each item in a <ul> or <ol> goes inside which tag?',
 '[{"v":"a","t":"<li>"},{"v":"b","t":"<td>"},{"v":"c","t":"<tr>"}]', 'a'),
('html-css', 5, 'Which tag is a header cell in a table?',
 '[{"v":"a","t":"<td>"},{"v":"b","t":"<th>"},{"v":"c","t":"<tr>"}]', 'b'),
('html-css', 5, 'When should you use a table?',
 '[{"v":"a","t":"To put a sidebar next to the main content"},{"v":"b","t":"To show data in rows and columns, like a price list"},{"v":"c","t":"To make text bigger"}]', 'b'),
('html-css', 6, 'In the CSS rule  p { color: red; }  what is p?',
 '[{"v":"a","t":"The property"},{"v":"b","t":"The selector"},{"v":"c","t":"The value"}]', 'b'),
('html-css', 6, 'Which CSS rule gives elements with class="sale" a gold background?',
 '[{"v":"a","t":".sale { background-color: gold; }"},{"v":"b","t":"#sale { background-color: gold; }"},{"v":"c","t":"sale { color: gold; }"}]', 'a');
