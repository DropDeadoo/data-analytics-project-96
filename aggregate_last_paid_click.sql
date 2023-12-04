/* Витрина для модели атрибуции Last Paid Click_агрегированная */
/* Запрос объединяет таблицы рекламных кампаний в ВК и Яндексе */
with vk_and_yandex as (
    select
        to_char(
            campaign_date, 'YYYY-MM-DD'
        )
        as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from
        vk_ads
    group by
        1,
        2,
        3,
        4
    union all
    select
        to_char(
            campaign_date, 'YYYY-MM-DD'
        )
        as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from
        ya_ads
    group by
        1,
        2,
        3,
        4
),

/* Создаём подзапрос в котором соединяем таблицы сессий и лидов */
last_paid_users as (
    select
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        s.visitor_id,
        l.lead_id,
        l.status_id,
        l.closing_reason,
        l.amount,
        to_char(
            s.visit_date, 'YYYY-MM-DD'
        )
        as visit_date,
        row_number() over (
            partition by s.visitor_id
            order by s.visit_date desc
        ) as rn
    /* Нумеруем пользователей совершивших последний платный клик */
    from
        sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
/* Находим пользователей только с платными кликами */
)

select
    /* В основном запросе находим необходимые по условию поля */
    lpu.visit_date,
    lpu.utm_source,
    lpu.utm_medium,
    lpu.utm_campaign,
    count(lpu.visitor_id) as visitors_count,
    sum(vy.total_cost) as total_cost,
    count(lpu.lead_id) as leads_count,
    count(
        case
            when
                lpu.status_id = '142'
                then '1'
        end
    ) as purchase_count,
    sum(
        case
            when
                lpu.status_id = '142'
                then lpu.amount
        end
    ) as revenue
from
    last_paid_users as lpu
left join vk_and_yandex as vy
    /* Соединяем по utm-меткам и дате проведения кампании */
    on
        lpu.utm_source = vy.utm_source
        and lpu.utm_medium = vy.utm_medium
        and lpu.utm_campaign = vy.utm_campaign
        and lpu.visit_date = vy.campaign_date
where
    lpu.rn = '1'
/* Оставляем только пользователей с последним платным кликом */
group by
    1,
    2,
    3,
    4
order by
    9 desc nulls last,
    1,
    6 desc,
    2,
    3,
    4
limit 15;
