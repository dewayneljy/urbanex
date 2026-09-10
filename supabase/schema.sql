-- ============================================================================
-- UrbanEx — Supabase schema
-- Run this once in Supabase Studio -> SQL Editor (or `supabase db push`).
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE where possible.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- profiles — one row per auth.users account (name, admin flag).
-- Supabase Auth already handles email + password; this just carries the
-- extra fields UrbanEx needs (name, isAdmin).
--
-- Created before is_admin() below, since Postgres checks a SQL function's
-- body against real tables/columns at CREATE FUNCTION time - it can't
-- reference public.profiles until the table exists.
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null unique,
  name        text not null default '',
  is_admin    boolean not null default false,
  created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- ---------------------------------------------------------------------------
-- Helper: is_admin() — SECURITY DEFINER so it can read `profiles` even
-- though RLS on `profiles` would otherwise block a plain query from within
-- another table's policy. Used everywhere we need "only an admin may..."
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

drop policy if exists "profiles_select_all" on public.profiles;
create policy "profiles_select_all" on public.profiles
  for select using (auth.role() = 'authenticated');

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

-- A user can edit their own row; an admin can edit anyone's (grant/revoke
-- admin, or as part of delete-account cleanup).
drop policy if exists "profiles_update_own_or_admin" on public.profiles;
create policy "profiles_update_own_or_admin" on public.profiles
  for update using (auth.uid() = id or public.is_admin());

drop policy if exists "profiles_delete_admin" on public.profiles;
create policy "profiles_delete_admin" on public.profiles
  for delete using (public.is_admin());

-- ---------------------------------------------------------------------------
-- favorites — now scoped per-account (previously one shared on-device list).
-- ---------------------------------------------------------------------------
create table if not exists public.favorites (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  fav_type    text not null,              -- 'state' | 'district'
  state       text not null,
  district    text,
  score       double precision not null,
  created_at  timestamptz not null default now(),
  unique (user_id, fav_type, state, district)
);

alter table public.favorites enable row level security;

drop policy if exists "favorites_owner_all" on public.favorites;
create policy "favorites_owner_all" on public.favorites
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- applications — school / business submissions.
-- The 30+ optional form fields are kept as JSONB (`payload`) so the schema
-- doesn't need a column per field; the handful of columns below are the
-- ones the app actually filters/sorts by.
-- ---------------------------------------------------------------------------
create table if not exists public.applications (
  id                text primary key,
  category          text not null,        -- 'school' | 'business'
  applicant_id      uuid not null references auth.users(id) on delete cascade,
  applicant_email   text not null,
  applicant_name    text not null,
  name              text not null,
  state             text not null,
  district          text,
  status            text not null default 'pending',
  review_note       text,
  reviewed_at       timestamptz,
  submitted_at      timestamptz not null default now(),
  payload           jsonb not null
);

alter table public.applications enable row level security;

drop policy if exists "applications_select_own_or_admin" on public.applications;
create policy "applications_select_own_or_admin" on public.applications
  for select using (auth.uid() = applicant_id or public.is_admin());

drop policy if exists "applications_insert_own" on public.applications;
create policy "applications_insert_own" on public.applications
  for insert with check (auth.uid() = applicant_id);

drop policy if exists "applications_update_admin" on public.applications;
create policy "applications_update_admin" on public.applications
  for update using (public.is_admin());

-- ---------------------------------------------------------------------------
-- feedback — contact form. Submission may be anonymous (no session), so
-- inserts are open; only an admin can read/reply/manage entries.
-- ---------------------------------------------------------------------------
create table if not exists public.feedback (
  id                  text primary key,
  category            text not null,
  name                text,
  email               text,
  message             text not null,
  submitted_at        timestamptz not null default now(),
  read                boolean not null default false,
  submitted_by        uuid references auth.users(id) on delete set null,
  submitted_by_email  text,
  admin_reply         text,
  replied_at          timestamptz,
  replied_by_email    text
);

alter table public.feedback enable row level security;

drop policy if exists "feedback_insert_anyone" on public.feedback;
create policy "feedback_insert_anyone" on public.feedback
  for insert with check (true);

drop policy if exists "feedback_select_admin" on public.feedback;
create policy "feedback_select_admin" on public.feedback
  for select using (public.is_admin());

drop policy if exists "feedback_update_admin" on public.feedback;
create policy "feedback_update_admin" on public.feedback
  for update using (public.is_admin());

drop policy if exists "feedback_delete_admin" on public.feedback;
create policy "feedback_delete_admin" on public.feedback
  for delete using (public.is_admin());

-- ---------------------------------------------------------------------------
-- notifications — per-recipient. System notifications (feedback replies,
-- application decisions) are inserted by an admin action on someone else's
-- behalf, so insert is allowed for the recipient themselves OR an admin.
-- ---------------------------------------------------------------------------
create table if not exists public.notifications (
  id                        text primary key,
  type                      text not null,
  title                     text not null,
  body                      text not null,
  created_at                timestamptz not null default now(),
  read                      boolean not null default false,
  recipient_id              uuid not null references auth.users(id) on delete cascade,
  recipient_email           text,
  related_feedback_id       text,
  related_application_id    text,
  related_district_state    text,
  related_district_name     text,
  related_news_id           text,
  application_status        text
);

