-- CBO 3.6.5
-- 06_current_hcp_index.sql
-- Startvärden för aktuellt HCP-index från Golf-ID-bilderna.
-- Tie-break i Totalen använder:
-- 1) senaste kända playing_hcp från GameBook/CBO
-- 2) annars current_hcp_index
-- 3) namn som sista tekniska sortering

begin;

alter table public.players
  add column if not exists current_hcp_index numeric;

update public.players
set current_hcp_index = v.hcp
from (
  values
    ('Anders Norrman',      13.3::numeric),
    ('Ernie Lagerstrand',   17.8::numeric),
    ('Henrik Lundin',       12.9::numeric),
    ('Håkan Harrysson',     15.3::numeric),
    ('Johan Fagerholm',     16.6::numeric),
    ('Johan Mattsson',      25.3::numeric),
    ('Johan Svanå',         26.2::numeric),
    ('Magnus Blennerud',    17.3::numeric),
    ('Magnus Jerkfelt',     27.0::numeric),
    ('Martin Burefors',     23.5::numeric),
    ('Peter Timar',         11.0::numeric),
    ('Tobias Henriksson',   26.3::numeric),
    ('Tomas Frydebo',       16.7::numeric),
    ('Urban Zakrison',      18.1::numeric)
) as v(name, hcp)
where public.players.name = v.name;

commit;

-- Kontroll: ska ge 14 rader.
select name, current_hcp_index
from public.players
where name in (
  'Anders Norrman','Ernie Lagerstrand','Henrik Lundin','Håkan Harrysson',
  'Johan Fagerholm','Johan Mattsson','Johan Svanå','Magnus Blennerud',
  'Magnus Jerkfelt','Martin Burefors','Peter Timar','Tobias Henriksson',
  'Tomas Frydebo','Urban Zakrison'
)
order by name;
