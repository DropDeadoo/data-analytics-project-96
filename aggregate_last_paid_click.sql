/* Построим витрину со следующими полями:

visit_date — дата визита
utm_source / utm_medium / utm_campaign — метки пользователя
visitors_count — количество визитов в этот день с этими метками
total_cost — затраты на рекламу
leads_count — количество лидов, которые оставили визиты, кликнувшие в этот день с этими метками
purchases_count — количество успешно закрытых лидов (closing_reason = “Успешно реализовано” или status_code = 142)
revenue — деньги с успешно закрытых лидов */

/*Отсортируйте данные по полям
revenue — от большего к меньшему, null записи идут последними
visit_date — от ранних к поздним
visitors_count — в убывающем порядке
utm_source, utm_medium, utm_campaign — в алфавитном порядке */

select *
from leads;
select *
from sessions;
select *
from vk_ads;
select *
from ya_ads;


with vk_and_yandex as (
	select 
		utm_source,
		utm_medium,
		utm_campaign,
		daily_spent
	from vk_ads
	union all
	select 
		utm_source,
		utm_medium,
		utm_campaign,
		daily_spent
	from ya_ads
		   ),
last_paid_users as (
	select 
		visitor_id,
		visit_date,
		row_number() over (partition by visitor_id order by visit_date desc) as rw 
	from sessions
		   ),
union_sessions as (
    select
        to_char(s.visit_date, 'YYYY-MM-DD') as visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign, 
        count(s.visitor_id) as visitors_count,
        sum(vy.daily_spent) as total_cost,
        count(l.lead_id) as leads_count,
        count(case when l.status_id = '142' or l.closing_reason = 'Успешная продажа' then '1' end) as purchases_count,
        sum(case when l.status_id = '142' or l.closing_reason = 'Успешная продажа' then l.amount end) as revenue 
    from sessions as s
    left join leads as l /* соединяем таблицу сессий с лидами по id пользователей */
        on s.visitor_id = l.visitor_id
        and s.visit_date <= l.created_at
    left join vk_and_yandex as vy /* соединяем таблицу сессий с рекламой на площадках яндекса и вк по utm-меткам */
    	on s.source = vy.utm_source
    	and s.medium = vy.utm_medium
    	and s.campaign = vy.utm_campaign
    left join last_paid_users lpu /* соединяем таблицу сессий с таблицей пользователей, последний совершивших платный клик */
    	on s.visitor_id = lpu.visitor_id
    	and s.visit_date = lpu.visit_date
           where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social') and lpu.rw = '1'
           group by s.visit_date, s.source, s.medium, s.campaign, l.status_id, l.closing_reason
           )
		
        select 
           	visit_date,
           	utm_source,
           	utm_medium,
           	utm_campaign,
           	visitors_count,
           	total_cost,
           	leads_count,
           	revenue
           from union_sessions
           order by revenue desc nulls last,
           visit_date,
           visitors_count desc,
           utm_source, utm_medium, utm_campaign;



