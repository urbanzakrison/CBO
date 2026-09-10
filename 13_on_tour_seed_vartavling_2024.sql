-- CBO On Tour – historical seed: Vårtävling 2024
-- Imports only values that are still explicitly available and verified in current project context.
-- Round 1 is created as incomplete, with no fabricated result rows.
-- Rounds 2-4 are imported from verified GameBook result data.

begin;

insert into public.cbo_tour_events
  (name, event_year, starts_on, ends_on, notes, results_complete)
values
  ('Vårtävling 2024', 2024, '2024-05-01', '2024-05-03',
   'Historisk import från verifierade GameBook-bilder. Omgång 1 saknar säker row-level-data i nuvarande sammanställning.', false)
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select
  e.id, 1, 'Omgång 1', '2024-05-01', 'Magnolia & Cedar', 18, 'individual',
  'Resultatbild fanns i tidigare genomgång, men full row-level-data är inte säkert tillgänglig i nuvarande sammanställning. Ingen resultatdata importeras här.', false
from public.cbo_tour_events e
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select
  e.id, 2, 'Omgång 2', '2024-05-02', 'Magnolia & Cedar', 18, 'individual',
  'Historisk import från verifierade GameBook-bilder.', true
from public.cbo_tour_events e
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select
  e.id, 3, 'Omgång 3', '2024-05-02', 'Pine & Magnolia', 9, 'individual',
  '9-hålsrond. Historisk import från verifierade GameBook-bilder.', true
from public.cbo_tour_events e
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select
  e.id, 4, 'Omgång 4', '2024-05-03', 'Magnolia & Cedar', 18, 'individual',
  'Historisk import från verifierade GameBook-bilder.', true
from public.cbo_tour_events e
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024
on conflict do nothing;

-- R2 stroke net
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'full','stroke_net',v.result,v.to_par,v.pos,'historical_import','vartavling-2024-r2-stroke'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Martin Burefors',28,1,74,3),('Peter Timar',13,2,79,8),('Urban Zakrison',20,3,79,8),('Tomas Frydebo',21,4,79,8),('Magnus Blennerud',16,5,82,11),('Håkan Harrysson',16,6,83,12),('Johan Fagerholm',19,7,83,12),('Tobias Henriksson',31,8,83,12),('Johan Svanå',27,9,84,13),('Magnus Jerkfelt',22,10,87,16),('Johan Mattsson',27,11,87,16),('Henrik Lundin',14,12,90,19)
) as v(name,hcp,pos,result,to_par)
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024 and r.round_no=2
on conflict do nothing;

-- R2 stableford net
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'full','stableford_net',v.result,v.to_par,v.pos,'historical_import','vartavling-2024-r2-pb'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Martin Burefors',28,1,34,2),('Tomas Frydebo',21,2,30,6),('Urban Zakrison',20,3,29,7),('Peter Timar',13,4,28,8),('Magnus Blennerud',16,5,28,8),('Håkan Harrysson',16,6,28,8),('Magnus Jerkfelt',22,7,26,10),('Johan Svanå',27,8,25,11),('Tobias Henriksson',31,9,25,11),('Johan Fagerholm',19,10,24,12),('Johan Mattsson',27,11,21,15),('Henrik Lundin',14,12,19,17)
) as v(name,hcp,pos,result,to_par)
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024 and r.round_no=2
on conflict do nothing;

-- R3 stroke net
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'full','stroke_net',v.result,v.to_par,v.pos,'historical_import','vartavling-2024-r3-stroke'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Martin Burefors',27,1,36,0),('Peter Timar',13,2,37,1),('Magnus Jerkfelt',21,3,37,1),('Urban Zakrison',19,4,39,3),('Tomas Frydebo',20,5,39,3),('Magnus Blennerud',15,6,40,4),('Håkan Harrysson',16,7,40,4),('Johan Svanå',26,8,42,6),('Johan Mattsson',26,9,43,7),('Henrik Lundin',14,10,45,9),('Johan Fagerholm',18,11,48,12),('Tobias Henriksson',29,12,50,14)
) as v(name,hcp,pos,result,to_par)
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024 and r.round_no=3
on conflict do nothing;