alter table public.notifications enable row level security;

-- Admins get a bypass on select/update/delete too (not just insert):
-- editing or deleting a district-news post touches every recipient's
-- notification about it, not just the admin's own.
drop policy if exists "notifications_select_own_or_admin" on public.notifications;
create policy "notifications_select_own_or_admin" on public.notifications
  for select using (auth.uid() = recipient_id or public.is_admin());

drop policy if exists "notifications_insert_own_or_admin" on public.notifications;
create policy "notifications_insert_own_or_admin" on public.notifications
  for insert with check (auth.uid() = recipient_id or public.is_admin());

drop policy if exists "notifications_update_own_or_admin" on public.notifications;
create policy "notifications_update_own_or_admin" on public.notifications
  for update using (auth.uid() = recipient_id or public.is_admin());

drop policy if exists "notifications_delete_own_or_admin" on public.notifications;
create policy "notifications_delete_own_or_admin" on public.notifications
  for delete using (auth.uid() = recipient_id or public.is_admin());

-- ---------------------------------------------------------------------------
-- district_news — admin-authored posts, visible to everyone signed in.
-- ---------------------------------------------------------------------------
create table if not exists public.district_news (
  id              text primary key,
  state           text not null,
  district        text not null,
  title           text not null,
  body            text not null,
  posted_at       timestamptz not null default now(),
  posted_by       uuid references auth.users(id) on delete set null,
  posted_by_email text not null
);

alter table public.district_news enable row level security;

drop policy if exists "district_news_select_all" on public.district_news;
create policy "district_news_select_all" on public.district_news
  for select using (auth.role() = 'authenticated');

drop policy if exists "district_news_write_admin" on public.district_news;
create policy "district_news_write_admin" on public.district_news
  for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- district_reviews — user-authored star ratings, visible to everyone.
-- ---------------------------------------------------------------------------
create table if not exists public.district_reviews (
  id            text primary key,
  state         text not null,
  district      text not null,
  author_id     uuid not null references auth.users(id) on delete cascade,
  author_email  text not null,
  author_name   text not null,
  rating        int not null check (rating between 0 and 5),
  comment       text not null default '',
  image         jsonb,
  created_at    timestamptz not null default now()
);

alter table public.district_reviews enable row level security;

drop policy if exists "district_reviews_select_all" on public.district_reviews;
create policy "district_reviews_select_all" on public.district_reviews
  for select using (auth.role() = 'authenticated');

drop policy if exists "district_reviews_insert_own" on public.district_reviews;
create policy "district_reviews_insert_own" on public.district_reviews
  for insert with check (auth.uid() = author_id);

drop policy if exists "district_reviews_delete_own_or_admin" on public.district_reviews;
create policy "district_reviews_delete_own_or_admin" on public.district_reviews
  for delete using (auth.uid() = author_id or public.is_admin());

-- ---------------------------------------------------------------------------
-- district_issues — bug/data reports, may be anonymous; admin-only reading.
-- ---------------------------------------------------------------------------
create table if not exists public.district_issues (
  id              text primary key,
  state           text not null,
  district        text not null,
  category        text not null,
  description     text not null,
  reporter_name   text,
  reporter_email  text,
  reporter_id     uuid references auth.users(id) on delete set null,
  submitted_at    timestamptz not null default now(),
  read            boolean not null default false,
  resolved        boolean not null default false
);

alter table public.district_issues enable row level security;

drop policy if exists "district_issues_insert_anyone" on public.district_issues;
create policy "district_issues_insert_anyone" on public.district_issues
  for insert with check (true);

drop policy if exists "district_issues_select_admin" on public.district_issues;
create policy "district_issues_select_admin" on public.district_issues
  for select using (public.is_admin());

drop policy if exists "district_issues_update_admin" on public.district_issues;
create policy "district_issues_update_admin" on public.district_issues
  for update using (public.is_admin());

drop policy if exists "district_issues_delete_admin" on public.district_issues;
create policy "district_issues_delete_admin" on public.district_issues
  for delete using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Seed data — the same sample district-news posts the old local build
