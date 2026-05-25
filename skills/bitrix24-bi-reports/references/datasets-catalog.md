# Каталог датасетов и справочные таблицы полей

Часть скилла `bitrix24-bi-reports`. Открывать на шагах 2–3 (план и разведка): что за таблицы есть в BI-схеме, какие поля и как связывать.

> ⚠️ **Список таблиц BI Битрикс24 одинаков на всех порталах.** Отличается только наполнение таблиц с суффиксом `_uf` — там хранятся пользовательские (кастомные) поля, набор которых на каждом портале свой. Это значит: имена и состав основных таблиц можно считать стабильными по этому каталогу, без разведки `SHOW TABLES` на конкретном портале. Разведка через SQL Lab нужна для другого — см. `references/recon.md`.

---

## Каталог датасетов

### Задачи
- `task` — основные данные задач
- `task_uf` — пользовательские поля задач
- `task_elapsed_time` — записи трекинга времени
- `task_stages` — стадии задач (канбан)
- `task_efficiency` — эффективность
- `flow` — потоки задач
- `socialnetwork_group` — группы/проекты

**Связки:**
- `task.ID = task_elapsed_time.TASK_ID` — для подсчёта затраченного времени
- `task.GROUP_ID = socialnetwork_group.ID` — для названия группы/проекта
- `task.ID = task_uf.TASK_ID` — для пользовательских полей

### CRM — основные сущности
- `crm_deal` — сделки (текущее состояние)
- `crm_deal_uf` — пользовательские поля сделок
- `crm_deal_product_row` — товарные позиции сделок
- `crm_lead` — лиды (текущее состояние)
- `crm_lead_uf` — пользовательские поля лидов
- `crm_lead_product_row` — товарные позиции лидов
- `crm_contact` — контакты
- `crm_contact_uf` — пользовательские поля контактов
- `crm_company` — компании
- `crm_company_uf` — пользовательские поля компаний
- `crm_quote` — коммерческие предложения
- `crm_quote_uf` — пользовательские поля КП
- `crm_quote_product_row` — товарные позиции КП

### CRM — справочники и история
- `crm_stages` — справочник стадий (общий для лидов, сделок, смарт-процессов)
- `crm_deal_stage_history` — история смены стадий **сделок** (одна строка = одно нахождение в стадии)
- `crm_lead_status_history` — история смены стадий **лидов**
- `crm_entity_stage_history` — история смены стадий **смарт-процессов** (универсальная по всем типам, см. `references/smart-processes.md`)
- `crm_entity_relation` — связи между сущностями CRM (разведать перед использованием)
- `crm_activity` — дела (звонки, встречи, письма)
- `crm_activity_relation` — связи дел с сущностями
- `crm_last_communication` — последние коммуникации (разведать перед использованием)

### CRM — товары и склад
- `crm_product` — товары каталога
- `crm_product_property` — свойства товаров
- `crm_product_property_value` — значения свойств товаров
- `catalog_store` — склады
- `catalog_store_product` — остатки товаров по складам
- `catalog_store_document` — складские документы
- `catalog_store_document_item` — позиции складских документов

### CRM — смарт-процессы
- `crm_smart_proc` — справочник смарт-процессов портала (типы и их свойства)
- `crm_dynamic_items_<typeId>` — элементы смарт-процесса конкретного типа (одна таблица = один тип)
- `crm_dynamic_items_prod_<typeId>` — товарные позиции элементов смарт-процесса

Подробнее — см. `references/smart-processes.md`.

### CRM — AI-аналитика звонков
- `crm_ai_quality_assessment` — оценки качества звонков AI (разведать перед использованием)
- `crm_copilot_call_assessment` — оценки звонков от CoPilot (разведать перед использованием)

### Телефония
- `telephony_call` — звонки (REST-аналог: `voximplant.statistic.get`)

Подробнее — см. `references/telephony.md`.

### Заказы (интернет-магазин)
- `sale_document_saleorder` — заказы
- `sale_document_saleorder_item` — позиции заказов

Разведать перед использованием.

### Аналитика трафика (сквозная аналитика)
- `tracking_source` — справочник источников трафика
- `tracking_source_expenses` — расходы по источникам

