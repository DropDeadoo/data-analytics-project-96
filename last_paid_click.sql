/* Витрина для модели атрибуции Last Paid Click */

/* Создаём подзапрос в котором находим необходимые поля по условиям + добавляем row_number в разрезе id пользователей */
with union_sessions as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number()
            over (partition by s.visitor_id order by visit_date desc)
        as rn
        /* Нумеруем id пользователей, с сортировкой по совершившим последнюю покупку*/
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
)

/*Пишем основной запрос в котором бёрем все поля их подзапроса union_sessions за исключением rw и фильтруем записи только с последними покупками пользователей */
select
    visitor_id,
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    lead_id,
    created_at,
    amount,
    closing_reason,
    status_id
from union_sessions
where
    rn = '1'
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
limit 10;
