-- CBO On Tour – SCR metrics v1
-- Extends ONLY cbo_tour_* metric handling to support historical GameBook
-- gross/scratch result tabs (SCR) as well as NET.
-- Ordinary CBO 9-hole scoring/import remains untouched.

begin;

-- ---------------------------------------------------------------------------
-- 1. RESULT METRIC CONSTRAINT
-- Existing values remain valid; two SCR values are added.
-- ---------------------------------------------------------------------------
alter table public.cbo_tour_results
  drop constraint if exists cbo_tour_results_metric_check;

alter table public.cbo_tour_results
  add constraint cbo_tour_results_metric_check
  check (metric in (
    'stroke_net',
    'stableford_net',
    'stroke_scr',
    'stableford_scr'
  ));

-- ---------------------------------------------------------------------------
-- 2. PRIMARY METRIC CONSTRAINT
-- ---------------------------------------------------------------------------
alter table public.cbo_tour_rounds
  drop constraint if exists cbo_tour_rounds_primary_metric_chk;

alter table public.cbo_tour_rounds
  add constraint cbo_tour_rounds_primary_metric_chk
  check (primary_metric is null or primary_metric in (
    'stroke_net',
    'stableford_net',
    'stroke_scr',
    'stableford_scr'
  ));

comment on column public.cbo_tour_rounds.primary_metric is
  'Primary competition metric. For GameBook imports this is the result tab displayed furthest left and determines the round winner. Supported: stroke_net, stableford_net, stroke_scr, stableford_scr.';

-- ---------------------------------------------------------------------------
-- 3. ADMIN PUBLISH RPC v3
-- Same exact signature as v2: CREATE OR REPLACE, therefore no overload.
-- Only accepted metric values are expanded.
-- ---------------------------------------------------------------------------
create or replace function public.cbo_tour_publish_round(
  p_event_id uuid,
  p_round_no integer,
  p_title text,
  p_played_on date,
  p_course text,
  p_holes integer,
  p_round_type text,
  p_notes text,
  p_primary_metric text,
  p_results jsonb,
  p_results_complete boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_admin boolean;
  v_round_id uuid;
  v_item jsonb;
  v_player_id uuid;
  v_name text;
  v_segment text;
  v_metric text;
  v_source text;
  v_primary_metric text;
  v_result_count integer;
begin
  select exists (
    select 1
    from public.player_credentials pc
    join public.players p on p.id = pc.player_id
    where pc.auth_user_id = auth.uid()
      and coalesce(p.active, true) = true
      and coalesce(p.is_admin, false) = true
  ) into v_admin;

  if not v_admin then
    return jsonb_build_object('ok', false, 'error', 'Adminbehörighet krävs.');
  end if;

  if p_event_id is null or not exists (
    select 1 from public.cbo_tour_events e where e.id = p_event_id
  ) then
    return jsonb_build_object('ok', false, 'error', 'On Tour-eventet finns inte.');
  end if;

  if p_round_no is null or p_round_no < 1 then
    return jsonb_build_object('ok', false, 'error', 'Ogiltigt rondnummer.');
  end if;

  if p_holes not in (9,18) then
    return jsonb_build_object('ok', false, 'error', 'Antal hål måste vara 9 eller 18.');
  end if;

  if coalesce(trim(p_round_type), '') not in ('individual','scramble','team','other') then
    return jsonb_build_object('ok', false, 'error', 'Ogiltig rondtyp.');
  end if;

  if p_results is null or jsonb_typeof(p_results) <> 'array' then
    return jsonb_build_object('ok', false, 'error', 'Resultat måste vara en lista.');
  end if;

  v_primary_metric := nullif(trim(coalesce(p_primary_metric, '')), '');

  if v_primary_metric is not null
     and v_primary_metric not in ('stroke_net','stableford_net','stroke_scr','stableford_scr') then
    return jsonb_build_object('ok', false, 'error', 'Ogiltig primär resultattyp.');
  end if;

  if p_round_type <> 'individual' and v_primary_metric is not null then
    return jsonb_build_object('ok', false, 'error', 'Primär resultattyp gäller endast individuell rond.');
  end if;

  v_result_count := jsonb_array_length(p_results);

  if coalesce(p_results_complete, false)
     and p_round_type = 'individual'
     and v_result_count < 1 then
    return jsonb_build_object('ok', false, 'error', 'En komplett individuell rond måste ha minst ett resultat.');
  end if;

  if coalesce(p_results_complete, false)
     and p_round_type = 'individual'
     and v_result_count > 0
     and v_primary_metric is null then
    return jsonb_build_object('ok', false, 'error', 'Primär resultattyp måste anges för en komplett individuell rond.');
  end if;

  if v_primary_metric is not null
     and not exists (
       select 1
       from jsonb_array_elements(p_results) x
       where trim(x->>'metric') = v_primary_metric
     ) then
    return jsonb_build_object('ok', false, 'error', 'Primär resultattyp saknas bland rondens resultat.');
  end if;

  if exists (
    select 1 from public.cbo_tour_rounds r
    where r.event_id = p_event_id
      and r.round_no = p_round_no
  ) then
    return jsonb_build_object('ok', false, 'error', 'Ronden finns redan för detta On Tour-event.');
  end if;

  if exists (
    select 1
    from (
      select
        lower(trim(x->>'participant_name')) as participant_name,
        coalesce(nullif(trim(x->>'segment'), ''), 'full') as segment,
        trim(x->>'metric') as metric,
        count(*) as c
      from jsonb_array_elements(p_results) x
      group by 1,2,3
      having count(*) > 1
    ) d
  ) then
    return jsonb_build_object('ok', false, 'error', 'Samma spelare/segment/resultattyp finns mer än en gång.');
  end if;

  insert into public.cbo_tour_rounds
    (event_id, round_no, title, played_on, course, holes, round_type, notes,
     primary_metric, results_complete, created_by)
  values
    (p_event_id, p_round_no,
     nullif(trim(coalesce(p_title, '')), ''),
     p_played_on,
     nullif(trim(coalesce(p_course, '')), ''),
     p_holes,
     trim(p_round_type),
     nullif(trim(coalesce(p_notes, '')), ''),
     v_primary_metric,
     coalesce(p_results_complete, false),
     auth.uid())
  returning id into v_round_id;

  for v_item in
    select x from jsonb_array_elements(p_results) x
  loop
    v_name := trim(v_item->>'participant_name');
    v_segment := coalesce(nullif(trim(v_item->>'segment'), ''), 'full');
    v_metric := trim(v_item->>'metric');
    v_source := coalesce(nullif(trim(v_item->>'source'), ''), 'gamebook');

    if coalesce(v_name, '') = '' then
      raise exception 'Deltagarnamn saknas i ett resultat.';
    end if;

    if v_segment not in ('full','first9','last9') then
      raise exception 'Ogiltigt segment för %: %', v_name, v_segment;
    end if;

    if v_metric not in ('stroke_net','stableford_net','stroke_scr','stableford_scr') then
      raise exception 'Ogiltig resultattyp för %: %', v_name, v_metric;
    end if;

    if v_item->>'result_value' is null then
      raise exception 'Resultatvärde saknas för %.', v_name;
    end if;

    if v_source not in ('gamebook','manual','historical_import') then
      raise exception 'Ogiltig källa för %: %', v_name, v_source;
    end if;

    v_player_id := null;
    select p.id into v_player_id
    from public.players p
    where lower(trim(p.name)) = lower(v_name)
    limit 1;

    insert into public.cbo_tour_results
      (round_id, player_id, participant_name, displayed_hcp, segment, metric,
       result_value, to_par, displayed_position, source, source_ref, created_by)
    values
      (v_round_id,
       v_player_id,
       v_name,
       case when v_item->>'displayed_hcp' is null then null else (v_item->>'displayed_hcp')::numeric end,
       v_segment,
       v_metric,
       (v_item->>'result_value')::integer,
       case when v_item->>'to_par' is null then null else (v_item->>'to_par')::integer end,
       case when v_item->>'displayed_position' is null then null else (v_item->>'displayed_position')::integer end,
       v_source,
       nullif(trim(coalesce(v_item->>'source_ref', '')), ''),
       auth.uid());
  end loop;

  return jsonb_build_object(
    'ok', true,
    'round_id', v_round_id,
    'round_no', p_round_no,
    'primary_metric', v_primary_metric,
    'result_count', v_result_count,
    'results_complete', coalesce(p_results_complete, false)
  );

exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'error', 'Dubblett upptäcktes. Ingen On Tour-rond publicerades.');
  when others then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;

