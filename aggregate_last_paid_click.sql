-- Витрина для модели атрибуции Last Paid Click_агрегированная
-- Создаём подзапрос в котором соединяем таблицы
-- рекламных кампаний в ВК и Яндексе
WITH vk_and_yandex AS (
    SELECT
        TO_CHAR(campaign_date, 'YYYY-MM-DD') AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(COALESCE(daily_spent, 0)) AS total_cost
    FROM vk_ads
    GROUP BY 1, 2, 3, 4

    UNION ALL

    SELECT
        TO_CHAR(campaign_date, 'YYYY-MM-DD') AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(COALESCE(daily_spent, 0)) AS total_cost
    FROM ya_ads
    GROUP BY 1, 2, 3, 4
),

last_paid_users AS (
    -- Создаём подзапрос в котором соединяем таблицы сессий и лидов
    SELECT
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        s.visitor_id,
        l.lead_id,
        l.status_id,
        -- Нумеруем пользователей совершивших последний платный клик
        l.closing_reason,
        l.amount,
        TO_CHAR(s.visit_date, 'YYYY-MM-DD') AS visit_date,
        ROW_NUMBER() OVER (PARTITION BY s.visitor_id ORDER BY s.visit_date DESC)
        AS rn
    FROM sessions AS s
    LEFT JOIN 
        leads AS l ON s.visitor_id = l.visitor_id AND 
            s.visit_date <= l.created_at
    WHERE -- Находим пользователей только с платными кликами
        s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

main as ( 
    SELECT
        lpu.visit_date,
        lpu.utm_medium,
        lpu.utm_campaign,
        vy.total_cost AS total_cost,
        COUNT(lpu.visitor_id) AS visitors_count,
        LOWER(lpu.utm_source) AS utm_source,
        COUNT(lpu.lead_id) AS leads_count,
        COUNT(
            CASE
                WHEN
                    lpu.status_id = '142'
                    OR lpu.closing_reason = 'Успешно реализовано'
                    THEN '1'
            END
         ) AS purchases_count,
        SUM(
            CASE
                WHEN
                    lpu.status_id = '142'
                    OR lpu.closing_reason = 'Успешно реализовано'
                    THEN lpu.amount
            END
        ) AS revenue
    FROM last_paid_users AS lpu
    LEFT JOIN vk_and_yandex AS vy
        ON
            lpu.utm_source = vy.utm_source
            AND lpu.utm_medium = vy.utm_medium
            AND lpu.utm_campaign = vy.utm_campaign
            AND lpu.visit_date = vy.campaign_date
-- Оставляем только пользователей с последним платным кликом
     WHERE lpu.rn = '1'
     group by 
         lpu.visit_date,
         lpu.utm_medium,
         LOWER(lpu.utm_source), 
         lpu.utm_campaign,
         vy.total_cost
)
    
select 
    visit_date,
    utm_medium,
    utm_campaign,
    total_cost,
    visitors_count,
    utm_source,
    leads_count,
    purchases_count,
    revenue
from main
ORDER BY
    visit_date ASC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC,
    purchases_count DESC,
    revenue DESC NULLS last
LIMIT 15;
