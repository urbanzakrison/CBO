-- Review-only release SQL. Do not run in production without approval.
-- Requires the already-applied cbo_allow_prepared_season_status migration.
begin;
set local lock_timeout = '5s';
create unique index cbo_one_active_season on public.seasons ((status)) where status = 'PÅGÅENDE';

create table public.cbo_season_snapshots (
 season_id uuid primary key references public.seasons(id),
 payload jsonb not null,
 captured_at timestamptz not null default now()
);
alter table public.cbo_season_snapshots enable row level security;
revoke all on public.cbo_season_snapshots from public, anon, authenticated;

create function public.cbo_seasons_status() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.is_cbo_member() then raise exception 'Aktivt CBO-medlemskap krävs.' using errcode='42501'; end if;
 return jsonb_build_object('ok',true,'active_year',(select year from public.seasons where status='PÅGÅENDE'),
 'seasons',(select coalesce(jsonb_agg(jsonb_build_object('year',s.year,'status',s.status,
 'champion_name',p.name,'champion_points',s.official_champion_points,'champion_note',s.champion_note,
 'can_activate',s.status='FÖRBEREDD' and s.year=(select min(year) from public.seasons where status='FÖRBEREDD')
 and s.year=1+(select year from public.seasons where status='PÅGÅENDE')) order by s.year desc),'[]'::jsonb)
 from public.seasons s left join public.players p on p.id=s.official_champion_player_id));
end $$;

