-- CBO On Tour – create event idempotent v1
-- Small isolated fix for historical import flow.
-- Existing On Tour events are reused instead of returning "event already exists".
-- Ordinary CBO tables and flows are untouched.

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

  select e.id into v_event_id
  from public.cbo_tour_events e
  where lower(trim(e.name)) = lower(trim(p_name))
    and e.event_year = p_event_year
  limit 1;

  if v_event_id is not null then
    return jsonb_build_object('ok', true, 'event_id', v_event_id, 'reused', true);
  end if;

  insert into public.cbo_tour_events
    (name, event_year, starts_on, ends_on, location, notes, results_complete, created_by)
  values
    (trim(p_name), p_event_year, p_starts_on, p_ends_on,
     nullif(trim(coalesce(p_location, '')), ''),
     nullif(trim(coalesce(p_notes, '')), ''),
     false, auth.uid())
  returning id into v_event_id;

  return jsonb_build_object('ok', true, 'event_id', v_event_id, 'reused', false);

exception
  when unique_violation then
    select e.id into v_event_id
    from public.cbo_tour_events e
    where lower(trim(e.name)) = lower(trim(p_name))
      and e.event_year = p_event_year
    limit 1;

    if v_event_id is not null then
      return jsonb_build_object('ok', true, 'event_id', v_event_id, 'reused', true);
    end if;

    return jsonb_build_object('ok', false, 'error', 'On Tour-eventet finns redan men kunde inte återanvändas.');
  when others then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;

revoke all on function public.cbo_tour_admin_create_event(text,integer,date,date,text,text) from public;
revoke all on function public.cbo_tour_admin_create_event(text,integer,date,date,text,text) from anon;
grant execute on function public.cbo_tour_admin_create_event(text,integer,date,date,text,text) to authenticated;