Полные структуры — ниже, в разделе «Сквозная аналитика».

### Бизнес-процессы
- `bizproc_workflow_template` — шаблоны БП
- `bizproc_workflow_state` — состояния запущенных БП
- `bizproc_task` — задачи (заявки) бизнес-процессов

Разведать перед использованием.

### Пользователи и оргструктура
- `user` — сотрудники портала
- `org_structure` — подразделения
- `org_structure_relation` — связи в оргструктуре

Разведать перед использованием.

**Связки (CRM):**
- `crm_deal.id = crm_deal_stage_history.deal_id` — история по сделке
- `crm_lead.id = crm_lead_status_history.lead_id` — история по лиду (поле уточнить разведкой)
- `crm_stages.status_id = crm_deal.stage_id` + `crm_stages.entity_type_id = 2` + `crm_stages.category_id = crm_deal.category_id` — справочник к сделке (для `sort` и `semantics`)
- `crm_stages.status_id = crm_lead.status_id` + `crm_stages.entity_type_id = 1` — справочник к лиду (у лидов нет `category_id`)
- `crm_deal_product_row.OWNER_ID = crm_deal.id` — товары сделки (поле уточнить разведкой)
- `crm_<entity>_uf.<ENTITY>_ID = crm_<entity>.id` — пользовательские поля (точное имя FK уточнить разведкой по `SELECT *`)

⚠️ Связку `crm_stages.id = crm_deal.stage_id` НЕ использовать — `crm_deal.stage_id` хранит **код** стадии (`NEW`, `WON`, `UC_200GJB`), а не числовой ID. Связывать через `status_id`.

⚠️ `crm_deal.category_id` — `VARCHAR`, а `crm_stages.category_id` — `BIGINT`. Кастить в JOIN: `s.category_id = CAST(d.category_id AS BIGINT)`.

---

## Справочные таблицы полей

### `crm_deal` (стандартные поля)

| Поле | Тип | Назначение |
|---|---|---|
| `id` | BIGINT | ID сделки |
| `title` | VARCHAR | Название |
| `date_create` | TIMESTAMP | **Фактическая** дата создания (системная, при импорте = дата импорта) |
| `begindate` | TIMESTAMP | **Редактируемая** дата начала. Использовать для отчётов по импортированным данным |
| `closedate` | TIMESTAMP | Дата закрытия |
| `assigned_by_id` | BIGINT | ID ответственного |
| `assigned_by_name` | VARCHAR | ФИО ответственного |
| `created_by_id` | BIGINT | ID создателя |
| `category_id` | VARCHAR (!) | ID направления (0 — обычно "Продажи") |
| `category_name` | VARCHAR | Название направления |
| `stage_id` | VARCHAR | **Код** стадии (`NEW`, `WON`, `UC_XXX`), не числовой ID |
| `stage_name` | VARCHAR | Текстовое название стадии |
| `stage_semantic_id` | VARCHAR | Семантика: `S` — успех, `F` — провал/брак, иное (NULL/'P') — рабочая |
| `source_id` | VARCHAR | Код источника |
| `source_name` | VARCHAR | Текстовое название источника |
| `opportunity` | FLOAT | Сумма сделки |
| `currency_id` | VARCHAR | Валюта |
| `company_id`, `company_name` | BIGINT/VARCHAR | Компания |
| `contact_id`, `contact_name` | BIGINT/VARCHAR | Основной контакт |
| `closed` | VARCHAR | `Y`/`N` — закрыта ли |

### `crm_stages`

| Поле | Тип | Назначение |
|---|---|---|
| `id` | BIGINT | Внутренний ID записи (НЕ для JOIN с deal!) |
| `entity_type_id` | BIGINT | 1 — лид, 2 — сделка |
| `status_id` | VARCHAR | Код стадии — соответствует `crm_deal.stage_id` |
| `name` | VARCHAR | Название стадии |
| `category_id` | BIGINT | ID направления (для сделок) |
| `category_name` | VARCHAR | Название направления |
| `sort` | BIGINT | Порядок стадии (используется для накопительной воронки) |
| `semantics` | VARCHAR | `S` — успех, `F` — провал, иное — рабочая |

