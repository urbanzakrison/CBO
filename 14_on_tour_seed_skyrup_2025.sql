-- CBO On Tour – historical seed: Vårtävling 2025 / Skyrup
-- Conservative import: only row-level values explicitly retained and verified.
-- R1 date is NULL (not verified). R2/R3 are created but left without rows.
-- R4 HCP/to_par are NULL where exact values are not safely retained.

begin;

insert into public.cbo_tour_events
  (name, event_year, starts_on, ends_on, location, notes, results_complete)
values
  ('Vårtävling 2025 – Skyrup', 2025, null, '2025-05-10', 'Skyrups Golfklubb',
   'Historisk import. R2/R3-resultatbilder fanns i tidigare genomgång men exakta row-level-rader är inte säkert tillgängliga i nuvarande sammanställning.', false)
on conflict do nothing;

insert into public.cbo_tour_rounds (event_id,round_no,title,played_on,course,holes,round_type,notes,results_complete)
select e.id,1,'Vårtävling 2025 r1',null,'Skyrups Golfklubb',18,'individual','Datum ej verifierat. Resultatrader för R1 är verifierade.',false from public.cbo_tour_events e where lower(trim(e.name))=lower('Vårtävling 2025 – Skyrup') and e.event_year=2025 on conflict do nothing;
insert into public.cbo_tour_rounds (event_id,round_no,title,played_on,course,holes,round_type,notes,results_complete)
select e.id,2,'Vårtävling 2025 r2','2025-05-09','Skyrups Golfklubb',18,'individual','Urban 87 (+16) verifierat i datumlistan; full row-level-data importeras inte utan säker källa.',false from public.cbo_tour_events e where lower(trim(e.name))=lower('Vårtävling 2025 – Skyrup') and e.event_year=2025 on conflict do nothing;
insert into public.cbo_tour_rounds (event_id,round_no,title,played_on,course,holes,round_type,notes,results_complete)
select e.id,3,'Vårtävling 2025 r3','2025-05-09','Skyrups Golfklubb',18,'individual','Urban 40 (+5) verifierat i datumlistan; full row-level-data importeras inte utan säker källa.',false from public.cbo_tour_events e where lower(trim(e.name))=lower('Vårtävling 2025 – Skyrup') and e.event_year=2025 on conflict do nothing;
insert into public.cbo_tour_rounds (event_id,round_no,title,played_on,course,holes,round_type,notes,results_complete)
select e.id,4,'Vårtävling 2025 r4','2025-05-10','Skyrups Golfklubb',18,'individual','Resultatrader verifierade. HCP lämnas NULL där exakta värden inte är säkert tillgängliga.',true from public.cbo_tour_events e where lower(trim(e.name))=lower('Vårtävling 2025 – Skyrup') and e.event_year=2025 on conflict do nothing;

-- Result rows are deliberately explicit and idempotent.
-- R1 stroke net
with d(name,hcp,pos,val,tp) as (values
('Peter Timar',14,1,73,2),('Magnus Jerkfelt',26,2,75,4),('Magnus Blennerud',17,3,76,5),('Martin Burefors',25,4,77,6),('Tobias Henriksson',31,5,78,7),('Håkan Harrysson',19,6,80,9),('Tomas Frydebo',19,7,81,10),('Johan Fagerholm',20,8,85,14),('Henrik Lundin',14,9,86,15),('Johan Svanå',28,10,88,17))
insert into public.cbo_tour_results(round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(d.name) limit 1),d.name,d.hcp,'full','stroke_net',d.val,d.tp,d.pos,'historical_import','skyrup-2025-r1-stroke'
from d cross join public.cbo_tour_events e join public.cbo_tour_rounds r on r.event_id=e.id and r.round_no=1
where lower(trim(e.name))=lower('Vårtävling 2025 – Skyrup') and e.event_year=2025 on conflict do nothing;

-- R1 stableford net
with d(name,hcp,pos,val) as (values
('Magnus Blennerud',17,1,35),('Peter Timar',14,2,34),('Martin Burefors',25,3,32),('Magnus Jerkfelt',26,4,32),('Tobias Henriksson',31,5,32),('Håkan Harrysson',19,6,28),('Tomas Frydebo',19,7,26),('Johan Svanå',28,8,25),('Henrik Lundin',14,9,24),('Johan Fagerholm',20,10,24))
insert into public.cbo_tour_results(round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(d.name) limit 1),d.name,d.hcp,'full','stableford_net',d.val,null,d.pos,'historical_import','skyrup-2025-r1-pb'
from d cross join public.cbo_tour_events e join public.cbo_tour_rounds r on r.event_id=e.id and r.round_no=1
where lower(trim(e.name))=lower('Vårtävling 2025 – Skyrup') and e.event_year=2025 on conflict do nothing;

-- R4 stroke net; HCP/to_par intentionally NULL
with d(name,pos,val) as (values
('Martin Burefors',1,70),('Removed User',2,76),('Urban Zakrison',3,77),('Magnus Jerkfelt',4,77),('Peter Timar',5,78),('Magnus Blennerud',6,79),('Tobias Henriksson',7,80),('Henrik Lundin',8,81),('Johan Fagerholm',9,83),('Tomas Frydebo',10,87))
insert into public.cbo_tour_results(round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(d.name) limit 1),d.name,null,'full','stroke_net',d.val,null,d.pos,'historical_import','skyrup-2025-r4-stroke'
from d cross join public.cbo_tour_events e join public.cbo_tour_rounds r on r.event_id=e.id and r.round_no=4
where lower(trim(e.name))=lower('Vårtävling 2025 – Skyrup') and e.event_year=2025 on conflict do nothing;

-- R4 stableford net; HCP/to_par intentionally NULL
with d(name,pos,val) as (values
('Martin Burefors',1,37),('Removed User',2,32),('Urban Zakrison',3,31),('Peter Timar',4,30),('Magnus Blennerud',5,30),('Magnus Jerkfelt',6,30),('Tobias Henriksson',7,29),('Henrik Lundin',8,27),('Tomas Frydebo',9,24),('Johan Fagerholm',10,24))
insert into public.cbo_tour_results(round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(d.name) limit 1),d.name,null,'full','stableford_net',d.val,null,d.pos,'historical_import','skyrup-2025-r4-pb'
from d cross join public.cbo_tour_events e join public.cbo_tour_rounds r on r.event_id=e.id and r.round_no=4
where lower(trim(e.name))=lower('Vårtävling 2025 – Skyrup') and e.event_year=2025 on conflict do nothing;

commit;

-- Verification: expected 4 rounds, 40 result rows.
select e.name, count(distinct r.id) as rounds, count(x.id) as result_rows
from public.cbo_tour_events e left join public.cbo_tour_rounds r on r.event_id=e.id left join public.cbo_tour_results x on x.round_id=r.id
where lower(trim(e.name))=lower('Vårtävling 2025 – Skyrup') and e.event_year=2025 group by e.name;

-- Expected: R1=20, R2=0, R3=0, R4=20.
select r.round_no,r.played_on,r.results_complete,count(x.id) as result_rows
from public.cbo_tour_events e join public.cbo_tour_rounds r on r.event_id=e.id left join public.cbo_tour_results x on x.round_id=r.id
where lower(trim(e.name))=lower('Vårtävling 2025 – Skyrup') and e.event_year=2025
group by r.round_no,r.played_on,r.results_complete order by r.round_no;