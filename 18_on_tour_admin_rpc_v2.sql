-- CBO On Tour – admin publish RPC v2
-- Small isolated change: adds primary_metric to On Tour round publication.
-- Ordinary CBO publish flow and ordinary CBO tables are untouched.
--
-- IMPORTANT:
-- PostgreSQL identifies functions by name + argument types. The v1 signature is
-- explicitly dropped first so this migration does NOT leave an accidental overload.

begin;

-- Remove ONLY the exact v1 On Tour publish signature.
drop function if exists public.cbo_tour_publish_round(
  uuid, integer, text, date, text, integer, text, text, jsonb, boolean
);

create function public.cbo_tour_publish_round(
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
     and v_primary_metric not in ('stroke_net','stableford_net') then
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

  -- A completed individual round must have an explicit primary metric.
  -- GameBook rule: whichever competition form is furthest left on the source card.
  if coalesce(p_results_complete, false)
     and p_round_type = 'individual'
     and v_result_count > 0
     and v_primary_metric is null then
    return jsonb_build_object('ok', false, 'error', 'Primär resultattyp måste anges för en komplett individuell rond.');
  end if;

  -- If a primary metric is supplied, it must actually exist in the submitted rows.
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

  -- Reject duplicate participant/segment/metric combinations in the same payload.
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

    if v_metric not in ('stroke_net','stableford_net') then
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

commit;

-- Verification: there must be exactly ONE cbo_tour_publish_round overload.
-- Run after this migration:
--
-- select
--   p.proname,
--   pg_get_function_identity_arguments(p.oid) as args
-- from pg_proc p
-- join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and p.proname = 'cbo_tour_publish_round'
-- order by 2;
--
-- Expected single signature:
-- p_event_id uuid, p_round_no integer, p_title text, p_played_on date,
-- p_course text, p_holes integer, p_round_type text, p_notes text,
-- p_primary_metric text, p_results jsonb, p_results_complete boolean