### `crm_deal_stage_history`

| Поле | Тип | Назначение |
|---|---|---|
| `id` | BIGINT | ID записи истории |
| `deal_id` | BIGINT | ID сделки |
| `stage_id` | VARCHAR | Код стадии (как в `crm_deal`) |
| `stage_name` | VARCHAR | Название стадии |
| `stage_semantic_id` | VARCHAR | Семантика стадии |
| `category_id` | BIGINT (!) | ID направления |
| `start_date` | DATE | Когда сделка вошла в стадию |
| `end_date` | DATE | Когда вышла |
| `assigned_by_id` | BIGINT | Ответственный на момент |

⚠️ В разных датасетах CRM `category_id` имеет **разный тип**: в `crm_deal` это `VARCHAR`, в `crm_stages` и `crm_deal_stage_history` — `BIGINT`. Всегда кастовать.

### `task_elapsed_time` (учёт времени)

⚠️ Состав полей в BI-схеме **отличается от REST-метода** `task.elapseditem.getlist`. Не ориентироваться на документацию REST — там другие имена.

| Поле | Тип | Назначение |
|---|---|---|
| `id` | BIGINT | ID записи |
| `task_id` | BIGINT | ID задачи |
| `user_id` | BIGINT | ID автора |
| `user_name` | VARCHAR | ФИО автора (готовое, JOIN на `user` не нужен) |
| `user` | VARCHAR | `[ID] ФИО` — комбинированное |
| `date_start` | TIMESTAMP | Дата начала работы — использовать для отчётов «когда выполнена работа» |
| `comment_text` | VARCHAR | Комментарий |
| `elapsed_time` | BIGINT | Длительность в **секундах** |

Чего в BI-схеме **нет** против REST: `created_date`, `date_stop`, `minutes`, `source`. Поле длительности в REST называется `seconds`, в BI — `elapsed_time`.

---

## CRM: Лиды

### `crm_lead` — стандартные поля

Одинаковы на всех порталах. Полный референс по группам:

| Группа | Поля |
|---|---|
| Идентификатор | `id` |
| Даты | `date_create`, `date_modify`, `date_closed`, `birthdate` |
| Создатель/исполнитель | `created_by_id`, `created_by`, `modify_by_id`, `modified_by`, `assigned_by_id`, `assigned_by_name`, `assigned_by`, `assigned_by_department` |
| Доступ | `opened` |
| Связки | `company_id`, `company_name`, `contact_id`, `contact_name`, `contact_ids` (ARRAY) |
| Статус | `status_id` (код), `status_name`, `status`, `status_description`, `status_semantic_id` (S/P/F), `status_semantic` |
| Сделка | `opportunity` (FLOAT), `currency_id`, `crm_product_id`, `crm_product_name`, `crm_product_count` |
| Источник CRM | `source_id` (формат `id|CODE`, напр. `1|OPENLINE` — **это код из справочника CRM, НЕ id из `tracking_source`!**), `source_name`, `source`, `source_description` |
| UTM | `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term` |
| ФИО / должность | `title`, `full_name`, `name`, `last_name`, `second_name`, `company_title`, `post` |
| Адрес | `address_1`, `address_2`, `address_city`, `address_postal_code`, `address_region`, `address_province`, `address_country`, `address_country_code` |
| Контакты (множ.) | `phone`, `web`, `email`, `im` |
| Служебное | `comments`, `originator_id`, `origin_id`, `honorific`, `is_return_customer` |

### Ключевые поля для отчётов (отличия от сделок)