-- R3 stableford net
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'full','stableford_net',v.result,v.to_par,v.pos,'historical_import','vartavling-2024-r3-pb'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Martin Burefors',27,1,18,0),('Peter Timar',13,2,17,1),('Magnus Jerkfelt',21,3,17,1),('Urban Zakrison',19,4,16,2),('Tomas Frydebo',20,5,16,2),('Johan Svanå',26,6,15,3),('Magnus Blennerud',15,7,14,4),('Håkan Harrysson',16,8,14,4),('Johan Mattsson',26,9,12,6),('Henrik Lundin',14,10,11,7),('Johan Fagerholm',18,11,9,9),('Tobias Henriksson',29,12,7,11)
) as v(name,hcp,pos,result,to_par)
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024 and r.round_no=3
on conflict do nothing;

-- R4 stroke net
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'full','stroke_net',v.result,v.to_par,v.pos,'historical_import','vartavling-2024-r4-stroke'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Martin Burefors',28,1,66,-5),('Johan Fagerholm',19,2,76,5),('Tomas Frydebo',21,3,76,5),('Tobias Henriksson',31,4,76,5),('Håkan Harrysson',16,5,77,6),('Peter Timar',13,6,81,10),('Urban Zakrison',20,7,81,10),('Johan Svanå',27,8,83,12),('Magnus Blennerud',16,9,84,13),('Magnus Jerkfelt',22,10,84,13),('Johan Mattsson',27,11,88,17),('Henrik Lundin',14,12,93,22)
) as v(name,hcp,pos,result,to_par)
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024 and r.round_no=4
on conflict do nothing;

-- R4 stableford net
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'full','stableford_net',v.result,v.to_par,v.pos,'historical_import','vartavling-2024-r4-pb'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Martin Burefors',28,1,41,-5),('Tomas Frydebo',21,2,33,3),('Tobias Henriksson',31,3,32,4),('Johan Fagerholm',19,4,31,5),('Håkan Harrysson',16,5,30,6),('Johan Svanå',27,6,28,8),('Peter Timar',13,7,27,9),('Urban Zakrison',20,8,27,9),('Magnus Blennerud',16,9,25,11),('Magnus Jerkfelt',22,10,24,12),('Johan Mattsson',27,11,24,12),('Henrik Lundin',14,12,18,18)
) as v(name,hcp,pos,result,to_par)
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024 and r.round_no=4
on conflict do nothing;

-- Side contests, round 4
insert into public.cbo_tour_side_contests (round_id,contest_type,hole,participant_name,player_id,placement,value,unit,note,source)
select r.id,v.contest_type,v.hole,v.name,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.placement,v.value,v.unit,'Historisk import från verifierad GameBook-bild.','historical_import'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('nearest_pin',13,'Tomas Frydebo',1,8.50::numeric,'m'),
('nearest_pin',13,'Johan Mattsson',2,10.34::numeric,'m'),
('longest_drive',5,'Martin Burefors',1,null::numeric,null::text),
('longest_drive',5,'Håkan Harrysson',2,null::numeric,null::text),
('longest_drive',5,'Tobias Henriksson',3,null::numeric,null::text)
) as v(contest_type,hole,name,placement,value,unit)
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024 and r.round_no=4
and not exists (
  select 1 from public.cbo_tour_side_contests s
  where s.round_id=r.id and s.contest_type=v.contest_type
    and coalesce(s.hole,-1)=coalesce(v.hole,-1)
    and lower(trim(s.participant_name))=lower(v.name)
    and coalesce(s.placement,-1)=coalesce(v.placement,-1)
);

commit;

-- Verification 1: expected rounds=4, result_rows=72, side_contests=5
select e.name,count(distinct r.id) as rounds,count(distinct x.id) as result_rows,count(distinct s.id) as side_contests
from public.cbo_tour_events e
left join public.cbo_tour_rounds r on r.event_id=e.id
left join public.cbo_tour_results x on x.round_id=r.id
left join public.cbo_tour_side_contests s on s.round_id=r.id
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024
group by e.name;

-- Verification 2: expected round 1 = 0 rows; rounds 2-4 = 24 rows each
select r.round_no,r.results_complete,count(x.id) as result_rows
from public.cbo_tour_events e
join public.cbo_tour_rounds r on r.event_id=e.id
left join public.cbo_tour_results x on x.round_id=r.id
where lower(trim(e.name))='vårtävling 2024' and e.event_year=2024
group by r.round_no,r.results_complete
order by r.round_no;
