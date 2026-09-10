-- CBO On Tour – historical seed: Mijas Tour 2024
-- User decision: import only Poängbogey NET for this event.
-- R2 and R3 are one 18-hole round each with first9/last9 segments.
-- Values below are the already verified GameBook results from the project work.

begin;

insert into public.cbo_tour_events
  (name, event_year, starts_on, ends_on, location, notes, results_complete)
values
  ('Mijas Tour 2024', 2024, '2024-10-17', '2024-10-20', 'Mijas',
   'Historisk import. Endast Poängbogey NET enligt fastställd projektregel.', true)
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select e.id,1,'Mijas Tour 2024 R1','2024-10-17','Los Lagos',18,'individual','Historisk import från verifierade GameBook-bilder.',true
from public.cbo_tour_events e where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select e.id,2,'Mijas Tour 2024 R2','2024-10-18','Los Olivos',18,'individual','Historisk import från verifierade GameBook-bilder.',true
from public.cbo_tour_events e where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select e.id,3,'Mijas Tour 2024 R3','2024-10-19','Los Lagos',18,'individual','Historisk import från verifierade GameBook-bilder.',true
from public.cbo_tour_events e where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024
on conflict do nothing;

insert into public.cbo_tour_rounds
  (event_id, round_no, title, played_on, course, holes, round_type, notes, results_complete)
select e.id,4,'Mijas Tour 2024 R4','2024-10-20','Los Olivos',18,'individual','Historisk import från verifierade GameBook-bilder.',true
from public.cbo_tour_events e where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024
on conflict do nothing;

-- Results are inserted below via deterministic source refs and unique result identity.
-- R1 full
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'full','stableford_net',v.result,v.to_par,v.pos,'historical_import','mijas-2024-r1-full-pb'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Henrik Lundin',15,38,-2,1),('Johan Fagerholm',20,30,6,2),('Martin Burefors',26,30,6,3),('Tomas Frydebo',19,29,7,4),('Urban Zakrison',23,29,7,5),('Johan Svanå',25,28,8,6),('Anders Norrman',16,26,10,7),('Removed User',17,20,16,8)
) as v(name,hcp,result,to_par,pos)
where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024 and r.round_no=1
on conflict do nothing;

-- R2 first9
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'first9','stableford_net',v.result,v.to_par,v.pos,'historical_import','mijas-2024-r2-first9-pb'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Martin Burefors',26,25,-7,1),('Henrik Lundin',14,19,-1,2),('Johan Fagerholm',19,18,0,3),('Urban Zakrison',23,18,0,4),('Magnus Blennerud',17,16,2,5),('Tomas Frydebo',19,14,4,6),('Anders Norrman',16,12,6,7),('Johan Svanå',25,11,7,8)
) as v(name,hcp,result,to_par,pos)
where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024 and r.round_no=2
on conflict do nothing;

-- R2 last9
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'last9','stableford_net',v.result,v.to_par,v.pos,'historical_import','mijas-2024-r2-last9-pb'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Urban Zakrison',23,20,-2,1),('Tomas Frydebo',19,19,-1,2),('Henrik Lundin',14,18,0,3),('Martin Burefors',26,18,0,4),('Johan Fagerholm',19,17,1,5),('Magnus Blennerud',17,15,3,6),('Johan Svanå',25,14,4,7),('Anders Norrman',16,13,5,8)
) as v(name,hcp,result,to_par,pos)
where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024 and r.round_no=2
on conflict do nothing;

-- R3 first9
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'first9','stableford_net',v.result,v.to_par,v.pos,'historical_import','mijas-2024-r3-first9-pb'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Anders Norrman',16,18,0,1),('Martin Burefors',26,18,0,2),('Henrik Lundin',15,17,1,3),('Johan Fagerholm',20,16,2,4),('Johan Svanå',25,16,2,5),('Urban Zakrison',23,15,3,6),('Magnus Blennerud',17,14,4,7),('Tomas Frydebo',19,13,5,8)
) as v(name,hcp,result,to_par,pos)
where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024 and r.round_no=3
on conflict do nothing;

-- R3 last9
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'last9','stableford_net',v.result,v.to_par,v.pos,'historical_import','mijas-2024-r3-last9-pb'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Urban Zakrison',23,20,-2,1),('Anders Norrman',16,19,-1,2),('Martin Burefors',26,18,0,3),('Tomas Frydebo',19,16,2,4),('Henrik Lundin',15,15,3,5),('Magnus Blennerud',17,14,4,6),('Johan Fagerholm',20,14,4,7),('Johan Svanå',25,12,6,8)
) as v(name,hcp,result,to_par,pos)
where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024 and r.round_no=3
on conflict do nothing;

-- R4 full
insert into public.cbo_tour_results (round_id,player_id,participant_name,displayed_hcp,segment,metric,result_value,to_par,displayed_position,source,source_ref)
select r.id,(select p.id from public.players p where lower(trim(p.name))=lower(v.name) limit 1),v.name,v.hcp,'full','stableford_net',v.result,v.to_par,v.pos,'historical_import','mijas-2024-r4-full-pb'
from public.cbo_tour_rounds r join public.cbo_tour_events e on e.id=r.event_id
cross join (values
('Tomas Frydebo',19,43,-7,1),('Martin Burefors',26,41,-5,2),('Johan Svanå',25,36,0,3),('Henrik Lundin',14,35,1,4),('Johan Fagerholm',19,35,1,5),('Anders Norrman',16,33,3,6),('Urban Zakrison',23,33,3,7),('Magnus Blennerud',17,30,6,8)
) as v(name,hcp,result,to_par,pos)
where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024 and r.round_no=4
on conflict do nothing;

commit;

-- Verification 1: expected rounds=4, result_rows=48
select e.name,count(distinct r.id) as rounds,count(x.id) as result_rows
from public.cbo_tour_events e
left join public.cbo_tour_rounds r on r.event_id=e.id
left join public.cbo_tour_results x on x.round_id=r.id
where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024
group by e.name;

-- Verification 2: expected six segment groups of 8 rows each
select r.round_no,x.segment,x.metric,count(*) as rows
from public.cbo_tour_events e
join public.cbo_tour_rounds r on r.event_id=e.id
join public.cbo_tour_results x on x.round_id=r.id
where lower(trim(e.name))='mijas tour 2024' and e.event_year=2024
group by r.round_no,x.segment,x.metric
order by r.round_no,x.segment;