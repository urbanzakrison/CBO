-- CBO 3.6
-- 04_live_leaderboard_rpc.sql
-- Sanitized server-side source for live leaderboard data.
-- No Golf-ID, phone, credential hash or other private fields are returned.

create or replace function public.cbo_live_leaderboard_data(p_year integer default 2026)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
$$;

revoke all on function public.cbo_live_leaderboard_data(integer) from public;
revoke all on function public.cbo_live_leaderboard_data(integer) from anon;
grant execute on function public.cbo_live_leaderboard_data(integer) to authenticated;

-- Kontroll som projektägare: funktionen ska finnas.
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'cbo_live_leaderboard_data';
