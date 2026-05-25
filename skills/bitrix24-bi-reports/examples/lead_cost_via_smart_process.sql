-- Отчёт «Стоимость лидов через смарт-процесс расходов»
-- Применяется, когда сквозная аналитика Битрикса недоступна (например, протухла
-- интеграция Я.Директа) или для тестов на ручных данных.
-- Расходы заводятся в отдельном смарт-процессе и стыкуются с лидами через CRM-источник.
--
-- Пояснения, схема смарт-процесса и шаги настройки — в lead_cost_via_smart_process.md
--
-- ВНИМАНИЕ, портально-специфичные значения (узнаются разведкой, см. references/recon.md):
--   crm_dynamic_items_1036  — 1036 это typeId смарт-процесса конкретного портала
--   uf_crm_19_*             — кодовые имена кастомных полей конкретного портала

WITH
expense_records AS (
    SELECT
        CAST(source_id AS VARCHAR)                                      AS source_id,
        source_name,
        CAST(uf_crm_19_datestart AS DATE)                               AS date_start,
        CAST(uf_crm_19_datestop  AS DATE)                               AS date_stop,
        CAST(uf_crm_19_rashoddouble AS DOUBLE)
            / (DATE_DIFF('day',
                         CAST(uf_crm_19_datestart AS DATE),
                         CAST(uf_crm_19_datestop  AS DATE)) + 1)        AS daily_expense
    FROM bitrix24.crm_dynamic_items_1036
),

-- каждая запись расхода раскладывается на дни своего периода
expense_by_day AS (
    SELECT
        e.source_id,
        e.source_name,
        d.day,
        e.daily_expense
    FROM expense_records e
    CROSS JOIN UNNEST(
        SEQUENCE(e.date_start, e.date_stop, INTERVAL '1' DAY)
    ) AS d(day)
),

-- дневные расходы в периоде фильтра суммируются по источнику
-- (пересекающиеся записи по одному источнику складываются)
expenses_in_period AS (
    SELECT
        source_id,
        ANY_VALUE(source_name)  AS source_name,
        SUM(daily_expense)      AS total_expenses
    FROM expense_by_day
    WHERE
        {% if from_dttm %}
          day >= CAST(from_iso8601_timestamp('{{ from_dttm }}') AS DATE) AND
        {% endif %}
        {% if to_dttm %}
          day < CAST(from_iso8601_timestamp('{{ to_dttm }}') AS DATE) AND
        {% endif %}
        true
    GROUP BY source_id
),

lead_stats AS (
    SELECT
        source_id,
        COUNT(*) AS leads_total,
        COUNT(CASE WHEN status_semantic_id = 'S' THEN 1 END) AS leads_success
    FROM bitrix24.crm_lead
    WHERE
        {% if from_dttm %}
          date_create >= from_iso8601_timestamp('{{ from_dttm }}') AND
        {% endif %}
        {% if to_dttm %}
          date_create < from_iso8601_timestamp('{{ to_dttm }}') AND
        {% endif %}
        true
    GROUP BY source_id
)

SELECT
    {% if from_dttm %}
      CAST(from_iso8601_timestamp('{{ from_dttm }}') AS TIMESTAMP)
    {% else %}
      TIMESTAMP '2000-01-01 00:00:00'
    {% endif %}
                                                            AS date_create,
    COALESCE(e.source_name, l_src.source_name)             AS "Источник",
    COALESCE(e.total_expenses, 0)                          AS "Расход",
    COALESCE(l.leads_total,   0)                           AS "Лид",
    CASE WHEN COALESCE(l.leads_total,   0) > 0
         THEN e.total_expenses / l.leads_total END         AS "Цена Л",
    COALESCE(l.leads_success, 0)                           AS "Лид успешный",
    CASE WHEN COALESCE(l.leads_success, 0) > 0
         THEN e.total_expenses / l.leads_success END       AS "Цена УЛ"
FROM expenses_in_period e
FULL OUTER JOIN lead_stats l ON l.source_id = e.source_id
LEFT JOIN (
    SELECT DISTINCT
        CAST(source_id AS VARCHAR) AS source_id,
        source_name
    FROM bitrix24.crm_lead
) l_src ON l_src.source_id = COALESCE(e.source_id, l.source_id)
ORDER BY "Источник";
