-- CBO On Tour – winners v1
-- Adds explicit event winner storage and a read-only round winner RPC.
-- Ordinary CBO rounds, points, stats and leaderboard are untouched.

begin;

-- ---------------------------------------------------------------------------
-- 1. EVENT WINNER
-- Event winner is stored explicitly because total competition rules can differ
-- between On Tour events. Non-CBO winners are supported through nullable
-- winner_player_id + required winner_name when a winner is set.
-- ---------------------------------------------------------------------------
alter table public.cbo_tour_events
  add column if not exists winner_player_id uuid references public.players(id) on delete set null;

alter table public.cbo_tour_events
  add column if not exists winner_name text;

alter table public.cbo_tour_events
  add column if not exists winner_source text;

alter table public.cbo_tour_events
  drop constraint if exists cbo_tour_events_winner_name_chk;

alter table public.cbo_tour_events
  add constraint cbo_tour_events_winner_name_chk
  check (winner_name is null or length(trim(winner_name)) between 1 and 120);

alter table public.cbo_tour_events
  drop constraint if exists cbo_tour_events_winner_source_chk;

alter table public.cbo_tour_events
  add constraint cbo_tour_events_winner_source_chk
  check (winner_source is null or winner_source in ('gamebook','manual','historical_import'));

comment on column public.cbo_tour_events.winner_name is
  'Explicit total event winner. Stored rather than inferred because event scoring rules may differ.';

comment on column public.cbo_tour_events.winner_player_id is
  'Optional link to a current CBO player. NULL is valid for historical/non-CBO winners.';

comment on column public.cbo_tour_events.winner_source is
  'Origin of the explicit event winner: gamebook, manual or historical_import.';

-- ---------------------------------------------------------------------------
-- 2. ROUND WINNERS
-- Rule: cbo_tour_rounds.primary_metric determines the result type used.
-- Preferred source is a full-round GameBook row with displayed_position = 1.
-- For rounds stored only as first9 + last9 segments, values are aggregated and
-- a winner is returned only when there is one unique best total.
-- Stableford: highest total wins. Stroke NET: lowest total wins.
-- ---------------------------------------------------------------------------
create or replace function public.cbo_tour_round_winners(p_event_id uuid)
returns table (
  round_id uuid,
  round_no integer,
  round_title text,
  primary_metric text,
  winner_player_id uuid,
  winner_name text,
  winner_result integer,
  winner_to_par integer,
  winner_basis text
)
language plpgsql
security definer
set search_path = public, extensions
stable
as $$
begin
  if not exists (
    select 1
    from public.player_credentials pc
    join public.players p on p.id = pc.player_id
    where pc.auth_user_id = auth.uid()
      and coalesce(p.active, true) = true
  ) then
    raise exception 'Aktivt CBO-medlemskap krävs.';
  end if;

  if not exists (
    select 1 from public.cbo_tour_events e where e.id = p_event_id
  ) then
    raise exception 'On Tour-eventet finns inte.';
  end if;

  return query
  with full_winner as (
    select distinct on (r.id)
      r.id as round_id,
      x.player_id,
      x.participant_name,
      x.result_value,
      x.to_par
    from public.cbo_tour_rounds r
    join public.cbo_tour_results x
      on x.round_id = r.id
     and x.metric = r.primary_metric
     and x.segment = 'full'
     and x.displayed_position = 1
    where r.event_id = p_event_id
      and r.primary_metric is not null
    order by r.id, x.id
  ),
  segmented_totals as (
    select
      r.id as round_id,
      r.primary_metric,
      lower(trim(x.participant_name)) as participant_key,
      min(x.player_id::text)::uuid as player_id,
      min(x.participant_name) as participant_name,
      sum(x.result_value)::integer as result_value,
      case when count(x.to_par) = count(*) then sum(x.to_par)::integer else null end as to_par,
      count(distinct x.segment) as segment_count
    from public.cbo_tour_rounds r
    join public.cbo_tour_results x
      on x.round_id = r.id
     and x.metric = r.primary_metric
     and x.segment in ('first9','last9')
    where r.event_id = p_event_id
      and r.primary_metric is not null
      and not exists (select 1 from full_winner fw where fw.round_id = r.id)
    group by r.id, r.primary_metric, lower(trim(x.participant_name))
    having count(distinct x.segment) = 2
  ),
  segmented_ranked as (
    select
      st.*,
      dense_rank() over (
        partition by st.round_id
        order by
          case when st.primary_metric = 'stroke_net' then st.result_value end asc nulls last,
          case when st.primary_metric = 'stableford_net' then st.result_value end desc nulls last
      ) as winner_rank,
      count(*) over (
        partition by st.round_id,
          case when st.primary_metric = 'stroke_net' then st.result_value end,
          case when st.primary_metric = 'stableford_net' then st.result_value end
      ) as tied_count
    from segmented_totals st
  ),
  segmented_winner as (
    select
      sr.round_id,
      sr.player_id,
      sr.participant_name,
      sr.result_value,
      sr.to_par
    from segmented_ranked sr
    where sr.winner_rank = 1
      and sr.tied_count = 1
  )
  select
    r.id,
    r.round_no,
    r.title,
    r.primary_metric,
    coalesce(fw.player_id, sw.player_id),
    coalesce(fw.participant_name, sw.participant_name),
    coalesce(fw.result_value, sw.result_value),
    coalesce(fw.to_par, sw.to_par),
    case
      when fw.round_id is not null then 'full_gamebook'
      when sw.round_id is not null then 'segments_aggregated'
      else null
    end
  from public.cbo_tour_rounds r
  left join full_winner fw on fw.round_id = r.id
  left join segmented_winner sw on sw.round_id = r.id
  where r.event_id = p_event_id
  order by r.round_no;
end;
$$;

revoke all on function public.cbo_tour_round_winners(uuid) from public;
revoke all on function public.cbo_tour_round_winners(uuid) from anon;
grant execute on function public.cbo_tour_round_winners(uuid) to authenticated;

commit;

-- Verification in Supabase SQL Editor:
-- 1) Columns
select column_name, data_type
from information_schema.columns
where table_schema='public'
  and table_name='cbo_tour_events'
  and column_name in ('winner_player_id','winner_name','winner_source')
order by column_name;

-- 2) RPC signature
select p.proname, pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname='cbo_tour_round_winners';
