/* Витрина для модели атрибуции Last Paid Click_агрегированная */
/* Создаём подзапрос в котором соединяем таблицы */
/* рекламных кампаний в вк и яндексе */
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

last_paid_users as (
    /* Создаём подзапрос в котором соединяем таблицы сессий и лидов */
    select
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        s.visitor_id,
        l.lead_id,
        l.status_id,
        /* Нумеруем пользователей совершивших последний платный клик */
        l.closing_reason,
        l.amount,
        to_char(s.visit_date, 'YYYY-MM-DD') as visit_date,
        row_number() over (partition by s.visitor_id 
        order by s.visit_date desc) as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where /* Находим пользователей только с платными кликами */
        s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
)
select  
    lpu.visit_date,
    count(lpu.visitor_id) as visitors_count,
    lower(lpu.utm_source) as utm_source,
    lpu.utm_medium,
    lpu.utm_campaign,
    vy.total_cost as total_cost,
    count(lpu.lead_id) as leads_count,
    count(
        case
            when
                lpu.status_id = '142'
                or lpu.closing_reason = 'Успешно реализовано'
                then '1'
        end
    ) as purchases_count,
    sum(
        case
            when
                lpu.status_id = '142'
                or lpu.closing_reason = 'Успешно реализовано'
                then lpu.amount
        end
    ) as revenue
from last_paid_users as lpu
left join
/* Соединяем с поздапросом созданным выше по utm-меткам и дате проведения кампании */
    vk_and_yandex as vy 
    on lpu.utm_source = vy.utm_source
	and lpu.utm_medium = vy.utm_medium
	and lpu.utm_campaign = vy.utm_campaign
	and lpu.visit_date = vy.campaign_date
/* Оставляем только пользователей с последним платным кликом */
where lpu.rn = '1' 
group by
    lpu.visit_date,
    lpu.utm_source,
    lpu.utm_medium,
    lpu.utm_campaign,
    vy.total_cost
order by
	1 asc, 3 asc, 4 asc, 5 asc,
	6 desc, 9 desc nulls last
limit 15;
