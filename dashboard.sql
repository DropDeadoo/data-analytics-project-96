/*Сколько у нас пользователей заходят на сайт? 
select 
	to_char(visit_date, 'YYYY-MM-DD') as visit_date,
	count(visitor_id) as visitors_count
from sessions
group by 1
order by 1; */

/* Сколько у нас пользователей заходят на сайт? Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам Сколько лидов к нам приходят? */
with advert as (
    select 
    	to_char(s.visit_date, 'YYYY-MM-DD') as visit_date,
        to_char(s.visit_date, 'day') as day_of_week,
        to_char(s.visit_date, 'W') as num_week,
        to_char(s.visit_date, 'Month') as Month,
        medium as utm_medium,
        count(distinct s.visitor_id) as visitors_count,
        count(l.lead_id) as count_leads
    from sessions s 
	left join leads l
	on s.visitor_id = l.visitor_id
	and s.visit_date <= l.created_at
    group by 1, 2, 3, 4, 5),
num_of_week as (    
 	select case
	 	when day_of_week = 'monday   ' then '1'
        when day_of_week = 'tuesday  ' then '2'
        when day_of_week = 'wednesday' then '3'
        when day_of_week = 'thursday ' then '4'
        when day_of_week = 'friday   ' then '5'
        when day_of_week = 'saturday ' then '6'
        when day_of_week = 'sunday   ' then '7'
     end as num_of_day_week,
     visit_date,
     day_of_week,
     num_week,
     Month,
     utm_medium,
     visitors_count,
     count_leads
     from advert
     order by 1 asc, 2)
     
select
	 visit_date,
     day_of_week,
     num_week,
     Month,
     utm_medium,
     visitors_count,
     count_leads
     from num_of_week
    order by 1;

/* Сколько лидов к нам приходят?
select 
    to_char(s.visit_date, 'YYYY-MM-DD') as visit_date,
    to_char(visit_date, 'day') as day_of_week,
    to_char(visit_date, 'W') as num_week,
    to_char(visit_date, 'Month') as Month,
    count(l.lead_id) as count_leads
from sessions s
left join leads l
on s.visitor_id = l.visitor_id
and s.visit_date <= l.created_at
group by 1, 2, 3, 4; */
    
/* Какая конверсия из клика в лид? А из лида в оплату? Проблема: кол-во лидов и пользователей не сходится с таблицей выше */
select 
	count(lead_id) as count_lead,
	count(distinct visitor_id) as visitors_count,
	(select count(amount) from leads where amount <> '0') as amount_count, /* Найдем кол-во платежей */
	round(cast(count(lead_id)::float / count(distinct visitor_id)::float * 100 as numeric), 2) as lcr,
	round(cast((select count(amount) from leads where amount <> '0')::float / count(lead_id)::float * 100 as numeric), 2) as lc
from sessions s
left join leads l
using (visitor_id);

/* Сколько мы тратим по разным каналам в динамике? */
select 
	to_char(campaign_date, 'YYYY-MM-DD') as campaign_date,
	utm_source,
	sum(daily_spent) as total_cost
from vk_ads
where utm_medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
group by 1, 2
union all
select 
	to_char(campaign_date, 'YYYY-MM-DD') as campaign_date,
	utm_source,
	sum(daily_spent) as total_cost
from ya_ads
where utm_medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
group by 1, 2
order by 1, 3;

/* Окупаются ли каналы? */

with vk_and_yandex as (
	select 
		to_char(campaign_date, 'YYYY-MM-DD') as campaign_date,
		utm_source,
		utm_campaign,
		utm_medium,
		sum(coalesce(daily_spent, 0)) as total_cost
	from vk_ads
	where utm_medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
	group by 1, 2, 3, 4
	union all
	select 
		to_char(campaign_date, 'YYYY-MM-DD') as campaign_date,
		utm_source,
		utm_campaign,
		utm_medium,
		sum(coalesce(daily_spent, 0)) as total_cost
	from ya_ads
	where utm_medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
	group by 1, 2, 3, 4),
	
leads as (
	select 
		to_char(l.created_at, 'YYYY-MM-DD') as created_at,
		sum(case when l.status_id = '142' or l.closing_reason = 'Успешно реализовано' then l.amount end) as revenue
	from leads l
	group by 1)

select 
	vy.campaign_date,
	vy.utm_source,
	round(sum(vy.total_cost), 0) as ads_costs,
	round(sum(l.revenue), 0) as revenue,
	round(sum(l.revenue), 0) - round(sum(vy.total_cost), 0) as diff
	from vk_and_yandex vy
	join leads l
	on vy.campaign_date = l.created_at
group by 1, 2
order by 1;

/* Основные метрики:
cpu = total_cost / visitors_count
cpl = total_cost / leads_count
cppu = total_cost / purchases_count
roi = (revenue - total_cost) / total_cost * 100%
При расчете метрик, используйте агрегацию по utm_source. Затем, для более детального анализа, сделайте расчет метрик по source, medium и campaign. */
with vk_and_yandex as (
	select 
		to_char(campaign_date, 'YYYY-MM-DD') as campaign_date,
		utm_source,
		utm_medium,
		utm_campaign,
		sum(coalesce(daily_spent, 0)) as total_cost
	from vk_ads
	group by 1, 2, 3, 4
	union all
	select 
		to_char(campaign_date, 'YYYY-MM-DD') as campaign_date,
		utm_source,
		utm_medium,
		utm_campaign,
		sum(coalesce(daily_spent, 0)) as total_cost
	from ya_ads
	group by 1, 2, 3, 4
		   ),
