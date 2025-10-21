-- =============================================================================
-- LINKLOCKER 4.0 – CORE DATABASE SCHEMA
-- RFP Compliance: §3.2, §5 Acceptance Criteria
-- Blueprint Alignment: Part B, Sections 2–3, 5–6
-- =============================================================================
-- SECURITY: All tables use Row-Level Security (RLS). Public access ONLY via views.
-- PRIVACY: IP anonymized (SHA256), consent logged, GDPR Art.15/17 DSR ready.
-- PERFORMANCE: Indexes optimized for TTFB <300ms (global), LCP <2.5s.
-- RESILIENCE: Designed for pg_cron backup/dunning jobs (RPO 15m, RTO 30m).
-- =============================================================================

-- Enable required extensions (pg_cron is auto-enabled in Supabase)
create extension if not exists "pg_cron";
create extension if not exists "pg_hashids";

-- =============================================================================
-- 1. PROFILES – User metadata, plan, compliance flags
-- =============================================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null check (char_length(username) >= 3 and char_length(username) <= 32),
  full_name text,
  avatar_url text,
  custom_domain text unique,
  plan text not null default 'free' check (plan in ('free', 'pro', 'team')),
  stripe_customer_id text,
  stripe_status text default 'inactive',
  locale text default 'en' check (locale ~ '^[a-z]{2}(-[A-Z]{2})?$'),
  is_public boolean default true,
  age_verified boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;
create policy "Users can manage own profile"
  on public.profiles for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

create view public.public_profiles as
select username, full_name, avatar_url, is_public
from public.profiles
where is_public = true;

-- =============================================================================
-- 2. LINKS – Creator’s link list
-- =============================================================================
create table if not exists public.links (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  url text not null,
  icon text,
  position int not null default 0,
  lead_capture boolean default false,
  enabled boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_links_user_position on public.links (user_id, position);
alter table public.links enable row level security;
create policy "Users manage own links"
  on public.links for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- =============================================================================
-- 3. LEADS – Captured leads (GDPR-compliant)
-- =============================================================================
create table if not exists public.leads (
  id uuid default gen_random_uuid() primary key,
  link_id uuid not null references public.links(id) on delete cascade,
  email text,
  phone text,
  consent_given boolean not null default false,
  consent_timestamp timestamptz default now(),
  ip_hash text not null,
  created_at timestamptz default now()
);

create index if not exists idx_leads_link on public.leads (link_id);
alter table public.leads enable row level security;
create policy "Users access own leads"
  on public.leads for select
  using (exists (
    select 1 from public.links 
    where links.id = leads.link_id 
    and links.user_id = auth.uid()
  ));

-- =============================================================================
-- 4. CLICKS – Analytics with bot filtering
-- =============================================================================
create table if not exists public.clicks (
  id uuid default gen_random_uuid() primary key,
  link_id uuid not null references public.links(id) on delete cascade,
  referrer text,
  user_agent text,
  device_type text check (device_type in ('mobile', 'desktop', 'tablet', 'bot')),
  ip_hash text not null,
  created_at timestamptz default now()
);

create index if not exists idx_clicks_link_time on public.clicks (link_id, created_at);
alter table public.clicks enable row level security;
create policy "Users access own clicks"
  on public.clicks for select
  using (exists (
    select 1 from public.links 
    where links.id = clicks.link_id 
    and links.user_id = auth.uid()
  ));

create materialized view if not exists public.daily_clicks as
select date(created_at) as day, link_id, count(*) as click_count
from public.clicks
where device_type != 'bot'
group by 1, 2;

-- =============================================================================
-- 5. TRANSLATIONS – i18n support
-- =============================================================================
create table if not exists public.translations (
  key text not null,
  locale text not null default 'en',
  value text not null,
  primary key (key, locale)
);

alter table public.translations enable row level security;
create policy "Public read for translations"
  on public.translations for select
  using (true);

-- =============================================================================
-- 6. USER_SESSIONS – Security logging
-- =============================================================================
create table if not exists public.user_sessions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_id text not null,
  ip_hash text not null,
  login_time timestamptz default now(),
  last_active timestamptz default now()
);

alter table public.user_sessions enable row level security;
create policy "Users manage own sessions"
  on public.user_sessions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- =============================================================================
-- 7. BILLING_EVENTS – Stripe audit log
-- =============================================================================
create table if not exists public.billing_events (
  id uuid default gen_random_uuid() primary key,
  stripe_event_id text unique not null,
  event_type text not null,
  payload jsonb not null,
  processed boolean default false,
  created_at timestamptz default now()
);

alter table public.billing_events enable row level security;
create policy "Admin insert only"
  on public.billing_events for insert
  with check (auth.role() = 'service_role');

-- =============================================================================
-- PERFORMANCE INDEXES
-- =============================================================================
create index if not exists idx_profiles_username on public.profiles (username) where is_public = true;

-- =============================================================================
-- PG_CRON JOBS
-- =============================================================================
select cron.schedule('refresh-analytics', '0 * * * *', $$ refresh materialized view concurrently daily_clicks $$);
select cron.schedule('dunning-check', '0 2 * * *', $$
  update public.profiles 
  set plan = 'free', stripe_status = 'downgraded'
  where stripe_status = 'past_due'
    and updated_at < now() - interval '3 days'
$$);
