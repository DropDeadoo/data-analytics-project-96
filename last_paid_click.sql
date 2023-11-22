/* Витрина для модели атрибуции Last Paid Click */
/* Создаем подзапрос, которые объединяет три поля из 2-х таблиц с рекламой от ВК и Яндекса */
with vk_and_ya_utm as (
    select
        utm_source,
        utm_medium,
        utm_campaign
    from vk_ads
    union all
    select
        utm_source,
        utm_medium,
        utm_campaign
    from ya_ads
),
/* Создаём подзапрос в котором находим необходимые поля по условиям + добавляем row_number в разрезе id пользователей */
union_sessions as (
    select
        s.visitor_id,
        s.visit_date,
        vkya.utm_source,
        vkya.utm_medium,
        vkya.utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number() over (partition by s.visitor_id order by visit_date) as rw /* Нумеруем id пользователей, с сортировкой по совершившим последнюю покупку*/
    from sessions as s
    left join leads as l
        on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at /* соединяем по полю id пользователя и дате, чтобы отсеять даты посещен*/
    left join vk_and_ya_utm as vkya
        on
            s.source = vkya.utm_source
            and s.medium = vkya.utm_medium
            and s.campaign = vkya.utm_campaign
)

/*Пишем основной запрос в котором бёрем все поля их подзапроса union_sessions за исключением rw и фильтруем записи только с платными кликами и последними покупками пользователей */
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
    rw = '1'
    and utm_medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
limit 10;
