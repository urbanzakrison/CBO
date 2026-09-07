-- CBO 3.7
-- 07_live_round_write_rpc.sql
-- Admin-only server function for publishing a CBO round.
-- The server, not the browser, decides official status, placement and CBO points.

create or replace function public.cbo_publish_round(
  p_round_no integer,
  p_played_on date,
  p_course text,
  p_par9 integer,
  p_recap text,
  p_results jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_admin boolean;
  v_season_id uuid;
  v_round_id uuid;
  v_count integer;
  v_official boolean;
  v_item jsonb;
  v_player_id uuid;
  v_name text;
  v_shcp numeric;
  v_net integer;
  v_gross integer;
  v_rank integer := 0;
  v_points integer;
begin
  -- Must be an authenticated active CBO admin.
  select exists (
    select 1
    from public.player_credentials pc
    join public.players p on p.id = pc.player_id
    where pc.auth_user_id = auth.uid()
      and coalesce(p.active, true) = true
      and coalesce(p.is_admin, false) = true
  )
  into v_admin;

  if not v_admin then
    return jsonb_build_object('ok', false, 'error', 'Adminbehörighet krävs.');
  end if;

  if p_round_no is null or p_round_no < 1 then
    return jsonb_build_object('ok', false, 'error', 'Ogiltigt omgångsnummer.');
  end if;

  if p_played_on is null then
    return jsonb_build_object('ok', false, 'error', 'Datum saknas.');
  end if;

  if coalesce(trim(p_course),'') = '' then
    return jsonb_build_object('ok', false, 'error', 'Bana saknas.');
  end if;

  if p_par9 is null or p_par9 < 20 or p_par9 > 50 then
    return jsonb_build_object('ok', false, 'error', 'Ogiltigt par för 9 hål.');
  end if;

  if jsonb_typeof(p_results) <> 'array' then
    return jsonb_build_object('ok', false, 'error', 'Resultat måste vara en lista.');
  end if;

  v_count := jsonb_array_length(p_results);
  if v_count < 1 then
    return jsonb_build_object('ok', false, 'error', 'Minst en deltagare krävs.');
  end if;

  -- Current season.
  select s.id
    into v_season_id
  from public.seasons s
  where coalesce(to_jsonb(s)->>'year', to_jsonb(s)->>'season_year', to_jsonb(s)->>'name') = '2026'
  limit 1;

  if v_season_id is null then
    return jsonb_build_object('ok', false, 'error', 'Säsong 2026 saknas.');
  end if;

  if exists (
    select 1 from public.rounds r
    where r.season_id = v_season_id
      and r.round_no = p_round_no
  ) then
    return jsonb_build_object('ok', false, 'error', 'Omgångsnumret finns redan.');
  end if;

  -- Reject duplicated player names in the submitted round.
  if (
    select count(*) from (
      select lower(trim(x->>'name')) as n
      from jsonb_array_elements(p_results) x
      group by lower(trim(x->>'name'))
      having count(*) > 1
    ) d
  ) > 0 then
    return jsonb_build_object('ok', false, 'error', 'Samma spelare finns mer än en gång.');
  end if;

  v_official := v_count >= 4;
  v_round_id := gen_random_uuid();

  insert into public.rounds
    (id, season_id, round_no, played_on, course, par9, official, recap, created_by)
  values
    (v_round_id, v_season_id, p_round_no, p_played_on, trim(p_course), p_par9,
     v_official, nullif(trim(coalesce(p_recap,'')),''), auth.uid());

  -- Sort on net ascending, then SHCP ascending, then name.
  -- Points: official round only. 4,3,2,1...
  for v_item in
    select x
    from jsonb_array_elements(p_results) x
    order by
      (x->>'net')::integer asc,
      (x->>'shcp')::numeric asc,
      lower(x->>'name') asc
  loop
    v_rank := v_rank + 1;
    v_name := trim(v_item->>'name');
    v_shcp := (v_item->>'shcp')::numeric;
    v_net := (v_item->>'net')::integer;
    v_gross := (v_item->>'gross')::integer;

    select p.id into v_player_id
    from public.players p
    where lower(p.name) = lower(v_name)
      and coalesce(p.active, true) = true
    limit 1;

    if v_player_id is null then
      raise exception 'Okänd/ej aktiv CBO-spelare: %', v_name;
    end if;

    if v_official then
      v_points := case v_rank
        when 1 then 4
        when 2 then 3
        when 3 then 2
        else 1
      end;
    else
      v_points := 0;
    end if;

    insert into public.round_results
      (round_id, player_id, net, gross, points, playing_hcp)
    values
      (v_round_id, v_player_id, v_net, v_gross, v_points, v_shcp);
  end loop;

  return jsonb_build_object(
    'ok', true,
    'round_id', v_round_id,
    'round_no', p_round_no,
    'official', v_official,
    'result_count', v_count
  );

exception
  when others then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;

revoke all on function public.cbo_publish_round(integer,date,text,integer,text,jsonb) from public;
revoke all on function public.cbo_publish_round(integer,date,text,integer,text,jsonb) from anon;
grant execute on function public.cbo_publish_round(integer,date,text,integer,text,jsonb) to authenticated;

select routine_name
from information_schema.routines
where routine_schema='public'
  and routine_name='cbo_publish_round';