-- generated on first launch. Inserted once here (bypasses RLS because it
-- runs as the table owner in the SQL editor) so every device sees the same
-- shared feed instead of each device seeding its own copy.
-- ---------------------------------------------------------------------------
insert into public.district_news (id, state, district, title, body, posted_at, posted_by_email)
values
  ('seed-0','Sarawak','Kuching','Coastal flood mitigation project begins in Kuching','Drainage upgrade works have started along the riverside districts to reduce flooding during the monsoon season. Expect temporary lane closures near the waterfront over the coming weeks.', now() - interval '6 hours','admin@urbanex.local'),
  ('seed-1','Sarawak','Kuching','Kuching Waterfront to host month-long cultural festival','A programme of food stalls, craft markets, and evening performances kicks off this month along the waterfront promenade, running through to the end of the month.', now() - interval '2 days','admin@urbanex.local'),
  ('seed-2','Selangor','Petaling','New rail stations open along the Petaling corridor','Two additional stations have opened for service, cutting commute times for residents in the surrounding neighbourhoods and easing congestion on nearby main roads.', now() - interval '18 hours','admin@urbanex.local'),
  ('seed-3','Selangor','Petaling','SME digitalisation grant applications now open','Small businesses registered in the district can now apply for a grant covering point-of-sale systems and e-commerce setup. Applications close at the end of next month.', now() - interval '4 days','admin@urbanex.local'),
  ('seed-4','Johor','Johor Bahru','RTS Link construction reaches key milestone','The cross-border rail link connecting Johor Bahru to Singapore has completed a major structural milestone, keeping the project on track for its planned opening.', now() - interval '27 hours','admin@urbanex.local'),
  ('seed-5','Johor','Johor Bahru','New vocational college campus announced','A new campus focused on technical and vocational training is set to open, adding several hundred intake places for school leavers in the district.', now() - interval '6 days','admin@urbanex.local'),
  ('seed-6','W.P. Kuala Lumpur','Kuala Lumpur','Cashless parking zones expanded downtown','City Hall has extended cashless-only parking to several additional streets in the city centre as part of a wider digital payments rollout.', now() - interval '9 hours','admin@urbanex.local'),
  ('seed-7','W.P. Kuala Lumpur','Kuala Lumpur','Community health screening drive launched','Free basic health screenings are being offered at community halls across the district this month, covering blood pressure, blood sugar, and BMI checks.', now() - interval '3 days','admin@urbanex.local'),
  ('seed-8','Sabah','Kota Kinabalu','Port upgrade to boost trade capacity','Expansion works at the port are underway to increase container handling capacity, supporting growing trade volumes through the district.', now() - interval '44 hours','admin@urbanex.local'),
  ('seed-9','Sabah','Kota Kinabalu','Local schools receive new computer labs','Several primary and secondary schools in the district have been equipped with new computer labs as part of a digital literacy programme.', now() - interval '5 days','admin@urbanex.local'),
  ('seed-10','Pulau Pinang','Timur Laut','George Town heritage zone gets pedestrian upgrade','Streets within the UNESCO heritage zone are being repaved with wider pedestrian walkways and improved lighting, with work expected to continue in phases.', now() - interval '52 hours','admin@urbanex.local'),
  ('seed-11','Pulau Pinang','Timur Laut','New startup incubator opens its doors','A technology-focused startup incubator has opened, offering co-working space and mentorship for early-stage founders based in the district.', now() - interval '8 days','admin@urbanex.local'),
  ('seed-12','Perak','Kinta','Ipoh old town revitalisation enters second phase','Facade restoration and street upgrades in the old town area are moving into their next phase, building on the first phase completed earlier this year.', now() - interval '14 hours','admin@urbanex.local'),
  ('seed-13','Perak','Kinta','District clinics extend weekend operating hours','Government clinics across the district will now open on Saturday afternoons to reduce weekday waiting times for routine consultations.', now() - interval '4 days','admin@urbanex.local'),
  ('seed-14','Pahang','Kuantan','Port expansion progresses ahead of schedule','Expansion works at Kuantan Port are reported to be ahead of schedule, with the new berth expected to be operational sooner than originally planned.', now() - interval '27 hours','admin@urbanex.local'),
  ('seed-15','Pahang','Kuantan','Coastal cleanup initiative launched','A community-led beach and river cleanup programme has launched, with volunteer sessions scheduled every other weekend for the next few months.', now() - interval '7 days','admin@urbanex.local'),
  ('seed-16','Negeri Sembilan','Seremban','New public library and community hub opens','A new library and community hub has opened, offering study spaces, a children''s reading corner, and meeting rooms available for public booking.', now() - interval '58 hours','admin@urbanex.local'),
  ('seed-17','Negeri Sembilan','Seremban','Business incentive zone announced for industrial park','Tax incentives have been announced for new manufacturers setting up in the district''s industrial park, aimed at attracting investment over the next few years.', now() - interval '9 days','admin@urbanex.local'),
  ('seed-18','Kelantan','Kota Bharu','Flood early-warning system upgraded','The district''s flood early-warning system has been upgraded ahead of the monsoon season, with SMS alerts now covering more low-lying neighbourhoods.', now() - interval '20 hours','admin@urbanex.local'),
  ('seed-19','Kelantan','Kota Bharu','Heritage craft market revitalised in old town','The old town''s traditional craft market has reopened after renovation, with additional stalls for local batik and songket artisans.', now() - interval '5 days','admin@urbanex.local')
on conflict (id) do nothing;
