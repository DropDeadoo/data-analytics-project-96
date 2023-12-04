-- Витрина для модели атрибуции Last Paid Click_агрегированная
-- Создаём подзапрос, в котором соединяем таблицы рекламных кампаний в ВК и Яндексе
WITH vk_and_yandex AS (
    SELECT
        TO_CHAR(campaign_date, 'YYYY-MM-DD') AS campaign_date,
        utm_source, utm_medium, utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY campaign_date, utm_source, utm_medium, utm_campaign

    UNION ALL

    SELECT
        TO_CHAR(campaign_date, 'YYYY-MM-DD') AS campaign_date,
        utm_source, utm_medium, utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY campaign_date, utm_source, utm_medium, utm_campaign
),

last_paid_users AS (
    -- Создаём подзапрос, в котором соединяем таблицы сессий и лидов
    SELECT
        TO_CHAR(s.visit_date, 'YYYY-MM-DD') AS visit_date,
        s.source AS utm_source, s.medium AS utm_medium, s.campaign AS utm_campaign,
        s.visitor_id,
        ROW_NUMBER() OVER (PARTITION BY s.visitor_id ORDER BY s.visit_date DESC) AS rn,
        l.lead_id, l.status_id, l.closing_reason, l.amount
    FROM sessions s
    LEFT JOIN leads l ON s.visitor_id = l.visitor_id AND s.visit_date <= l.created_at
    WHERE medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

main_query AS (
    -- В основном запросе находим необходимые по условию поля
    SELECT
        lpu.visit_date, lpu.utm_source, lpu.utm_medium, lpu.utm_campaign,
        COUNT(lpu.visitor_id) AS visitors_count,
        SUM(vy.total_cost) AS total_cost,
        COUNT(lpu.lead_id) AS leads_count,
        COUNT(CASE WHEN lpu.status_id = '142' OR lpu.closing_reason = 'Успешно реализовано' THEN '1' END) AS purchase_count,
        SUM(CASE WHEN lpu.status_id = '142' OR lpu.closing_reason = 'Успешно реализовано' THEN lpu.amount END) AS revenue
    FROM last_paid_users lpu
    LEFT JOIN vk_and_yandex vy ON lpu.utm_source = vy.utm_source
        AND lpu.utm_medium = vy.utm_medium
        AND lpu.utm_campaign = vy.utm_campaign
        AND lpu.visit_date = vy.campaign_date
    WHERE rn = '1' -- Оставляем только пользователей с последним платным кликом
    GROUP BY lpu.visit_date, lpu.utm_source, lpu.utm_medium, lpu.utm_campaign
)

-- Итоговый запрос
SELECT
    visit_date, utm_source, utm_medium, utm_campaign,
    visitors_count, total_cost, leads_count, purchase_count, revenue
FROM main_query
ORDER BY total_cost DESC NULLS LAST, visit_date, visitors_count DESC, utm_source, utm_medium, utm_campaign
LIMIT 15;
