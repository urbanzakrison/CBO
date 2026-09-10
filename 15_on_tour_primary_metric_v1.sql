-- CBO On Tour – primary competition metric v1
-- Rule: the GameBook result type displayed furthest left is the round's
-- primary competition metric and therefore determines the round winner.
-- Isolated to cbo_tour_*; ordinary CBO scoring is untouched.

begin;

alter table public.cbo_tour_rounds
  add column if not exists primary_metric text;

alter table public.cbo_tour_rounds
  drop constraint if exists cbo_tour_rounds_primary_metric_chk;

alter table public.cbo_tour_rounds
  add constraint cbo_tour_rounds_primary_metric_chk
  check (primary_metric is null or primary_metric in ('stroke_net','stableford_net'));

comment on column public.cbo_tour_rounds.primary_metric is
  'Primary competition metric. For GameBook imports this is the result type displayed furthest left and determines the round winner.';

-- Backfill only where the historical source is unambiguous from the data/rules
-- already verified in the CBO project. Never guess when both metrics exist.

-- Mijas Tour 2024 is explicitly PB-only.
update public.cbo_tour_rounds r
set primary_metric = 'stableford_net'
from public.cbo_tour_events e
where r.event_id = e.id
  and lower(trim(e.name)) = lower('Mijas Tour 2024')
  and e.event_year = 2024
  and r.primary_metric is null;

-- For rounds with exactly one metric represented in imported result rows,
-- that metric is necessarily the primary metric.
update public.cbo_tour_rounds r
set primary_metric = x.metric
from (
  select round_id, min(metric) as metric
  from public.cbo_tour_results
  group by round_id
  having count(distinct metric) = 1
) x
where x.round_id = r.id
  and r.primary_metric is null;

commit;

-- Verification: inspect all imported rounds. NULL is intentional where the
-- original left-to-right GameBook order has not yet been safely verified.
select
  e.name as event_name,
  r.round_no,
  r.title,
  r.primary_metric,
  array_agg(distinct x.metric order by x.metric) filter (where x.metric is not null) as stored_metrics
from public.cbo_tour_events e
join public.cbo_tour_rounds r on r.event_id = e.id
left join public.cbo_tour_results x on x.round_id = r.id
group by e.name, e.event_year, r.round_no, r.title, r.primary_metric
order by e.event_year, e.name, r.round_no;