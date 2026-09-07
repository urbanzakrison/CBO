-- CBO 3.6.2
-- 05_latest_playing_hcp.sql
-- Sparar spelhandicap per resultat och använder senast kända spelhandicap
-- som tie-break i Totalen.

begin;

alter table public.round_results
  add column if not exists playing_hcp numeric;

commit;

-- Kontroll
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'round_results'
  and column_name = 'playing_hcp';
