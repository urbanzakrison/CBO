CREATE OR REPLACE FUNCTION public.cbo_publish_round(p_round_no integer, p_played_on date, p_course text, p_par9 integer, p_recap text, p_results jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.cbo_live_leaderboard_data(p_year integer DEFAULT 2026)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_season jsonb;
  v_sid text;
  v_players jsonb;
  v_rounds jsonb;
  v_results jsonb;
  v_round_ids text[];
  v_is_member boolean;
begin
  -- Only an authenticated, active CBO player may use this RPC.
  select exists (
    select 1
    from public.player_credentials pc
    join public.players p on p.id = pc.player_id
    where pc.auth_user_id = auth.uid()
      and coalesce(p.active, true) = true
  ) into v_is_member;

  if not v_is_member then
    return jsonb_build_object('ok', false, 'error', 'Ingen aktiv CBO-behörighet.');
  end if;

  -- Find requested season without depending on one exact imported column name.
  select to_jsonb(s)
    into v_season
  from public.seasons s
  where coalesce(
          to_jsonb(s)->>'year',
          to_jsonb(s)->>'season_year',
          to_jsonb(s)->>'name'
        ) = p_year::text
  limit 1;

  if v_season is null then
    return jsonb_build_object('ok', false, 'error', 'Säsongen hittades inte.');
  end if;

  v_sid := coalesce(v_season->>'id', v_season->>'season_id');

  -- Safe player projection only.
  -- current_playing_hcp = latest known playing handicap from CBO round results.
  with active_players as (
    select p.id, p.name, p.current_hcp_index
    from public.players p
    where coalesce(p.active, true) = true
  ),
  latest_hcp as (
    select distinct on (rr.player_id)
      rr.player_id,
      rr.playing_hcp
    from public.round_results rr
    join public.rounds r on r.id = rr.round_id
    where rr.playing_hcp is not null
    order by rr.player_id,
             r.played_on desc nulls last,
             r.round_no desc nulls last,
             r.id desc
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'name', p.name,
      'current_hcp', coalesce(lh.playing_hcp, p.current_hcp_index),
      'hcp_source', case
        when lh.playing_hcp is not null then 'latest_playing_hcp'
        when p.current_hcp_index is not null then 'current_hcp_index'
        else 'missing'
      end
    )
    order by p.name
  ), '[]'::jsonb)
  into v_players
  from active_players p
  left join latest_hcp lh on lh.player_id = p.id;

  -- Sanitized round projection for the requested season.
  with r as (
    select to_jsonb(x) j
    from public.rounds x
  ), chosen as (
    select j
    from r
    where coalesce(j->>'season_id', j->>'season') = v_sid
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id', coalesce(j->>'id', j->>'round_id'),
      'round_number', coalesce(j->>'round_no', j->>'round_number', j->>'round', j->>'number'),
      'played_on', j->>'played_on',
      'course', j->>'course',
      'par9', j->>'par9',
      'official', j->>'official',
      'recap', j->>'recap'
    )), '[]'::jsonb),
    coalesce(array_agg(coalesce(j->>'id', j->>'round_id')), array[]::text[])
  into v_rounds, v_round_ids
  from chosen;

  -- Sanitized result projection only.
  select coalesce(jsonb_agg(jsonb_build_object(
    'round_id', coalesce(j->>'round_id', j->>'round'),
    'player_id', coalesce(j->>'player_id', j->>'player'),
    'net', coalesce(j->>'net', j->>'net_score', j->>'netto'),
    'gross', coalesce(j->>'gross', j->>'gross_score', j->>'brutto'),
    'points', coalesce(j->>'points', j->>'competition_points', j->>'pts'),
    'playing_hcp', coalesce(j->>'playing_hcp', j->>'shcp')
  )), '[]'::jsonb)
  into v_results
  from (
    select to_jsonb(rr) j
    from public.round_results rr
  ) q
  where coalesce(j->>'round_id', j->>'round') = any(v_round_ids);

  return jsonb_build_object(
    'ok', true,
    'year', p_year,
    'round_count', jsonb_array_length(v_rounds),
    'result_count', jsonb_array_length(v_results),
    'players', v_players,
    'rounds', v_rounds,
    'results', v_results
  );
exception
  when others then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$function$;

