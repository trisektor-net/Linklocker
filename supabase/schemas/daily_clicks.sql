-- View: daily_clicks
create or replace view public.daily_clicks as
select
  date_trunc('day', timestamp) as day,
  count(*)::int as clicks
from public.clicks
group by 1
order by 1;
