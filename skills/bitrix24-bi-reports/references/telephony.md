# Телефония и звонки

Часть скилла `bitrix24-bi-reports`. Датасет `telephony_call` соответствует REST-методу `voximplant.statistic.get`. Одна строка = один звонок.

## Ключевые поля

| Поле | Тип | Назначение |
|---|---|---|
| `call_id` | VARCHAR | Уникальный ключ звонка |
| `phone_number` | VARCHAR | Номер абонента (клиента) |
| `portal_number` | VARCHAR | Номер оператора (АТС) |
| `portal_user_id` | BIGINT | ID оператора |
| `portal_user` | VARCHAR | ФИО оператора |
| `call_type` | VARCHAR (!) | `'1'` — исходящий, `'2'` — входящий. **Строка, не число!** |
| `call_duration` | FLOAT | **Длительность разговора в секундах** — основное поле для аналитики дозвона |
| `record_duration` | BIGINT | Длительность файла записи. ⚠️ Часто `NULL` или мусорные значения (1–4 сек) — НЕ использовать как длительность разговора |
| `call_start_time` | TIMESTAMP | Время начала звонка |
| `call_status_code_id` | VARCHAR | Код результата (`'200'` — успех, `'603-S'` — сброс и т.п.) |
| `call_status_reason` | VARCHAR | Расшифровка кода |
| `crm_entity_type` | VARCHAR | `LEAD` / `CONTACT` / `COMPANY` / `DEAL` — к чему привязан звонок |
| `crm_entity_id` | BIGINT | ID объекта CRM |
| `redial_attempt` | INTEGER | Попытки автодозвона в рамках **одного** звонка (не серии попыток менеджера) |

⚠️ **Длительность разговора — это `call_duration`, НЕ `record_duration`.** Несмотря на название «Продолжительность разговора в секундах» в схеме, `record_duration` фактически содержит длительность файла записи и часто пустое/мусорное. Перед любым отчётом по успешности звонков сверять (см. мини-чеклист ниже).

## Связки

- `telephony_call.crm_entity_id = crm_lead.id` при `crm_entity_type = 'LEAD'`
- `telephony_call.crm_entity_id = crm_deal.id` при `crm_entity_type = 'DEAL'`
- `telephony_call.crm_entity_id = crm_contact.id` при `crm_entity_type = 'CONTACT'`
- `telephony_call.crm_entity_id = crm_company.id` при `crm_entity_type = 'COMPANY'`

## Разведка перед телефонным отчётом

Обязательный мини-чек-лист на новом портале (по одному SELECT за сообщение):

```sql
-- 1. Структура таблицы звонков
SELECT * FROM bitrix24.telephony_call LIMIT 1;

-- 2. Распределение типов звонков (какое значение у исходящего)
SELECT call_type, COUNT(*) AS cnt
FROM bitrix24.telephony_call
WHERE call_start_time >= TIMESTAMP '2026-05-01 00:00:00'
GROUP BY call_type
ORDER BY cnt DESC;

-- 3. Какое поле длительности живое
SELECT
    SUM(CASE WHEN call_duration >= 60 THEN 1 ELSE 0 END)   AS call_ge_60,
    SUM(CASE WHEN record_duration >= 60 THEN 1 ELSE 0 END) AS rec_ge_60,
    MAX(call_duration) AS max_call,
    MAX(record_duration) AS max_rec
FROM bitrix24.telephony_call
WHERE call_type = '1'
  AND call_start_time >= TIMESTAMP '2026-05-01 00:00:00';

-- 4. К какой сущности привязаны звонки
SELECT crm_entity_type, COUNT(*) AS cnt
FROM bitrix24.telephony_call
WHERE call_type = '1'
  AND call_start_time >= TIMESTAMP '2026-05-01 00:00:00'
GROUP BY crm_entity_type
ORDER BY cnt DESC;
```

Если `max_call` десятки/сотни секунд, а `max_rec` — единицы или NULL → использовать `call_duration`.

## Что считается «дозвоном» — варианты

- `call_duration >= 60` — содержательный разговор (фильтрует приветствия и сбросы) ← **по умолчанию**
- `call_duration > 0` — любой состоявшийся разговор
- `call_status_code_id = '200'` — успех по коду АТС

## SQL-паттерн: «с какой попытки дозвонились» (сделки, фильтр по воронке)

Логика: группировка по номеру → нумерация звонков по времени → первый звонок с `call_duration >= 60` секунд = попытка дозвона. Если такого нет — недозвон.

