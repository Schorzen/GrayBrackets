-- GrayBrackets projects, certificates and admin review.
-- Paste all of this into Supabase: SQL Editor -> New query -> Run.
-- Then make yourself an admin with the one line at the very bottom.

-- 1. Admins (only people listed here can review projects)
create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- 2. Project submissions
create table if not exists public.project_submissions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  course text not null,
  live_url text not null check (live_url ~ '^https://' and char_length(live_url) <= 300),
  code_url text not null check (code_url ~ '^https://' and char_length(code_url) <= 300),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  feedback text check (char_length(feedback) <= 1000),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create index if not exists project_submissions_user on public.project_submissions (user_id, course, created_at desc);
alter table public.project_submissions enable row level security;
revoke all on public.project_submissions from anon, authenticated;
grant select on public.project_submissions to authenticated;
drop policy if exists "Students read own submissions" on public.project_submissions;
create policy "Students read own submissions"
  on public.project_submissions for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- 3. Certificates (read publicly only through verify_certificate)
create table if not exists public.certificates (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  course text not null,
  full_name text not null,
  score int not null,
  total int not null,
  live_url text not null,
  code_url text not null,
  issued_at timestamptz not null default now(),
  unique (user_id, course)
);
alter table public.certificates enable row level security;
revoke all on public.certificates from anon, authenticated;
grant select on public.certificates to authenticated;
drop policy if exists "Students read own certificates" on public.certificates;
create policy "Students read own certificates"
  on public.certificates for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- Course names and ID codes
create or replace function public.course_info(p_course text)
returns jsonb
language sql immutable set search_path = ''
as $$
  select case p_course
    when 'html-css' then '{"name":"HTML & CSS Foundations","code":"HC","skills":["Semantic HTML","Headings and text","Links and images","Lists and tables","CSS selectors and classes","Publishing with GitHub Pages"]}'::jsonb
    else null
  end;
$$;

-- 4. Student submits a project (after passing the exam)
create or replace function public.submit_project(p_course text, p_live_url text, p_code_url text)
returns bigint
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  v_id bigint;
begin
  if uid is null then raise exception 'not_logged_in'; end if;
  if public.course_info(p_course) is null then raise exception 'unknown_course'; end if;
  if not exists (select 1 from public.exam_attempts a where a.user_id = uid and a.course = p_course and a.passed) then
    raise exception 'pass_exam_first';
  end if;
  if exists (select 1 from public.certificates c where c.user_id = uid and c.course = p_course) then
    raise exception 'already_certified';
  end if;
  if exists (select 1 from public.project_submissions s where s.user_id = uid and s.course = p_course and s.status = 'pending') then
    raise exception 'already_pending';
  end if;
  p_live_url := trim(p_live_url);
  p_code_url := trim(p_code_url);
  if p_live_url !~ '^https://[^\s]+$' or p_code_url !~ '^https://[^\s]+$' then
    raise exception 'bad_links';
  end if;
  insert into public.project_submissions (user_id, course, live_url, code_url)
  values (uid, p_course, p_live_url, p_code_url)
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.submit_project(text, text, text) from public, anon;
grant execute on function public.submit_project(text, text, text) to authenticated;

-- 5. Admin: list submissions waiting for review
create or replace function public.admin_pending_projects()
returns table (id bigint, course text, full_name text, email text, live_url text, code_url text, created_at timestamptz)
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  return query
    select s.id, s.course,
           coalesce(nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''), '(no name)')::text,
           u.email::text, s.live_url, s.code_url, s.created_at
    from public.project_submissions s
    join auth.users u on u.id = s.user_id
    where s.status = 'pending'
    order by s.created_at;
end;
$$;
revoke execute on function public.admin_pending_projects() from public, anon;
grant execute on function public.admin_pending_projects() to authenticated;

-- 6. Admin: approve (issues the certificate) or send back with feedback
create or replace function public.review_project(p_submission_id bigint, p_approve boolean, p_feedback text default null)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  s public.project_submissions%rowtype;
  v_name text;
  v_score int;
  v_total int;
  v_code text;
  v_cert text;
  v_chars text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  i int;
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  select * into s from public.project_submissions where id = p_submission_id for update;
  if not found then raise exception 'not_found'; end if;
  if s.status <> 'pending' then raise exception 'already_reviewed'; end if;

  if not p_approve then
    update public.project_submissions
      set status = 'rejected', feedback = left(nullif(trim(p_feedback), ''), 1000), reviewed_at = now()
      where id = s.id;
    return null;
  end if;

  select coalesce(nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''), split_part(u.email, '@', 1))
    into v_name from auth.users u where u.id = s.user_id;
  select a.score, a.total into v_score, v_total
    from public.exam_attempts a
    where a.user_id = s.user_id and a.course = s.course and a.passed
    order by a.score desc, a.created_at limit 1;
  if v_score is null then raise exception 'pass_exam_first'; end if;

  v_code := public.course_info(s.course) ->> 'code';
  loop
    v_cert := 'GB-' || v_code || '-' || to_char(now(), 'YYYY') || '-';
    for i in 1..6 loop
      v_cert := v_cert || substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1);
    end loop;
    exit when not exists (select 1 from public.certificates c where c.id = v_cert);
  end loop;

  insert into public.certificates (id, user_id, course, full_name, score, total, live_url, code_url)
  values (v_cert, s.user_id, s.course, v_name, v_score, v_total, s.live_url, s.code_url);

  update public.project_submissions
    set status = 'approved', feedback = left(nullif(trim(p_feedback), ''), 1000), reviewed_at = now()
    where id = s.id;
  return v_cert;
end;
$$;
revoke execute on function public.review_project(bigint, boolean, text) from public, anon;
grant execute on function public.review_project(bigint, boolean, text) to authenticated;

-- 7. Anyone can verify a certificate by its ID (no email or account details are shown)
create or replace function public.verify_certificate(p_id text)
returns table (id text, full_name text, course text, course_name text, skills jsonb, score int, total int, live_url text, code_url text, issued_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select c.id, c.full_name, c.course,
         public.course_info(c.course) ->> 'name',
         public.course_info(c.course) -> 'skills',
         c.score, c.total, c.live_url, c.code_url, c.issued_at
  from public.certificates c
  where c.id = upper(trim(p_id));
$$;
revoke execute on function public.verify_certificate(text) from public;
grant execute on function public.verify_certificate(text) to anon, authenticated;

-- 8. MAKE YOURSELF AN ADMIN: put the email you used to sign up on the site, then run this line.
-- insert into public.admins (user_id) select id from auth.users where email = 'YOUR_EMAIL_HERE' on conflict do nothing;
