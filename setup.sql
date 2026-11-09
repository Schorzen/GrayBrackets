-- GrayBrackets database setup.
-- Paste all of this into Supabase: SQL Editor -> New query -> Run.

-- Which lessons each student has finished.
create table if not exists public.lesson_progress (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  course text not null check (char_length(course) <= 50),
  lesson int not null check (lesson between 1 and 100),
  completed_at timestamptz not null default now(),
  primary key (user_id, course, lesson)
);

-- Row Level Security: students can only see and change their own progress.
alter table public.lesson_progress enable row level security;

drop policy if exists "Students read own progress" on public.lesson_progress;
create policy "Students read own progress"
  on public.lesson_progress for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Students add own progress" on public.lesson_progress;
create policy "Students add own progress"
  on public.lesson_progress for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

grant select, insert on public.lesson_progress to authenticated;