```sql
WITH target_deals AS (
    SELECT id
    FROM bitrix24.crm_deal
    WHERE category_id = '0'   -- ID нужной воронки
),
calls AS (
    SELECT
        tc.phone_number,
        tc.call_start_time,
        tc.call_duration,
        ROW_NUMBER() OVER (
            PARTITION BY tc.phone_number
            ORDER BY tc.call_start_time
        ) AS attempt_num
    FROM bitrix24.telephony_call tc
    JOIN target_deals d ON d.id = tc.crm_entity_id
    WHERE tc.call_type = '1'
      AND tc.crm_entity_type = 'DEAL'
      AND tc.call_start_time >= TIMESTAMP '2026-05-01 00:00:00'
      AND tc.phone_number IS NOT NULL
      AND tc.phone_number <> ''
),
per_number AS (
    SELECT
        phone_number,
        MIN(CASE WHEN call_duration >= 60 THEN attempt_num END) AS first_success_attempt
    FROM calls
    GROUP BY phone_number
),
bucketed AS (
    SELECT
        CASE
            WHEN first_success_attempt = 1 THEN '1. С 1-й попытки'
            WHEN first_success_attempt = 2 THEN '2. Со 2-й попытки'
            WHEN first_success_attempt = 3 THEN '3. С 3-й попытки'
            WHEN first_success_attempt = 4 THEN '4. С 4-й попытки'
            WHEN first_success_attempt >= 5 THEN '5. С 5-й и более'
            ELSE                                '6. Так и не дозвонились'
        END AS bucket
    FROM per_number
)
SELECT
    bucket,
    COUNT(*) AS numbers_cnt,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM bucketed
GROUP BY bucket
ORDER BY bucket;
```

## SQL-паттерн: «с какой попытки дозвонились» (лиды)

Для лидовых порталов — фильтр по `date_create` лида:

```sql
WITH target_leads AS (
    SELECT id
    FROM bitrix24.crm_lead
    WHERE date_create >= TIMESTAMP '2026-05-01 00:00:00'
),
calls AS (
    SELECT
        tc.phone_number,
        tc.call_start_time,
        tc.call_duration,
        ROW_NUMBER() OVER (
            PARTITION BY tc.phone_number
            ORDER BY tc.call_start_time
        ) AS attempt_num
    FROM bitrix24.telephony_call tc
    JOIN target_leads l ON l.id = tc.crm_entity_id
    WHERE tc.call_type = '1'
      AND tc.crm_entity_type = 'LEAD'
      AND tc.call_start_time >= TIMESTAMP '2026-05-01 00:00:00'
      AND tc.phone_number IS NOT NULL
      AND tc.phone_number <> ''
),
per_number AS (
    SELECT
        phone_number,
        MIN(CASE WHEN call_duration >= 60 THEN attempt_num END) AS first_success_attempt
    FROM calls
    GROUP BY phone_number
),
bucketed AS (
    SELECT
        CASE
            WHEN first_success_attempt = 1 THEN '1. С 1-й попытки'
            WHEN first_success_attempt = 2 THEN '2. Со 2-й попытки'
            WHEN first_success_attempt = 3 THEN '3. С 3-й попытки'
            WHEN first_success_attempt = 4 THEN '4. С 4-й попытки'
            WHEN first_success_attempt >= 5 THEN '5. С 5-й и более'
            ELSE                                '6. Так и не дозвонились'
        END AS bucket
    FROM per_number
)
SELECT
    bucket,
    COUNT(*) AS numbers_cnt,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM bucketed
GROUP BY bucket
ORDER BY bucket;
```

## SQL-паттерн: качество звонков по номерам АТС

```sql
WITH target_entities AS (
    -- для сделок:
    SELECT id FROM bitrix24.crm_deal WHERE category_id = '0'
    -- для лидов:
    -- SELECT id FROM bitrix24.crm_lead WHERE date_create >= TIMESTAMP '2026-05-01 00:00:00'
)
SELECT
    tc.portal_number,
    COUNT(*) AS total_outgoing,
    SUM(CASE WHEN tc.call_duration >= 60 THEN 1 ELSE 0 END) AS over_60_sec,
    ROUND(
        SUM(CASE WHEN tc.call_duration >= 60 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        1
    ) AS pct_over_60
FROM bitrix24.telephony_call tc
JOIN target_entities t ON t.id = tc.crm_entity_id
WHERE tc.call_type = '1'
  AND tc.crm_entity_type = 'DEAL'   -- или 'LEAD'
  AND tc.call_start_time >= TIMESTAMP '2026-05-01 00:00:00'
  AND tc.portal_number IS NOT NULL
  AND tc.portal_number <> ''
GROUP BY tc.portal_number
ORDER BY total_outgoing DESC;
```

Замена `portal_number` на `portal_user` → срез по операторам, а не по номерам АТС.

## Грабли телефонии

- `redial_attempt` — это попытки автодозвона в рамках **одного** звонка, не серия попыток менеджера. Серию собирать через `ROW_NUMBER() OVER (PARTITION BY phone_number ORDER BY call_start_time)`.
- У одного «номера» в `phone_number` могут оказаться разные клиенты из-за разных префиксов (`+79991234567` vs `79991234567`). Нормализация в CTE: `REGEXP_REPLACE(phone_number, '[^0-9]', '')` и взять последние 10–11 цифр.
- Отчёт по «всем звонкам» неинформативен — менеджеры названивают по старым контактам. Нужен срез по «новым заявкам»: фильтр через CTE с целевыми лидами/сделками + JOIN по `crm_entity_id`.
