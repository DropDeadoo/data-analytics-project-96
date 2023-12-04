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

last_paid_users as (
/* Создаём подзапрос в котором соединяем таблицы сессий и лидов */
    select
        to_char(
	    ses.visit_date, 'YYYY-MM-DD'
	)
	as visit_date,
	ses.source as utm_source,
	ses.medium as utm_medium,
	ses.campaign as utm_campaign,
	ses.visitor_id,
	ld.lead_id,
	ld.status_id,
	ld.closing_reason,
	ld.amount,
	row_number() over (
	    partition by ses.visitor_id
                order by
	ses.visit_date desc        ) as rn,
/* Нумеруем пользователей совершивших последний платный клик */
	
    from
        sessions ses
    left join leads ld
            on
	ses.visitor_id = ld.visitor_id
	and ses.visit_date <= ld.created_at
    where
	ses.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social') 
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
	case when lpu.status_id = '142' or lpu.closing_reason = 'Успешно реализовано' 
	then '1' end
	) as purchase_count,
	sum(
	case when lpu.status_id = '142' or lpu.closing_reason = 'Успешно реализовано' 
	then lpu.amount end
	) as revenue
    from
	last_paid_users lpu
    left join vk_and_yandex vy 
/* Соединяем с созданным выше запросом по utm-меткам и дате проведения кампании */
	on
	lpu.utm_source = vy.utm_source
	and lpu.utm_medium = vy.utm_medium
	and lpu.utm_campaign = vy.utm_campaign
	and lpu.visit_date = vy.campaign_date
    where
	rn = '1' 
/* Оставляем только пользователей с последним платным кликом */
    group by
	lpu.visit_date,
	lpu.utm_source,
	lpu.utm_medium,
	lpu.utm_campaign
    order by
	9 desc nulls last,
	lpu.visit_date,
	5 desc,
	lpu.utm_source,
	lpu.utm_medium,
	lpu.utm_campaign
    limit 15;