| Поле | Тип | Назначение |
|---|---|---|
| `id` | BIGINT | ID лида (связка со звонками через `telephony_call.crm_entity_id` при `crm_entity_type = 'LEAD'`) |
| `date_create` | TIMESTAMP | Дата создания — основной фильтр для «новых заявок» |
| `date_modify` | TIMESTAMP | Дата изменения |
| `date_closed` | TIMESTAMP | Дата закрытия |
| `status_id` | VARCHAR | Код стадии (`NEW`, `IN_PROCESS`, `PROCESSED`, `JUNK`, `CONVERTED` или кастомные `UC_*`) |
| `status_semantic_id` | VARCHAR | `P` / `S` / `F` — в процессе / успех / провал |
| `assigned_by_id` | BIGINT | Ответственный (ID) |
| `source_id` | VARCHAR | Источник лида (формат `id|CODE`) |
| `phone` | VARCHAR | Телефоны (множественное, через разделитель) |
| `email` | VARCHAR | Email (множественное) |
| `opportunity` | FLOAT | Ожидаемая сумма |
| `utm_source`, `utm_medium`, `utm_campaign` | VARCHAR | UTM-метки |

⚠️ **У лидов нет `category_id`.** Воронок в обычном смысле у лидов не бывает. В JOIN со `crm_stages` использовать только `status_id` + `entity_type_id = 1`, без `category_id`.

История стадий лидов — в отдельной таблице `crm_lead_status_history` (не путать с `crm_deal_stage_history`).

---

## Сквозная аналитика

### `tracking_source` — справочник источников трафика

| Поле | Тип | Описание |
|---|---|---|
| `id` | BIGINT | ID источника |
| `name` | VARCHAR | Название источника |
| `utm_source_list` | ARRAY | Список UTM-меток `utm_source`, привязанных к этому источнику |

### `tracking_source_expenses` — расходы по источникам

Одна строка = расход за день по конкретному объявлению.

| Поле | Тип | Описание |
|---|---|---|
| `source_id` | BIGINT | ID источника (связь с `tracking_source.id`) |
| `expenses` | FLOAT | Расход за день |
| `currency` | VARCHAR | Валюта |
| `date` | DATE | Дата |
| `campaign_name`, `campaign_id` | VARCHAR | Рекламная кампания |
| `group_name`, `group_id` | VARCHAR | Рекламная группа |
| `ad_name`, `ad_id` | VARCHAR | Рекламное объявление |
| `clicks`, `impressions`, `actions` | BIGINT | Клики, показы, действия |
| `cpm`, `cpc` | FLOAT | Цена за тысячу показов / за клик |
| `utm_medium`, `utm_source`, `utm_campaign`, `utm_content` | VARCHAR | UTM-метки |

### Типовые связки

- `tracking_source.id = tracking_source_expenses.source_id` — расход к источнику.
- Связка с лидом — **только через UTM**: `crm_lead.utm_source ↔ tracking_source.utm_source_list` (через `UNNEST` массива).

⚠️ **При чтении из `tracking_source_expenses` запрос может падать** с ошибкой типа `[source id: N][yandex account error] Can not find user name for yandex account.` — это значит, что у одного из источников протухла интеграция с Я.Директом, и Trino падает на всём запросе целиком. Чинить — в интерфейсе Б24 (CRM → Аналитика → Сквозная аналитика → Источники → проблемный источник → переподключить аккаунт).

### Связка лида со сквозной аналитикой

Отдельного поля типа `tracking_source_id` на лиде **нет**. `crm_lead.source_id` хранит код CRM-источника из справочника (формат `id|CODE`, напр. `1|OPENLINE`), а **не** id из `tracking_source`. Это два разных справочника.

Стыковка лида с расходами идёт через UTM:

```
crm_lead.utm_source ↔ tracking_source.utm_source_list (ARRAY)
```

Используется через `UNNEST(utm_source_list)` или `CONTAINS(utm_source_list, lead.utm_source)`.

**Лиды без `utm_source`** (звонки, ручной ввод, прямые заходы с `utm_source='direct'`) в отчёт по стоимости трафика **не попадают** — на них нет данных в `tracking_source_expenses`.

**Альтернатива:** для теста или для случая, когда сквозная аналитика не работает (например, протухла интеграция Я.Директа) — связку «лид ↔ расход» можно делать **через CRM-источник напрямую**, заводя расходы в самостоятельном смарт-процессе с привязкой к тому же справочнику источников, что используется в лидах (поле `source_id`). Готовый кейс — `examples/lead_cost_via_smart_process.md` и `examples/lead_cost_via_smart_process.sql`.
