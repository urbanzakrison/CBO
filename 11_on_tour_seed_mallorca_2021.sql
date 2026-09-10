-- CBO On Tour – historical seed: Mallorca 2021
-- Source: verified GameBook screenshots/date-list from project work.
-- Imports exactly the verified values currently available.
-- No inferred to_par values; they remain NULL.
-- Idempotent: safe to re-run; unique constraints prevent duplicates.

begin;

insert into public.cbo_tour_events
  (name, event_year, starts_on, ends_on, location, notes, results_complete)
values
  ('Mallorca 2021', 2021, '2021-09-16', '2021-09-19', 'Mallorca',
   'Historisk import från verifierade GameBook-bilder.', true)
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select
  e.id, 1, 'Mallorca r1', '2021-09-16', 'East Course', 18, 'individual',
  'Historisk import från verifierade GameBook-bilder.', true
from public.cbo_tour_events e
where lower(trim(e.name))='mallorca 2021' and e.event_year=2021
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select
  e.id, 2, 'Mallorca r2', '2021-09-16', 'East Course', 18, 'individual',
  'Historisk import från verifierade GameBook-bilder.', true
from public.cbo_tour_events e
where lower(trim(e.name))='mallorca 2021' and e.event_year=2021
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select
  e.id, 3, 'Mallorca r3', '2021-09-17', 'West Course', 18, 'individual',
  'Historisk import från verifierade GameBook-bilder.', true
from public.cbo_tour_events e
where lower(trim(e.name))='mallorca 2021' and e.event_year=2021
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select
  e.id, 4, 'Mallorca r4', '2021-09-18', 'Son Gual', 18, 'individual',
  'Historisk import från verifierade GameBook-bilder.', true
from public.cbo_tour_events e
where lower(trim(e.name))='mallorca 2021' and e.event_year=2021
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select
  e.id, 5, 'Mallorca r5', '2021-09-19', 'West Course', 18, 'individual',
  'Historisk import från verifierade GameBook-bilder.', true
from public.cbo_tour_events e
where lower(trim(e.name))='mallorca 2021' and e.event_year=2021
on conflict do nothing;

-- R1
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Urban Zakrison') limit 1),'Urban Zakrison',19,'full','stroke_net',75,null,1,'historical_import','mallorca-2021-r1-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Urban Zakrison') limit 1),'Urban Zakrison',19,'full','stableford_net',35,null,1,'historical_import','mallorca-2021-r1-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Anders Norrman') limit 1),'Anders Norrman',14,'full','stroke_net',78,null,2,'historical_import','mallorca-2021-r1-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Anders Norrman') limit 1),'Anders Norrman',14,'full','stableford_net',30,null,2,'historical_import','mallorca-2021-r1-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Blennerud') limit 1),'Magnus Blennerud',18,'full','stroke_net',80,null,3,'historical_import','mallorca-2021-r1-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Blennerud') limit 1),'Magnus Blennerud',18,'full','stableford_net',29,null,4,'historical_import','mallorca-2021-r1-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Tomas Frydebo') limit 1),'Tomas Frydebo',15,'full','stroke_net',81,null,4,'historical_import','mallorca-2021-r1-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Tomas Frydebo') limit 1),'Tomas Frydebo',15,'full','stableford_net',29,null,3,'historical_import','mallorca-2021-r1-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Henrik Lundin') limit 1),'Henrik Lundin',13,'full','stroke_net',83,null,5,'historical_import','mallorca-2021-r1-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Henrik Lundin') limit 1),'Henrik Lundin',13,'full','stableford_net',26,null,5,'historical_import','mallorca-2021-r1-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Jerkfelt') limit 1),'Magnus Jerkfelt',24,'full','stroke_net',84,null,6,'historical_import','mallorca-2021-r1-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Jerkfelt') limit 1),'Magnus Jerkfelt',24,'full','stableford_net',24,null,7,'historical_import','mallorca-2021-r1-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Fagerholm') limit 1),'Johan Fagerholm',19,'full','stroke_net',85,null,7,'historical_import','mallorca-2021-r1-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Fagerholm') limit 1),'Johan Fagerholm',19,'full','stableford_net',24,null,6,'historical_import','mallorca-2021-r1-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Svanå') limit 1),'Johan Svanå',26,'full','stroke_net',93,null,8,'historical_import','mallorca-2021-r1-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Svanå') limit 1),'Johan Svanå',26,'full','stableford_net',18,null,8,'historical_import','mallorca-2021-r1-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=1 on conflict do nothing;

