-- Isolated PostgreSQL fixture matching the inspected ordinary-CBO schema.
create role anon; create role authenticated;
create schema auth; create schema extensions;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table public.players(id uuid primary key default gen_random_uuid(),name text not null,active boolean not null default true,is_admin boolean not null default false,is_test boolean not null default false,current_hcp_index numeric);
create table public.player_credentials(player_id uuid references players(id),auth_user_id uuid references auth.users(id));
create table public.seasons(id uuid primary key default gen_random_uuid(),year integer not null unique,status text not null check(status in ('PÅGÅENDE','AVSLUTAD','FÖRBEREDD')),official_champion_player_id uuid references players(id),official_champion_points numeric,created_at timestamptz not null default now(),champion_metric text,champion_value numeric,champion_note text);
create table public.season_players(season_id uuid references seasons(id) on delete cascade,player_id uuid references players(id) on delete cascade,start_hcp numeric,primary key(season_id,player_id));
create table public.rounds(id uuid primary key default gen_random_uuid(),season_id uuid not null references seasons(id) on delete cascade,round_no integer not null,played_on date,course text,par9 integer not null default 36,official boolean not null default true,recap text,created_by uuid references auth.users(id),created_at timestamptz not null default now(),unique(season_id,round_no));
create table public.round_results(round_id uuid not null references rounds(id) on delete cascade,player_id uuid not null references players(id) on delete cascade,playing_hcp numeric,net integer,gross integer,placement integer,points numeric,primary key(round_id,player_id));
create function public.cbo_current_player() returns table(player_id uuid,name text,is_admin boolean) language sql stable security definer set search_path='' as $$select p.id,p.name,p.is_admin from public.players p join public.player_credentials pc on pc.player_id=p.id where pc.auth_user_id=auth.uid() and p.active limit 1$$;
create function public.is_cbo_member() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.cbo_current_player())$$;
grant usage on schema public,auth to authenticated;
grant execute on function public.cbo_current_player(),public.is_cbo_member() to authenticated;
