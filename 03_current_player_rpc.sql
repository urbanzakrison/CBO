-- CBO 3.3 – säker identitetskoppling för inloggad användare
-- Returnerar endast spelarens namn och adminstatus, aldrig Golf-ID eller koddata.

create or replace function public.cbo_current_player()
returns table (
  player_id uuid,
  name text,
  is_admin boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, p.name, coalesce(p.is_admin, false)
  from public.player_credentials pc
  join public.players p on p.id = pc.player_id
  where pc.auth_user_id = auth.uid()
    and coalesce(p.active, true) = true
  limit 1;
$$;

revoke all on function public.cbo_current_player() from public;
revoke all on function public.cbo_current_player() from anon;
grant execute on function public.cbo_current_player() to authenticated;

-- Kontroll som projektägare: ska visa att funktionen finns.
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'cbo_current_player';