-- R2
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Blennerud') limit 1),'Magnus Blennerud',18,'full','stroke_net',73,null,1,'historical_import','mallorca-2021-r2-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Blennerud') limit 1),'Magnus Blennerud',18,'full','stableford_net',35,null,1,'historical_import','mallorca-2021-r2-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Jerkfelt') limit 1),'Magnus Jerkfelt',24,'full','stroke_net',77,null,2,'historical_import','mallorca-2021-r2-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Jerkfelt') limit 1),'Magnus Jerkfelt',24,'full','stableford_net',31,null,2,'historical_import','mallorca-2021-r2-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Anders Norrman') limit 1),'Anders Norrman',14,'full','stroke_net',80,null,3,'historical_import','mallorca-2021-r2-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Anders Norrman') limit 1),'Anders Norrman',14,'full','stableford_net',28,null,4,'historical_import','mallorca-2021-r2-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Henrik Lundin') limit 1),'Henrik Lundin',13,'full','stroke_net',81,null,4,'historical_import','mallorca-2021-r2-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Henrik Lundin') limit 1),'Henrik Lundin',13,'full','stableford_net',27,null,6,'historical_import','mallorca-2021-r2-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Tomas Frydebo') limit 1),'Tomas Frydebo',15,'full','stroke_net',82,null,5,'historical_import','mallorca-2021-r2-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Tomas Frydebo') limit 1),'Tomas Frydebo',15,'full','stableford_net',28,null,5,'historical_import','mallorca-2021-r2-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Urban Zakrison') limit 1),'Urban Zakrison',19,'full','stroke_net',82,null,6,'historical_import','mallorca-2021-r2-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Urban Zakrison') limit 1),'Urban Zakrison',19,'full','stableford_net',29,null,3,'historical_import','mallorca-2021-r2-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Svanå') limit 1),'Johan Svanå',26,'full','stroke_net',87,null,7,'historical_import','mallorca-2021-r2-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Svanå') limit 1),'Johan Svanå',26,'full','stableford_net',22,null,8,'historical_import','mallorca-2021-r2-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Fagerholm') limit 1),'Johan Fagerholm',20,'full','stroke_net',92,null,8,'historical_import','mallorca-2021-r2-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Fagerholm') limit 1),'Johan Fagerholm',20,'full','stableford_net',23,null,7,'historical_import','mallorca-2021-r2-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=2 on conflict do nothing;

-- R3
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Anders Norrman') limit 1),'Anders Norrman',16,'full','stroke_net',75,null,1,'historical_import','mallorca-2021-r3-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Anders Norrman') limit 1),'Anders Norrman',16,'full','stableford_net',35,null,1,'historical_import','mallorca-2021-r3-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Tomas Frydebo') limit 1),'Tomas Frydebo',17,'full','stroke_net',75,null,2,'historical_import','mallorca-2021-r3-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Tomas Frydebo') limit 1),'Tomas Frydebo',17,'full','stableford_net',33,null,2,'historical_import','mallorca-2021-r3-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Urban Zakrison') limit 1),'Urban Zakrison',21,'full','stroke_net',78,null,3,'historical_import','mallorca-2021-r3-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Urban Zakrison') limit 1),'Urban Zakrison',21,'full','stableford_net',32,null,4,'historical_import','mallorca-2021-r3-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Henrik Lundin') limit 1),'Henrik Lundin',14,'full','stroke_net',79,null,4,'historical_import','mallorca-2021-r3-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Henrik Lundin') limit 1),'Henrik Lundin',14,'full','stableford_net',30,null,5,'historical_import','mallorca-2021-r3-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Blennerud') limit 1),'Magnus Blennerud',20,'full','stroke_net',80,null,5,'historical_import','mallorca-2021-r3-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Blennerud') limit 1),'Magnus Blennerud',20,'full','stableford_net',32,null,3,'historical_import','mallorca-2021-r3-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Svanå') limit 1),'Johan Svanå',28,'full','stroke_net',81,null,6,'historical_import','mallorca-2021-r3-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Svanå') limit 1),'Johan Svanå',28,'full','stableford_net',30,null,6,'historical_import','mallorca-2021-r3-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Jerkfelt') limit 1),'Magnus Jerkfelt',26,'full','stroke_net',82,null,7,'historical_import','mallorca-2021-r3-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Jerkfelt') limit 1),'Magnus Jerkfelt',26,'full','stableford_net',28,null,7,'historical_import','mallorca-2021-r3-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Fagerholm') limit 1),'Johan Fagerholm',22,'full','stroke_net',93,null,8,'historical_import','mallorca-2021-r3-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Fagerholm') limit 1),'Johan Fagerholm',22,'full','stableford_net',19,null,8,'historical_import','mallorca-2021-r3-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=3 on conflict do nothing;