create function public.cbo_season_create(p_year integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_next integer;
begin
 if auth.uid() is null or not exists(select 1 from public.cbo_current_player() where is_admin) then raise exception 'Adminbehörighet krävs.' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(20261019,1);
 if p_year is null or p_year<2000 or p_year>9999 then raise exception 'Ogiltigt säsongsår.'; end if;
 if exists(select 1 from public.seasons where year=p_year) then raise exception 'Säsongen finns redan.'; end if;
 select max(year)+1 into v_next from public.seasons;
 if p_year is distinct from v_next then raise exception 'Nästa säsongsår måste vara %.',v_next; end if;
 insert into public.seasons(year,status) values(p_year,'FÖRBEREDD') returning id into v_id;
 insert into public.season_players(season_id,player_id,start_hcp)
 select v_id,id,current_hcp_index from public.players where coalesce(active,true) and not coalesce(is_test,false);
 return jsonb_build_object('ok',true,'year',p_year,'status','FÖRBEREDD');
end $$;

create function public.cbo_season_data(p_year integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_data jsonb; v_season public.seasons;
begin
 if auth.uid() is null or not public.is_cbo_member() then raise exception 'Aktivt CBO-medlemskap krävs.' using errcode='42501'; end if;
 select * into v_season from public.seasons where year=p_year;
 if not found then raise exception 'Säsongen saknas.'; end if;
 select payload into v_data from public.cbo_season_snapshots where season_id=v_season.id;
 if found then return v_data; end if;
 if v_season.status='FÖRBEREDD' then
   return jsonb_build_object('ok',true,'year',p_year,'players','[]'::jsonb,'rounds','[]'::jsonb,'results','[]'::jsonb);
 end if;
 v_data:=public.cbo_live_leaderboard_data(p_year);
 if p_year>2026 then
   v_data:=jsonb_set(v_data,'{players}',(select coalesce(jsonb_agg(x || jsonb_build_object('start_hcp',sp.start_hcp)),'[]'::jsonb)
   from jsonb_array_elements(v_data->'players') x
   join public.players p on p.id=(x->>'id')::uuid
   left join public.season_players sp on sp.season_id=v_season.id and sp.player_id=p.id
   where not coalesce(p.is_test,false)));
 end if;
 return v_data;
end $$;

create function public.cbo_season_activate(p_year integer,p_expected_active_year integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_old public.seasons; v_new public.seasons; v_data jsonb; v_winner uuid; v_points numeric;
begin
 if auth.uid() is null or not exists(select 1 from public.cbo_current_player() where is_admin) then raise exception 'Adminbehörighet krävs.' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(20261019,1);
 select * into v_old from public.seasons where status='PÅGÅENDE' for update;
 if not found or v_old.year is distinct from p_expected_active_year then raise exception 'Aktiv säsong har ändrats. Läs om sidan.'; end if;
 select * into v_new from public.seasons where year=p_year for update;
 if not found or v_new.status<>'FÖRBEREDD' then raise exception 'Säsongen måste vara FÖRBEREDD.'; end if;
 if p_year<>v_old.year+1 then raise exception 'Endast nästa säsong kan aktiveras.'; end if;
 if exists(select 1 from public.rounds where season_id=v_new.id) then raise exception 'Förberedd säsong innehåller redan omgångar. Granskning krävs.'; end if;
 v_data:=public.cbo_season_data(v_old.year);
 if coalesce((v_data->>'ok')::boolean,false) is not true then raise exception 'Slutställningen kunde inte verifieras.'; end if;
 -- Freeze exactly the current live tie-break (points, current HCP, name).
 select (p->>'id')::uuid,sum((r->>'points')::numeric) into v_winner,v_points
 from jsonb_array_elements(v_data->'players') p
 join jsonb_array_elements(v_data->'results') r on r->>'player_id'=p->>'id'
 group by p order by sum((r->>'points')::numeric) desc,
 (p->>'current_hcp')::numeric asc nulls last,p->>'name' collate "C" limit 1;
 if exists(select 1 from public.rounds where season_id=v_old.id and official) and v_winner is null then raise exception 'Säsongens champion kunde inte fastställas.'; end if;
 insert into public.cbo_season_snapshots(season_id,payload) values(v_old.id,v_data);
 update public.seasons set status='AVSLUTAD',
 official_champion_player_id=coalesce(official_champion_player_id,v_winner),
 official_champion_points=coalesce(official_champion_points,v_points),
 champion_metric=coalesce(champion_metric,'Tävlingspoäng'),champion_value=coalesce(champion_value,v_points)
 where id=v_old.id;
 insert into public.season_players(season_id,player_id,start_hcp)
 select v_new.id,id,current_hcp_index from public.players where coalesce(active,true) and not coalesce(is_test,false)
 on conflict(season_id,player_id) do nothing;
 update public.seasons set status='PÅGÅENDE' where id=v_new.id;
 return jsonb_build_object('ok',true,'active_year',p_year,'closed_year',v_old.year);
end $$;

revoke all on function public.cbo_seasons_status() from public,anon;
revoke all on function public.cbo_season_create(integer) from public,anon;
revoke all on function public.cbo_season_data(integer) from public,anon;
revoke all on function public.cbo_season_activate(integer,integer) from public,anon;
grant execute on function public.cbo_seasons_status(),public.cbo_season_create(integer),public.cbo_season_data(integer),public.cbo_season_activate(integer,integer) to authenticated;

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

  -- Serialize with season activation and concurrent ordinary publication.
  perform pg_catalog.pg_advisory_xact_lock(20261019,1);
  -- Current season.
  select s.id
    into v_season_id
  from public.seasons s
  where s.status = 'PÅGÅENDE'
  limit 1;

  if v_season_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ingen pågående CBO-säsong hittades.');
  end if;

  if exists (
    select 1 from public.rounds r
    where r.season_id = v_season_id
      and r.round_no = p_round_no
  ) then
    return jsonb_build_object('ok', false, 'error', 'Omgångsnumret finns redan.');
  end if;

  if extract(year from p_played_on)::integer <> (select year from public.seasons where id=v_season_id) then
    return jsonb_build_object('ok',false,'error','Datumet tillhör inte den aktiva säsongen. Läs om säsongen och kontrollera importen.');
  end if;
  if exists(select 1 from public.rounds where season_id=v_season_id and played_on=p_played_on) then
    return jsonb_build_object('ok',false,'error','Datumet finns redan.');
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
      and (not coalesce(p.is_test,false) or (select year from public.seasons where id=v_season_id)<=2026)
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

commit;
