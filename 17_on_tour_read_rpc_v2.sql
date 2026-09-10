-- CBO On Tour – read RPCs v2
-- Extends member read contract with explicit event winner, primary metric and
-- round winner data. Ordinary CBO tables/RPCs remain untouched.

begin;

-- ---------------------------------------------------------------------------
-- 1. EVENT FEED
-- Return event winner directly for On Tour overview cards.
-- Return type changes from v1, so drop/recreate is required.
-- ---------------------------------------------------------------------------
drop function if exists public.cbo_tour_events_feed();

create function public.cbo_tour_events_feed()
returns table (
  id uuid,
  name text,
  event_year integer,
  starts_on date,
  ends_on date,
  location text,
  notes text,
  results_complete boolean,
  round_count bigint,
  winner_player_id uuid,
  winner_name text,
  winner_source text
)
language sql
security definer
set search_path = public, extensions
stable
as $$
  select
    e.id,
    e.name,
    e.event_year,
    e.starts_on,
    e.ends_on,
    e.location,
    e.notes,
    e.results_complete,
    count(r.id) as round_count,
    e.winner_player_id,
    e.winner_name,
    e.winner_source
  from public.cbo_tour_events e
  left join public.cbo_tour_rounds r on r.event_id = e.id
  where exists (
    select 1
    from public.player_credentials pc
    join public.players p on p.id = pc.player_id
    where pc.auth_user_id = auth.uid()
      and coalesce(p.active, true) = true
  )
  group by e.id
  order by e.event_year desc, e.starts_on desc nulls last, lower(e.name);
$$;

revoke all on function public.cbo_tour_events_feed() from public;
revoke all on function public.cbo_tour_events_feed() from anon;
grant execute on function public.cbo_tour_events_feed() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. EVENT DETAIL
-- Adds event winner plus primary_metric and derived winner per round.
-- Winner is NULL when source data is incomplete/ambiguous; no guessing.
-- ---------------------------------------------------------------------------
create or replace function public.cbo_tour_event_detail(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
stable
as $$
declare
  v_member boolean;
  v_event jsonb;
begin
  select exists (
    select 1
    from public.player_credentials pc
    join public.players p on p.id = pc.player_id
    where pc.auth_user_id = auth.uid()
      and coalesce(p.active, true) = true
  ) into v_member;

  if not v_member then
    return jsonb_build_object('ok', false, 'error', 'Aktivt CBO-medlemskap krävs.');
  end if;

  select jsonb_build_object(
    'id', e.id,
    'name', e.name,
    'event_year', e.event_year,
    'starts_on', e.starts_on,
    'ends_on', e.ends_on,
    'location', e.location,
    'notes', e.notes,
    'results_complete', e.results_complete,
    'winner_player_id', e.winner_player_id,
    'winner_name', e.winner_name,
    'winner_source', e.winner_source,
    'rounds', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', r.id,
          'round_no', r.round_no,
          'title', r.title,
          'played_on', r.played_on,
          'course', r.course,
          'holes', r.holes,
          'round_type', r.round_type,
          'primary_metric', r.primary_metric,
          'notes', r.notes,
          'results_complete', r.results_complete,
          'winner', case
            when w.winner_name is null then null
            else jsonb_build_object(
              'player_id', w.winner_player_id,
              'name', w.winner_name,
              'result_value', w.winner_result,
              'to_par', w.winner_to_par,
              'basis', w.winner_basis
            )
          end,
          'results', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'id', x.id,
                'player_id', x.player_id,
                'participant_name', x.participant_name,
                'displayed_hcp', x.displayed_hcp,
                'segment', x.segment,
                'metric', x.metric,
                'result_value', x.result_value,
                'to_par', x.to_par,
                'displayed_position', x.displayed_position,
                'source', x.source,
                'source_ref', x.source_ref
              ) order by
                case when x.metric = r.primary_metric then 0 else 1 end,
                x.metric,
                x.segment,
                x.displayed_position nulls last,
                lower(x.participant_name)
            )
            from public.cbo_tour_results x
            where x.round_id = r.id
          ), '[]'::jsonb),
          'side_contests', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'id', s.id,
                'contest_type', s.contest_type,
                'hole', s.hole,
                'participant_name', s.participant_name,
                'player_id', s.player_id,
                'placement', s.placement,
                'value', s.value,
                'unit', s.unit,
                'note', s.note,
                'source', s.source
              ) order by s.contest_type, s.hole nulls last, s.placement nulls last, lower(s.participant_name)
            )
            from public.cbo_tour_side_contests s
            where s.round_id = r.id
          ), '[]'::jsonb)
        ) order by r.round_no
      )
      from public.cbo_tour_rounds r
      left join lateral (
        select rw.winner_player_id,
               rw.winner_name,
               rw.winner_result,
               rw.winner_to_par,
               rw.winner_basis
        from public.cbo_tour_round_winners(e.id) rw
        where rw.round_id = r.id
        limit 1
      ) w on true
      where r.event_id = e.id
    ), '[]'::jsonb)
  )
  into v_event
  from public.cbo_tour_events e
  where e.id = p_event_id;

  if v_event is null then
    return jsonb_build_object('ok', false, 'error', 'On Tour-eventet finns inte.');
  end if;

  return jsonb_build_object('ok', true, 'event', v_event);
end;
$$;

revoke all on function public.cbo_tour_event_detail(uuid) from public;
revoke all on function public.cbo_tour_event_detail(uuid) from anon;
grant execute on function public.cbo_tour_event_detail(uuid) to authenticated;

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION
-- pg_proc first, per CBO project rule.
-- ---------------------------------------------------------------------------
select p.proname, pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('cbo_tour_events_feed','cbo_tour_event_detail','cbo_tour_round_winners')
order by p.proname;

-- Expected signatures:
-- cbo_tour_event_detail   | p_event_id uuid
-- cbo_tour_events_feed    | 
-- cbo_tour_round_winners  | p_event_id uuid