last_paid_users as ( /* Создаём подзапрос в котором соединяем таблицы сессий и лидов */ 
	select 
		to_char(s.visit_date, 'YYYY-MM-DD') as visit_date,
		s.source as utm_source,
		s.medium as utm_medium,
		s.campaign as utm_campaign,
		s.visitor_id,
		row_number() over (partition by s.visitor_id order by s.visit_date desc) as rn, /* Нумеруем пользователей совершивших последний платный клик */ 
		l.lead_id,
		l.status_id,
		l.closing_reason,
		l.amount 
	from sessions s
	left join leads l
	on s.visitor_id = l.visitor_id 
	and s.visit_date <= l.created_at
	where medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social') /* Находим пользователей только с платными кликами */ 
	
		   ),
		   
main as(
	select  /* В основном запросе находим необходимые по условию поля */
		lpu.visit_date,
		count(lpu.visitor_id) as visitors_count,
		lower(lpu.utm_source) as utm_source,
		vy.total_cost as total_cost,
		count(lpu.lead_id) as leads_count,
		count(case when lpu.status_id = '142' or lpu.closing_reason = 'Успешно реализовано' then '1' end) as purchases_count,
		sum(case when lpu.status_id = '142' or lpu.closing_reason = 'Успешно реализовано' then lpu.amount end) as revenue
		from last_paid_users lpu
		left join vk_and_yandex vy /* Соединяем с view созданной выше по utm-меткам и дате проведения кампании */ 
		on lpu.utm_source = vy.utm_source
		and lpu.visit_date = vy.campaign_date
		where rn = '1' /* Оставляем только пользователей с последним платным кликом */ 
		group by  
			lpu.visit_date,
			lpu.utm_source,
			vy.total_cost
		order by 7 desc nulls last,
           lpu.visit_date,
           4 desc,
           lpu.utm_source
        )
       
select visit_date,
utm_source,
round(total_cost / nullif(visitors_count, 0), 2) as cpu,
round(total_cost / nullif(leads_count, 0), 2) as cpl,
round(total_cost / nullif(purchases_count, 0), 2) as cppu,
round((revenue - total_cost) / nullif(total_cost, 0) * 100.0, 2) as roi
from main
order by 1;
/* Детализированная сводная таблица по utm_source, utm_medium, utm_campaign */
with vk_and_yandex as (
	select 
		to_char(campaign_date, 'YYYY-MM-DD') as campaign_date,
		utm_source,
		utm_medium,
		utm_campaign,
		sum(coalesce(daily_spent, 0)) as total_cost
	from vk_ads
	group by 1, 2, 3, 4
	union all
	select 
		to_char(campaign_date, 'YYYY-MM-DD') as campaign_date,
		utm_source,
		utm_medium,
		utm_campaign,
		sum(coalesce(daily_spent, 0)) as total_cost
	from ya_ads
	group by 1, 2, 3, 4
		   ),
last_paid_users as ( /* Создаём подзапрос в котором соединяем таблицы сессий и лидов */ 
	select 
		to_char(s.visit_date, 'YYYY-MM-DD') as visit_date,
		s.source as utm_source,
		s.medium as utm_medium,
		s.campaign as utm_campaign,
		s.visitor_id,
		row_number() over (partition by s.visitor_id order by s.visit_date desc) as rn, /* Нумеруем пользователей совершивших последний платный клик */ 
		l.lead_id,
		l.status_id,
		l.closing_reason,
		l.amount 
	from sessions s
	left join leads l
	on s.visitor_id = l.visitor_id 
	and s.visit_date <= l.created_at
	where medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social') /* Находим пользователей только с платными кликами */ 
	
		   ),
		   
main as(
	select  /* В основном запросе находим необходимые по условию поля */
		lpu.visit_date,
		count(lpu.visitor_id) as visitors_count,
		lower(lpu.utm_source) as utm_source,
		lpu.utm_medium,
		lpu.utm_campaign,
		vy.total_cost as total_cost,
		count(lpu.lead_id) as leads_count,
		count(case when lpu.status_id = '142' or lpu.closing_reason = 'Успешно реализовано' then '1' end) as purchases_count,
		sum(case when lpu.status_id = '142' or lpu.closing_reason = 'Успешно реализовано' then lpu.amount end) as revenue
		from last_paid_users lpu
		left join vk_and_yandex vy /* Соединяем с view созданной выше по utm-меткам и дате проведения кампании */ 
		on lpu.utm_source = vy.utm_source
		and lpu.utm_medium = vy.utm_medium
		and lpu.utm_campaign = vy.utm_campaign
		and lpu.visit_date = vy.campaign_date
		where rn = '1' /* Оставляем только пользователей с последним платным кликом */ 
		group by  
			lpu.visit_date,
			lpu.utm_source,
			lpu.utm_medium,
			lpu.utm_campaign,
			vy.total_cost
		order by 9 desc nulls last,
           lpu.visit_date,
           6 desc,
           lpu.utm_source, lpu.utm_medium, lpu.utm_campaign
        )
       
select visit_date,
utm_source,
utm_medium,
utm_campaign,
round(total_cost / nullif(visitors_count, 0), 2) as cpu,
round(total_cost / nullif(leads_count, 0), 2) as cpl,
round(total_cost / nullif(purchases_count, 0), 2) as cppu,
round((revenue - total_cost) / nullif(total_cost, 0) * 100.0, 2) as roi
from main
order by 1;
