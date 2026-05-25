# Смарт-процессы

Часть скилла `bitrix24-bi-reports`. В Битрикс24 смарт-процессы (СП) — это пользовательские CRM-сущности (счета, проекты, заявки и т.п.) с собственными воронками и стадиями. В BI-конструкторе они хранятся в **отдельных таблицах для каждого типа**.

## Структура

- `crm_smart_proc` — справочник типов смарт-процессов портала
- `crm_dynamic_items_<typeId>` — элементы смарт-процесса конкретного типа (одна таблица = один тип)
- `crm_dynamic_items_prod_<typeId>` — товарные позиции элементов смарт-процесса
- `crm_entity_stage_history` — универсальная история стадий по **всем** смарт-процессам портала

## Зарезервированный ID

- `31` = **Счета** (CRM Invoices) — зарезервирован Битриксом, одинаков для всех порталов.
  - `crm_dynamic_items_31` — счета
  - `crm_dynamic_items_prod_31` — товарные позиции счетов

Все остальные `typeId` — портально-специфичные. Узнать список типов на конкретном портале:

```sql
SELECT * FROM bitrix24.crm_smart_proc;
```

или через имена таблиц:

```sql
SHOW TABLES IN bitrix24 LIKE 'crm_dynamic_items_%';
```

## История стадий смарт-процессов: `crm_entity_stage_history`

Универсальная таблица истории по всем СП портала. Структура:

| Поле | Тип | Назначение |
|---|---|---|
| `id` | BIGINT | Уникальный ключ записи |
| `type_id` | BIGINT | Тип записи истории |
| `owner_type_id` | BIGINT | **ID типа смарт-процесса** (для счетов = 31) |
| `owner_id` | BIGINT | ID элемента смарт-процесса (FK на `crm_dynamic_items_<typeId>.id`) |
| `date_create` | TIMESTAMP | Дата создания записи истории |
| `start_date` | DATE | Дата начала пребывания в стадии |
| `end_date` | DATE | Дата завершения пребывания в стадии |
| `responsible_by_id` | BIGINT | ID ответственного |
| `responsible_by_name` | VARCHAR | Имя ответственного |
| `responsible_by` | VARCHAR | Ответственный (форматированное) |
| `responsible_by_department` | VARCHAR | Отдел ответственного |
| `category_id` | BIGINT | **ID воронки смарт-процесса** (нумерация портально-специфичная) |
| `category_name` | VARCHAR | Название воронки |
| `category` | VARCHAR | Воронка (форматированное) |
| `stage_semantic_id` | VARCHAR | ID типа стадии (`P` / `S` / `F`) |
| `stage_semantic` | VARCHAR | Тип стадии (форматированное) |
| `stage_id` | VARCHAR | Код стадии |
| `stage_name` | VARCHAR | Название стадии |
| `stage` | VARCHAR | Стадия (форматированное) |

⚠️ `category_id` в `crm_entity_stage_history` **всегда заполнено**, NULL не встречается. Значение зависит от конкретной воронки портала — разведать `SELECT DISTINCT category_id` для нужного `owner_type_id` перед фильтрацией.

⚠️ В отличие от сделок и лидов, в смарт-процессах **уже встроены** имена ответственного, отдела, воронки и стадии — JOIN с `user`, `crm_stages` и т.п. часто не нужен. Это удобно для упрощения SQL.

## Различия трёх таблиц истории

| Таблица | Для какой сущности | FK на основную таблицу |
|---|---|---|
| `crm_deal_stage_history` | Сделки | `deal_id` |
| `crm_lead_status_history` | Лиды | `lead_id` (уточнить разведкой) |
| `crm_entity_stage_history` | Смарт-процессы (все типы) | `owner_id` + фильтр по `owner_type_id` |

## Пользовательские поля смарт-процессов

⚠️ Колонки `crm_dynamic_items_<typeId>` — портально-специфичные кодовые имена вида `uf_crm_NN_xxx`. Узнавать через `SELECT * ... LIMIT 1`. И часто такие поля приходят `VARCHAR`'ом независимо от типа в UI — перед арифметикой/датами кастовать (см. `references/pitfalls.md`).

## Разведка перед отчётом по смарт-процессу

По одному SELECT за сообщение:

```sql
-- 1. Список типов смарт-процессов на портале
SELECT * FROM bitrix24.crm_smart_proc;

-- 2. Структура элементов конкретного типа (напр., счетов)
SELECT * FROM bitrix24.crm_dynamic_items_31 LIMIT 1;

-- 3. Какие воронки у этого типа
SELECT DISTINCT category_id, category_name
FROM bitrix24.crm_entity_stage_history
WHERE owner_type_id = 31;

-- 4. Стадии в нужной воронке
SELECT DISTINCT stage_id, stage_name, stage_semantic_id
FROM bitrix24.crm_entity_stage_history
WHERE owner_type_id = 31 AND category_id = 1;
```

## Кейс: смарт-процесс как источник данных

Смарт-процесс можно использовать не только как объект отчёта, но и как **источник вспомогательных данных** — например, расходы на рекламу, заведённые вручную, когда сквозная аналитика недоступна. Готовый разбор — `examples/lead_cost_via_smart_process.md` и `examples/lead_cost_via_smart_process.sql`.