CREATE OR REPLACE FUNCTION public.cbo_round_duplicate_check(p_round_no integer, p_played_on date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_season_id uuid;
  v_round_no_exists boolean := false;
  v_date_exists boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'Ogiltig Supabase-session.');
  end if;

  if not exists (
    select 1
    from public.cbo_current_player()
    where is_admin = true
  ) then
    return jsonb_build_object('ok', false, 'error', 'Adminbehörighet krävs.');
  end if;

  select id
    into v_season_id
  from public.seasons
  where status = 'PÅGÅENDE'
  limit 1;

  if v_season_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ingen pågående CBO-säsong hittades.');
  end if;

  select exists(
    select 1 from public.rounds
    where season_id = v_season_id
      and round_no = p_round_no
  ) into v_round_no_exists;

  select exists(
    select 1 from public.rounds
    where season_id = v_season_id
      and played_on = p_played_on
  ) into v_date_exists;

  return jsonb_build_object(
    'ok', true,
    'duplicate', (v_round_no_exists or v_date_exists),
    'round_no_exists', v_round_no_exists,
    'date_exists', v_date_exists
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.cbo_season_stats(p_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_allowed boolean;
  v_season_id uuid;
  v_rounds integer; v_starts integer; v_unique integer;
  v_total_net bigint; v_total_gross bigint;
  v_best_net jsonb; v_worst_net jsonb; v_best_gross jsonb; v_worst_gross jsonb;
  v_attendance jsonb; v_wins jsonb; v_top3 jsonb;
begin
  select exists(
    select 1 from public.player_credentials pc
    where pc.auth_user_id=auth.uid()
  ) into v_allowed;
  if not v_allowed then raise exception 'Du måste vara inloggad i CBO'; end if;

  if exists(select 1 from information_schema.columns where table_schema='public' and table_name='seasons' and column_name='year') then
    execute 'select id from public.seasons where year=$1 limit 1' into v_season_id using p_year;
  elsif exists(select 1 from information_schema.columns where table_schema='public' and table_name='seasons' and column_name='season_year') then
    execute 'select id from public.seasons where season_year=$1 limit 1' into v_season_id using p_year;
  elsif exists(select 1 from information_schema.columns where table_schema='public' and table_name='seasons' and column_name='name') then
    execute 'select id from public.seasons where name=$1::text limit 1' into v_season_id using p_year;
  else
    raise exception 'Kunde inte identifiera årskolumnen i public.seasons';
  end if;
  if v_season_id is null then raise exception 'Säsong % hittades inte',p_year; end if;

  select count(*)::int into v_rounds from public.rounds r
   where r.season_id=v_season_id and coalesce(r.official,false)=true;

  select count(*)::int,count(distinct rr.player_id)::int,
         coalesce(sum(rr.net),0)::bigint,coalesce(sum(rr.gross),0)::bigint
    into v_starts,v_unique,v_total_net,v_total_gross
  from public.round_results rr join public.rounds r on r.id=rr.round_id
  where r.season_id=v_season_id and coalesce(r.official,false)=true;

  select jsonb_build_object('name',p.name,'score',rr.net,'round',r.round_no,'date',r.played_on,'course',r.course)
  into v_best_net from public.round_results rr join public.rounds r on r.id=rr.round_id join public.players p on p.id=rr.player_id
  where r.season_id=v_season_id and coalesce(r.official,false)=true and rr.net is not null
  order by rr.net,r.played_on,p.name limit 1;

  select jsonb_build_object('name',p.name,'score',rr.net,'round',r.round_no,'date',r.played_on,'course',r.course)
  into v_worst_net from public.round_results rr join public.rounds r on r.id=rr.round_id join public.players p on p.id=rr.player_id
  where r.season_id=v_season_id and coalesce(r.official,false)=true and rr.net is not null
  order by rr.net desc,r.played_on,p.name limit 1;

  select jsonb_build_object('name',p.name,'score',rr.gross,'round',r.round_no,'date',r.played_on,'course',r.course)
  into v_best_gross from public.round_results rr join public.rounds r on r.id=rr.round_id join public.players p on p.id=rr.player_id
  where r.season_id=v_season_id and coalesce(r.official,false)=true and rr.gross is not null
  order by rr.gross,r.played_on,p.name limit 1;

  select jsonb_build_object('name',p.name,'score',rr.gross,'round',r.round_no,'date',r.played_on,'course',r.course)
  into v_worst_gross from public.round_results rr join public.rounds r on r.id=rr.round_id join public.players p on p.id=rr.player_id
  where r.season_id=v_season_id and coalesce(r.official,false)=true and rr.gross is not null
  order by rr.gross desc,r.played_on,p.name limit 1;

  with a as (
    select p.name,count(*)::int n from public.round_results rr
    join public.rounds r on r.id=rr.round_id join public.players p on p.id=rr.player_id
    where r.season_id=v_season_id and coalesce(r.official,false)=true group by p.id,p.name
  ), mx as (select max(n) n from a)
  select case when mx.n is null then '{}'::jsonb else jsonb_build_object(
    'count',mx.n,'players',(select jsonb_agg(a.name order by a.name) from a where a.n=mx.n)) end
  into v_attendance from mx;

  with a as (
    select p.name,count(*)::int n from public.round_results rr
    join public.rounds r on r.id=rr.round_id join public.players p on p.id=rr.player_id
    where r.season_id=v_season_id and coalesce(r.official,false)=true and rr.points=4 group by p.id,p.name
  ), mx as (select max(n) n from a)
  select case when mx.n is null then '{}'::jsonb else jsonb_build_object(
    'count',mx.n,'players',(select jsonb_agg(a.name order by a.name) from a where a.n=mx.n)) end
  into v_wins from mx;

  with a as (
    select p.name,count(*)::int n from public.round_results rr
    join public.rounds r on r.id=rr.round_id join public.players p on p.id=rr.player_id
    where r.season_id=v_season_id and coalesce(r.official,false)=true and rr.points>=2 group by p.id,p.name
  ), mx as (select max(n) n from a)
  select case when mx.n is null then '{}'::jsonb else jsonb_build_object(
    'count',mx.n,'players',(select jsonb_agg(a.name order by a.name) from a where a.n=mx.n)) end
  into v_top3 from mx;

  return jsonb_build_object(
    'year',p_year,'official_rounds',v_rounds,'starts',v_starts,'unique_players',v_unique,
    'total_net',v_total_net,'total_gross',v_total_gross,
    'avg_net',case when v_starts>0 then round(v_total_net::numeric/v_starts,2) end,
    'avg_gross',case when v_starts>0 then round(v_total_gross::numeric/v_starts,2) end,
    'attendance',coalesce(v_attendance,'{}'::jsonb),
    'best_net',v_best_net,'worst_net',v_worst_net,'best_gross',v_best_gross,'worst_gross',v_worst_gross,
    'wins',coalesce(v_wins,'{}'::jsonb),'top3',coalesce(v_top3,'{}'::jsonb)
  );
end;
$function$;
