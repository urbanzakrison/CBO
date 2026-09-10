-- CBO On Tour – admin RPCs v1
-- Isolated write layer for On Tour only.
-- Does not write to rounds, round_results, seasons or any ordinary CBO scoring tables.

begin;

-- ---------------------------------------------------------------------------
-- 1. CREATE EVENT (ADMIN ONLY)
-- ---------------------------------------------------------------------------
create or replace function public.cbo_tour_admin_create_event(
  p_name text,
  p_event_year integer,
  p_starts_on date default null,
  p_ends_on date default null,
  p_location text default null,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_admin boolean;
  v_event_id uuid;
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

  if coalesce(trim(p_name), '') = '' then
    return jsonb_build_object('ok', false, 'error', 'Eventnamn saknas.');
  end if;

  if p_event_year is null or p_event_year < 1900 or p_event_year > 2200 then
    return jsonb_build_object('ok', false, 'error', 'Ogiltigt eventår.');
  end if;

  if p_starts_on is not null and p_ends_on is not null and p_ends_on < p_starts_on then
    return jsonb_build_object('ok', false, 'error', 'Slutdatum kan inte vara före startdatum.');
  end if;

  if exists (
    select 1
    from public.cbo_tour_events e
    where lower(trim(e.name)) = lower(trim(p_name))
      and e.event_year = p_event_year
  ) then
    return jsonb_build_object('ok', false, 'error', 'On Tour-eventet finns redan.');
  end if;

  insert into public.cbo_tour_events
    (name, event_year, starts_on, ends_on, location, notes, results_complete, created_by)
  values
    (trim(p_name), p_event_year, p_starts_on, p_ends_on,
     nullif(trim(coalesce(p_location, '')), ''),
     nullif(trim(coalesce(p_notes, '')), ''),
     false, auth.uid())
  returning id into v_event_id;

  return jsonb_build_object('ok', true, 'event_id', v_event_id);

exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'error', 'On Tour-eventet finns redan.');
  when others then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;

revoke all on function public.cbo_tour_admin_create_event(text,integer,date,date,text,text) from public;
revoke all on function public.cbo_tour_admin_create_event(text,integer,date,date,text,text) from anon;
grant execute on function public.cbo_tour_admin_create_event(text,integer,date,date,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. DUPLICATE CHECK (ADMIN ONLY)
-- ---------------------------------------------------------------------------
create or replace function public.cbo_tour_round_duplicate_check(
  p_event_id uuid,
  p_round_no integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
stable
as $$
declare
  v_admin boolean;
  v_exists boolean;
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

  if p_event_id is null or p_round_no is null or p_round_no < 1 then
    return jsonb_build_object('ok', false, 'error', 'Event och giltigt rondnummer krävs.');
  end if;

  if not exists (select 1 from public.cbo_tour_events e where e.id = p_event_id) then
    return jsonb_build_object('ok', false, 'error', 'On Tour-eventet finns inte.');
  end if;

  select exists (
    select 1 from public.cbo_tour_rounds r
    where r.event_id = p_event_id
      and r.round_no = p_round_no
  ) into v_exists;

  return jsonb_build_object('ok', true, 'duplicate', v_exists);
end;
$$;

revoke all on function public.cbo_tour_round_duplicate_check(uuid,integer) from public;
revoke all on function public.cbo_tour_round_duplicate_check(uuid,integer) from anon;
grant execute on function public.cbo_tour_round_duplicate_check(uuid,integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. PUBLISH ROUND + RESULTS (ADMIN ONLY)
-- One database transaction because this function call is atomic.
-- Historical participants who are not CBO members are preserved by name with
-- player_id = null. Exact displayed GameBook values are stored as submitted.
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

  v_result_count := jsonb_array_length(p_results);

  if coalesce(p_results_complete, false)
     and p_round_type = 'individual'
     and v_result_count < 1 then
    return jsonb_build_object('ok', false, 'error', 'En komplett individuell rond måste ha minst ett resultat.');
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
     results_complete, created_by)
  values
    (p_event_id, p_round_no,
     nullif(trim(coalesce(p_title, '')), ''),
     p_played_on,
     nullif(trim(coalesce(p_course, '')), ''),
     p_holes,
     trim(p_round_type),
     nullif(trim(coalesce(p_notes, '')), ''),
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

revoke all on function public.cbo_tour_publish_round(uuid,integer,text,date,text,integer,text,text,jsonb,boolean) from public;
revoke all on function public.cbo_tour_publish_round(uuid,integer,text,date,text,integer,text,text,jsonb,boolean) from anon;
grant execute on function public.cbo_tour_publish_round(uuid,integer,text,date,text,integer,text,text,jsonb,boolean) to authenticated;

commit;

-- Verification in pg_proc:
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args
-- from pg_proc p
-- join pg_namespace n on n.oid=p.pronamespace
-- where n.nspname='public'
--   and p.proname in (
--     'cbo_tour_admin_create_event',
--     'cbo_tour_round_duplicate_check',
--     'cbo_tour_publish_round'
--   )
-- order by p.proname;