revoke all on function public.cbo_tour_publish_round(
  uuid,integer,text,date,text,integer,text,text,text,jsonb,boolean
) from public;
revoke all on function public.cbo_tour_publish_round(
  uuid,integer,text,date,text,integer,text,text,text,jsonb,boolean
) from anon;
grant execute on function public.cbo_tour_publish_round(
  uuid,integer,text,date,text,integer,text,text,text,jsonb,boolean
) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. ROUND WINNER RPC v2
-- Stableford (NET or SCR): highest result wins.
-- Stroke play (NET or SCR): lowest result wins.
-- Full GameBook displayed_position=1 remains preferred when available.
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
          case when st.primary_metric in ('stroke_net','stroke_scr') then st.result_value end asc nulls last,
          case when st.primary_metric in ('stableford_net','stableford_scr') then st.result_value end desc nulls last
      ) as winner_rank,
      count(*) over (
        partition by st.round_id,
          case when st.primary_metric in ('stroke_net','stroke_scr') then st.result_value end,
          case when st.primary_metric in ('stableford_net','stableford_scr') then st.result_value end
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

-- ---------------------------------------------------------------------------
-- VERIFICATION
-- ---------------------------------------------------------------------------
-- A. Both CHECK constraints must contain all four supported values.
select
  c.conname,
  pg_get_constraintdef(c.oid) as definition
from pg_constraint c
join pg_class t on t.oid = c.conrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname in ('cbo_tour_results','cbo_tour_rounds')
  and c.conname in ('cbo_tour_results_metric_check','cbo_tour_rounds_primary_metric_chk')
order by t.relname, c.conname;

-- B. There must still be exactly ONE publish overload and ONE winners overload.
select
  p.proname,
  pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('cbo_tour_publish_round','cbo_tour_round_winners')
order by p.proname, args;