-- R4
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Blennerud') limit 1),'Magnus Blennerud',21,'full','stroke_net',71,null,1,'historical_import','mallorca-2021-r4-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Blennerud') limit 1),'Magnus Blennerud',21,'full','stableford_net',37,null,1,'historical_import','mallorca-2021-r4-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Urban Zakrison') limit 1),'Urban Zakrison',23,'full','stroke_net',74,null,2,'historical_import','mallorca-2021-r4-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Urban Zakrison') limit 1),'Urban Zakrison',23,'full','stableford_net',36,null,2,'historical_import','mallorca-2021-r4-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Henrik Lundin') limit 1),'Henrik Lundin',16,'full','stroke_net',78,null,3,'historical_import','mallorca-2021-r4-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Henrik Lundin') limit 1),'Henrik Lundin',16,'full','stableford_net',30,null,3,'historical_import','mallorca-2021-r4-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Fagerholm') limit 1),'Johan Fagerholm',23,'full','stroke_net',79,null,4,'historical_import','mallorca-2021-r4-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Fagerholm') limit 1),'Johan Fagerholm',23,'full','stableford_net',30,null,5,'historical_import','mallorca-2021-r4-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Anders Norrman') limit 1),'Anders Norrman',17,'full','stroke_net',80,null,5,'historical_import','mallorca-2021-r4-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Anders Norrman') limit 1),'Anders Norrman',17,'full','stableford_net',30,null,4,'historical_import','mallorca-2021-r4-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Svanå') limit 1),'Johan Svanå',30,'full','stroke_net',81,null,6,'historical_import','mallorca-2021-r4-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Svanå') limit 1),'Johan Svanå',30,'full','stableford_net',28,null,6,'historical_import','mallorca-2021-r4-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Tomas Frydebo') limit 1),'Tomas Frydebo',18,'full','stroke_net',84,null,7,'historical_import','mallorca-2021-r4-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Tomas Frydebo') limit 1),'Tomas Frydebo',18,'full','stableford_net',26,null,7,'historical_import','mallorca-2021-r4-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Jerkfelt') limit 1),'Magnus Jerkfelt',27,'full','stroke_net',86,null,8,'historical_import','mallorca-2021-r4-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Jerkfelt') limit 1),'Magnus Jerkfelt',27,'full','stableford_net',26,null,8,'historical_import','mallorca-2021-r4-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=4 on conflict do nothing;

-- R5
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Urban Zakrison') limit 1),'Urban Zakrison',21,'full','stroke_net',75,null,1,'historical_import','mallorca-2021-r5-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Urban Zakrison') limit 1),'Urban Zakrison',21,'full','stableford_net',34,null,1,'historical_import','mallorca-2021-r5-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Anders Norrman') limit 1),'Anders Norrman',16,'full','stroke_net',76,null,2,'historical_import','mallorca-2021-r5-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Anders Norrman') limit 1),'Anders Norrman',16,'full','stableford_net',32,null,2,'historical_import','mallorca-2021-r5-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Henrik Lundin') limit 1),'Henrik Lundin',14,'full','stroke_net',81,null,3,'historical_import','mallorca-2021-r5-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Henrik Lundin') limit 1),'Henrik Lundin',14,'full','stableford_net',29,null,4,'historical_import','mallorca-2021-r5-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Blennerud') limit 1),'Magnus Blennerud',20,'full','stroke_net',81,null,4,'historical_import','mallorca-2021-r5-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Blennerud') limit 1),'Magnus Blennerud',20,'full','stableford_net',30,null,3,'historical_import','mallorca-2021-r5-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Svanå') limit 1),'Johan Svanå',28,'full','stroke_net',81,null,5,'historical_import','mallorca-2021-r5-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Svanå') limit 1),'Johan Svanå',28,'full','stableford_net',28,null,6,'historical_import','mallorca-2021-r5-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Tomas Frydebo') limit 1),'Tomas Frydebo',17,'full','stroke_net',83,null,6,'historical_import','mallorca-2021-r5-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Tomas Frydebo') limit 1),'Tomas Frydebo',17,'full','stableford_net',29,null,5,'historical_import','mallorca-2021-r5-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Jerkfelt') limit 1),'Magnus Jerkfelt',26,'full','stroke_net',88,null,7,'historical_import','mallorca-2021-r5-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Magnus Jerkfelt') limit 1),'Magnus Jerkfelt',26,'full','stableford_net',24,null,7,'historical_import','mallorca-2021-r5-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Fagerholm') limit 1),'Johan Fagerholm',22,'full','stroke_net',90,null,8,'historical_import','mallorca-2021-r5-stroke' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower('Johan Fagerholm') limit 1),'Johan Fagerholm',22,'full','stableford_net',23,null,8,'historical_import','mallorca-2021-r5-pb' from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id where lower(trim(e.name))='mallorca 2021' and e.event_year=2021 and r.round_no=5 on conflict do nothing;

commit;

-- Verification:
select e.name, count(distinct r.id) as rounds, count(x.id) as result_rows
from public.cbo_tour_events e
left join public.cbo_tour_rounds r on r.event_id=e.id
left join public.cbo_tour_results x on x.round_id=r.id
where lower(trim(e.name))='mallorca 2021' and e.event_year=2021
group by e.name;

select r.round_no, r.played_on, r.course, x.metric, count(*) as rows
from public.cbo_tour_events e
join public.cbo_tour_rounds r on r.event_id=e.id
join public.cbo_tour_results x on x.round_id=r.id
where lower(trim(e.name))='mallorca 2021' and e.event_year=2021
group by r.round_no, r.played_on, r.course, x.metric
order by r.round_no, x.metric;