-- CBO On Tour – schema v1
-- Isolated from ordinary CBO rounds/round_results.
-- Purpose: historical and future non-CBO tour events that must never affect
-- attendance, CBO points, Totalen, Netto, Brutto, Effektivitet or Topp 8.

begin;

-- ---------------------------------------------------------------------------
-- 1. EVENTS
-- ---------------------------------------------------------------------------
create table if not exists public.cbo_tour_events (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 120),
  event_year integer not null check (event_year between 1900 and 2200),
  starts_on date,
  ends_on date,
  location text,
  notes text,
  results_complete boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  constraint cbo_tour_events_date_order_chk
    check (starts_on is null or ends_on is null or ends_on >= starts_on)
);

create unique index if not exists cbo_tour_events_name_year_uq
  on public.cbo_tour_events (lower(trim(name)), event_year);

-- ---------------------------------------------------------------------------
-- 2. ROUNDS
-- A competition round is one row even when GameBook displays first/last 9
-- as separate sub-results. Those sub-results live in cbo_tour_results.segment.
-- ---------------------------------------------------------------------------
create table if not exists public.cbo_tour_rounds (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.cbo_tour_events(id) on delete cascade,
  round_no integer not null check (round_no >= 1),
  title text,
  played_on date,
  course text,
  holes integer not null default 18 check (holes in (9,18)),
  round_type text not null default 'individual'
    check (round_type in ('individual','scramble','team','other')),
  notes text,
  results_complete boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  unique (event_id, round_no)
);

create index if not exists cbo_tour_rounds_event_idx
  on public.cbo_tour_rounds(event_id, round_no);
create index if not exists cbo_tour_rounds_played_on_idx
  on public.cbo_tour_rounds(played_on);

-- ---------------------------------------------------------------------------
-- 3. INDIVIDUAL RESULTS
-- One row = one displayed GameBook result for one participant, metric and
-- segment. This intentionally preserves historical display data rather than
-- recalculating it.
--
-- player_id is nullable: historical tours may contain non-CBO participants.
-- participant_name is always stored so the historical leaderboard remains
-- faithful even if no CBO player record exists.
-- ---------------------------------------------------------------------------
create table if not exists public.cbo_tour_results (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.cbo_tour_rounds(id) on delete cascade,
  player_id uuid references public.players(id) on delete set null,
  participant_name text not null check (length(trim(participant_name)) between 1 and 120),
  displayed_hcp numeric(6,2),
  segment text not null default 'full'
    check (segment in ('full','first9','last9')),
  metric text not null
    check (metric in ('stroke_net','stableford_net')),
  result_value integer not null,
  to_par integer,
  displayed_position integer check (displayed_position is null or displayed_position >= 1),
  source text not null default 'gamebook'
    check (source in ('gamebook','manual','historical_import')),
  source_ref text,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now()
);

create unique index if not exists cbo_tour_results_identity_uq
  on public.cbo_tour_results (
    round_id,
    segment,
    metric,
    lower(trim(participant_name))
  );

create index if not exists cbo_tour_results_round_idx
  on public.cbo_tour_results(round_id, metric, segment, displayed_position);
create index if not exists cbo_tour_results_player_idx
  on public.cbo_tour_results(player_id)
  where player_id is not null;

-- ---------------------------------------------------------------------------
-- 4. SIDE CONTESTS
-- Examples: nearest pin / longest drive. Kept outside individual round scoring.
-- ---------------------------------------------------------------------------
create table if not exists public.cbo_tour_side_contests (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.cbo_tour_rounds(id) on delete cascade,
  contest_type text not null
    check (contest_type in ('nearest_pin','longest_drive','other')),
  hole integer check (hole is null or hole between 1 and 18),
  participant_name text not null check (length(trim(participant_name)) between 1 and 120),
  player_id uuid references public.players(id) on delete set null,
  placement integer check (placement is null or placement >= 1),
  value numeric,
  unit text,
  note text,
  source text not null default 'gamebook'
    check (source in ('gamebook','manual','historical_import')),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid()
);

create index if not exists cbo_tour_side_contests_round_idx
  on public.cbo_tour_side_contests(round_id, contest_type, hole, placement);

-- ---------------------------------------------------------------------------
-- 5. RLS
-- Only authenticated, active CBO members may read On Tour data.
-- Direct client writes are intentionally not granted. Future writes should go
-- through dedicated admin-only SECURITY DEFINER RPCs.
-- ---------------------------------------------------------------------------
alter table public.cbo_tour_events enable row level security;
alter table public.cbo_tour_rounds enable row level security;
alter table public.cbo_tour_results enable row level security;
alter table public.cbo_tour_side_contests enable row level security;

revoke all on public.cbo_tour_events from anon;
revoke all on public.cbo_tour_rounds from anon;
revoke all on public.cbo_tour_results from anon;
revoke all on public.cbo_tour_side_contests from anon;

revoke insert, update, delete on public.cbo_tour_events from authenticated;
revoke insert, update, delete on public.cbo_tour_rounds from authenticated;
revoke insert, update, delete on public.cbo_tour_results from authenticated;
revoke insert, update, delete on public.cbo_tour_side_contests from authenticated;

grant select on public.cbo_tour_events to authenticated;
grant select on public.cbo_tour_rounds to authenticated;
grant select on public.cbo_tour_results to authenticated;
grant select on public.cbo_tour_side_contests to authenticated;

drop policy if exists cbo_tour_events_member_read on public.cbo_tour_events;
create policy cbo_tour_events_member_read
on public.cbo_tour_events
for select
to authenticated
using (
  exists (
    select 1
    from public.player_credentials pc
    join public.players p on p.id = pc.player_id
    where pc.auth_user_id = auth.uid()
      and coalesce(p.active, true) = true
  )
);

drop policy if exists cbo_tour_rounds_member_read on public.cbo_tour_rounds;
create policy cbo_tour_rounds_member_read
on public.cbo_tour_rounds
for select
to authenticated
using (
  exists (
    select 1
    from public.player_credentials pc
    join public.players p on p.id = pc.player_id
    where pc.auth_user_id = auth.uid()
      and coalesce(p.active, true) = true
  )
);

drop policy if exists cbo_tour_results_member_read on public.cbo_tour_results;
create policy cbo_tour_results_member_read
on public.cbo_tour_results
for select
to authenticated
using (
  exists (
    select 1
    from public.player_credentials pc
    join public.players p on p.id = pc.player_id
    where pc.auth_user_id = auth.uid()
      and coalesce(p.active, true) = true
  )
);

drop policy if exists cbo_tour_side_contests_member_read on public.cbo_tour_side_contests;
create policy cbo_tour_side_contests_member_read
on public.cbo_tour_side_contests
for select
to authenticated
using (
  exists (
    select 1
    from public.player_credentials pc
    join public.players p on p.id = pc.player_id
    where pc.auth_user_id = auth.uid()
      and coalesce(p.active, true) = true
  )
);

commit;

-- Verification after running in Supabase SQL Editor:
--
-- select table_name
-- from information_schema.tables
-- where table_schema='public'
--   and table_name in (
--     'cbo_tour_events',
--     'cbo_tour_rounds',
--     'cbo_tour_results',
--     'cbo_tour_side_contests'
--   )
-- order by table_name;
--
-- select schemaname, tablename, policyname, roles, cmd
-- from pg_policies
-- where schemaname='public'
--   and tablename like 'cbo_tour_%'
-- order by tablename, policyname;
