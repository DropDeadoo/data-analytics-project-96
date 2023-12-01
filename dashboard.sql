/* Запрос находит кол-во пользователей и лидов, заходящих на сайт. Показывает каналы, по которым они приходят в разрезе дней/недель/месяцев.
 * Дополнительно можно найти lc и lcr для каждого канала */
with advert as (
    select
        medium as utm_medium,
        s.visitor_id,
        l.lead_id,
        to_char(s.visit_date, 'YYYY-MM-DD') as visit_date,
        to_char(s.visit_date, 'day') as day_of_week,
        to_char(s.visit_date, 'W') as num_week,
        to_char(s.visit_date, 'Month') as month,
        case when l.amount != '0' or null then '1' end as amount
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
)

select
    visit_date,
    day_of_week,
    num_week,
    month,
    utm_medium,
    count(distinct visitor_id) as visitors_count,
    count(distinct lead_id) as leads_count,
    count(amount) as customers_count,
    round(
        cast(
            cast (count(lead_id) as float)
            / nullif(cast (count(distinct visitor_id) as float), 0)
            * 100 as numeric
        ),
        2
    ) as lcr,
    round(
        cast(
            cast (count(amount) as float)
            / nullif(cast (count(lead_id) as float), 0)
            * 100 as numeric
        ),
        2
    ) as lc
from advert
group by 1, 2, 3, 4, 5
order by 1;


/* Общая конверсия ил клика в лид и из лида в оплату */
with conv_rate as (
    select
        s.visitor_id,
        l.lead_id,
        case when l.amount != '0' or null then '1' end as amount
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where medium != 'organic'
)

select
    round(
        cast(
            cast (count(lead_id) as float)
            / cast (count(distinct visitor_id) as float)
            * 100 as numeric
        ),
        2
    ) as lcr,
    round(
        cast(
            cast (count(amount) as float)
            / cast (count(lead_id) as float)
            * 100 as numeric
        ),
        2
    ) as lc
from conv_rate;

/* Запрос находит стоимость рекламы в различных каналах и доходы. */
with main1 as (
    select
        s.visitor_id,
        s.visit_date,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        vk.daily_spent as ads_cost,
        lower(s.source) as utm_source

    from sessions as s
    left join vk_ads as vk
        on
            s.source = vk.utm_source
            and s.medium = vk.utm_medium
            and s.campaign = vk.utm_campaign
    left join ya_ads as ya
        on
            s.source = ya.utm_source
            and s.medium = ya.utm_medium
            and s.campaign = ya.utm_campaign
),

main2 as (
    select
        m1.utm_medium,
        m1.utm_campaign,
        m1.ads_cost,
        lower(m1.utm_source),
        case when l.amount = '0' then null else l.amount end as revenue
    from main1 as m1
    left join leads as l
        on
            m1.visitor_id = l.visitor_id
            and m1.visit_date <= l.created_at
)

select
    utm_medium,
    sum(ads_cost) as adv_costs,
    sum(revenue) as revenue
from main2
group by 1;
/* За сколько дней с момента перехода по рекламе закрывается 90% лидов. */
with registration_date as (
	select 
		visitor_id,
		visit_date as first_visit_date,
		row_number() over (partition by visitor_id order by visit_date asc) as rn, /* найдем первый переход пользователя */
		source,
		medium,
		campaign
	from sessions
	),
	main as (
	select 
		rd.visitor_id,
		rd.first_visit_date,
		l.lead_id,
		l.created_at as lead_date,
		rd.source,
		rd.medium,
		rd.campaign,
		l.amount
	from registration_date rd
	left join leads l
	on rd.visitor_id = l.visitor_id
	and rd.first_visit_date <= l.created_at
	where rn = '1' and l.closing_reason = 'Успешная продажа'
	
	)/* ,

tab as(	*/
	select 	
		/*lead_id,*/
		medium,
		round(cast(avg(extract(day from lead_date - first_visit_date)) as numeric), 0) as lifetime,
		avg(amount) as avg_amount,
		avg(extract(day from lead_date - first_visit_date)) * avg(amount) as ltv 
	from main
	group by 1
	order by 2
	)
/* За сколько закрывается 90 прцоентов сделок по рекламным кампаниям?*/	

with advert as (
    select 
    	to_char(s.visit_date, 'YYYY-MM-DD') as visit_date,
    	to_char(l.visit_date, 'YYYY-MM-DD') as 
        medium as utm_medium,
        s.visitor_id,
    	l.lead_id,
    	case when l.amount <> '0' or null then '1' end as amount
    from sessions s 
	left join leads l
	on s.visitor_id = l.visitor_id
	and s.visit_date <= l.created_at
    )
     
select
	visit_date,
    utm_medium,
    lead_id
    from advert
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
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
/* Находим пользователей только с платными кликами */

),

main as (
    select  /* В основном запросе находим необходимые по условию поля */
        lpu.visit_date,
        count(lpu.visitor_id) as visitors_count,
        lower(lpu.utm_source) as utm_source,
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
        vk_and_yandex as vy /* Соединяем с view созданной выше по utm-меткам и дате проведения кампании */
        on
            lpu.utm_source = vy.utm_source
            and lpu.visit_date = vy.campaign_date
    where
        rn = '1'
    /* Оставляем только пользователей с последним платным кликом */
    group by
        lpu.visit_date,
        lpu.utm_source,
        vy.total_cost
    order by
        7 desc nulls last,
        lpu.visit_date,
        4 desc,
        lpu.utm_source
)

select
    visit_date,
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
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
/* Находим пользователей только с платными кликами */

),

main as (
    select  /* В основном запросе находим необходимые по условию поля */
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
        vk_and_yandex as vy /* Соединяем с view созданной выше по utm-меткам и дате проведения кампании */
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
        lpu.utm_campaign,
        vy.total_cost
    order by
        9 desc nulls last,
        lpu.visit_date,
        6 desc,
        lpu.utm_source, lpu.utm_medium asc, lpu.utm_campaign asc
)

select
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    round(total_cost / nullif(visitors_count, 0), 2) as cpu,
    round(total_cost / nullif(leads_count, 0), 2) as cpl,
    round(total_cost / nullif(purchases_count, 0), 2) as cppu,
    round((revenue - total_cost) / nullif(total_cost, 0) * 100.0, 2) as roi
from main
order by 1;