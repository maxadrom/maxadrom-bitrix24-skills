---
name: bitrix24-bi-reports
description: |
  Разработка отчётов и дашбордов в BI-конструкторе Битрикс24 (Trino + Apache Superset 6.0). Используй этот скилл, когда пользователь просит сделать отчёт, дашборд, чарт, таблицу или график в BI-конструкторе, BI Битрикса, Superset, Trino, SQL Lab. Покрывает: проектирование датасетов через SQL Lab, типовые SQL-паттерны для задач/CRM/телефонии/лидов/смарт-процессов, форматирование длительности и дат, кликабельные ссылки, фильтры дашборда, раскраска ячеек, накопительные воронки, отчёты по дозвону, типичные грабли. Триггеры: «BI конструктор», «BI Битрикса», «Superset», «отчёт в Битриксе», «дашборд в B24», «SQL Lab», «Trino», «чарт по задачам», «отчёт по сделкам», «воронка продаж», «конверсия по этапам», «отчёт по звонкам», «телефония», «дозвон», «отчёт по лидам», «смарт-процесс», «счета».
---

# Разработка отчётов в BI-конструкторе Битрикс24

## ⚠️ Правила работы с пользователем

### 1. Один вопрос за раз

**Задавать вопросы строго ПО ОДНОМУ за раз.** Не собирать несколько вопросов или запросов на разведку в одно сообщение. Дождаться ответа на текущий вопрос перед тем, как задавать следующий.

Это касается и уточнений по требованиям, и запросов на разведку структуры таблиц через SQL Lab.

- **Плохо:** «Выполни вот эти три SELECT и пришли результаты».
- **Хорошо:** «Выполни этот SELECT, пришли результат» → ответ → следующий вопрос.

### 2. Разведка структуры — через пользователя в SQL Lab

Если не знаешь точную структуру таблицы, имена полей, формат данных или связки на конкретном портале — **не угадывать и не подменять документацией**. Любая разведка реальных данных идёт через пользователя:

1. Дать пользователю готовый SELECT для SQL Lab (один за раз, см. правило 1).
2. Дождаться, пока он выполнит и пришлёт результат.
3. На основе результата сформулировать следующий шаг.

**MCP-коннекторы к порталу** (Bitrix24 REST, `b24_call` и т.п.) использовать **только в одном случае**: если адрес портала, для которого идёт разработка, совпадает с адресом портала, подключённого через MCP. Тогда это не вторжение в чужие данные, а легитимный доступ к тем же данным другим путём — можно разведывать самостоятельно. Во всех остальных случаях — только SELECT через пользователя.

Это правило защищает приватность данных и не даёт скиллу путаться между документацией Битрикса (она бывает неточной/устаревшей для BI-схемы) и реальной структурой конкретного портала.

- **Плохо:** «По документации REST поле называется так-то, использую» (документация REST ≠ структура BI-датасета).
- **Хорошо:** «Не знаю точное имя поля FK. Выполни в SQL Lab: `SELECT * FROM bitrix24.<таблица> LIMIT 1` — пришли список колонок».

---

## Сценарий работы над отчётом

Это карта процесса. Не проскакивать вперёд по шагам — между ними стоят ворота согласования с пользователем.

### Шаг 1. Получить ТЗ

Опросить пользователя — по одному вопросу за сообщение (см. правило 1):

1. **Адрес портала** — нужен, чтобы понять, можно ли разведывать через MCP (см. правило 2: MCP можно, только если адрес портала разработки = адресу MCP-подключения).
2. **Что собрать и как показать** — какие данные нужны, в каком виде (таблица / график / число / воронка), какие разрезы (по сотрудникам, по клиентам, по месяцам и т.п.).
3. **Фильтры** — какие фильтры нужны на дашборде. ⚠️ Сразу предупредить пользователя: фильтр по дате в Superset стандартно цепляется только к **одному** полю-таймлайну на чарт. Если в отчёте несколько дат с разным смыслом (создана / закрыта / выполнена работа) — решить на старте, какая дата основная.

### Шаг 2. Обозначить план

Накидать верхнеуровневый план **на языке пользователя**, без технического жаргона. Не «сделаем JOIN `task_elapsed_time` на `task`», а «соберём таблицу: кто, по какой задаче, сколько времени, какой клиент».

Зачем это нужно: первая версия плана — **точка синхронизации понимания**. На ней видно, правильно ли Claude понял задачу, и пользователь может затормозить: «стоп, это планируется не так».

⚠️ Если данных о портале мало и план будет наполовину выдуманным — **не сочинять план**. Честно сказать пользователю, что нужна предварительная разведка, и перейти к шагу 3. План обозначить после.

После плана — дождаться согласия пользователя.

### Шаг 3. Разведка

Посмотреть реальную структуру таблиц и данных. Технические детали — что именно смотреть и какими запросами — в разделе «Разведка портала» ниже. Пошагово, по одному SELECT за сообщение.

### Шаг 4. Уточнить план при необходимости

Разведка — предохранитель на коллизии: может вскрыться что угодно (нет поля, другой формат, грязные данные, не та связка). Если вскрылось — вернуться к плану, скорректировать затронутый кусок, пересогласовать с пользователем.

### Шаг 5. Сборка

Датасет → чарты → дашборд. Пошагово. Технические детали — в разделах «Стандартный workflow разработки отчёта», «Типовые SQL-паттерны», «Чарты», «Дашборды».

---

## Среда

- **БД-движок:** Trino (диалект SQL — Trino/Presto, не MySQL!)
- **UI:** Apache Superset 6.0 (русифицированный интерфейс)
- **Схема:** `bitrix24`
- **Точка входа для SQL:** SQL Lab

⚠️ **Ключевое:** функции — Trino-style. `MOD(a, b)` (а не `a % b`), `CONCAT(...)`, `CAST(x AS VARCHAR)`, `LPAD(str, len, pad)`, `COALESCE`, `DATE_FORMAT`, `DATE_TRUNC`. Конкатенация строк через `CONCAT()`, не через `||` и не через `+`.

⚠️ **Префикс схемы:** при ошибке `Schema must be specified when session schema is not set` — добавить `bitrix24.` перед именем таблицы: `SELECT * FROM bitrix24.crm_deal`.

⚠️ **UI Superset проверять по документации.** Версии Superset (5.x / 6.0 / форк Битрикс24) различаются в интерфейсе и наборе настроек, особенно по фильтрам. При сомнении в опции — сверяться с официальной документацией Apache Superset, DeepWiki по `apache/superset` (особенно по native filters), issues и discussions репозитория. **Не выдумывать опции «по аналогии с другими BI»** — в Superset часто работает иначе (характерный пример: ожидаемого per-chart маппинга колонок в фильтре в Superset нет в принципе, см. раздел «Фильтры дашборда на несколько датасетов»).

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
- `crm_entity_stage_history` — история смены стадий **смарт-процессов** (универсальная по всем типам, см. раздел «Смарт-процессы»)
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

Подробнее — см. раздел «Смарт-процессы».

### CRM — AI-аналитика звонков
- `crm_ai_quality_assessment` — оценки качества звонков AI (разведать перед использованием)
- `crm_copilot_call_assessment` — оценки звонков от CoPilot (разведать перед использованием)

### Телефония
- `telephony_call` — звонки (REST-аналог: `voximplant.statistic.get`)

Подробнее — см. раздел «Телефония и звонки».

### Заказы (интернет-магазин)
- `sale_document_saleorder` — заказы
- `sale_document_saleorder_item` — позиции заказов

Разведать перед использованием.

### Аналитика трафика
- `tracking_source` — источники трафика
- `tracking_source_expenses` — расходы по источникам

Разведать перед использованием.

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

## Разведка портала

Технические детали шага 3 «Сценария работы над отчётом».

**Перед написанием любого отчёта** делай `SELECT *` по одной записи, чтобы увидеть **реальный набор полей конкретного портала**. На разных порталах в одних и тех же датасетах могут быть нестандартные поля сверх документации, а имена и форматы полей в BI-схеме отличаются от REST API.

```sql
SELECT * FROM bitrix24.crm_deal LIMIT 1;
SELECT * FROM bitrix24.task WHERE ID = <известный_id>;
```

Разведка идёт пошагово — по одному SELECT за сообщение (правило 1). Только после того, как реальная структура подтверждена, писать финальный SQL.

Доменные мини-чеклисты разведки — в соответствующих разделах: «Телефония и звонки», «Смарт-процессы».

---

## Стандартный workflow разработки отчёта

Технические детали шага 5 «Сценария работы над отчётом» (ТЗ, план и разведка к этому моменту уже сделаны).

1. **Написать SQL для виртуального датасета** в SQL Lab → кнопка «Сохранить и исследовать» (сохраняет датасет и сразу открывает создание первого чарта).
2. **Создать чарты** один за другим, все на общем датасете. Однотипные — через «Сохранить как» (см. раздел «Чарты»).
3. **Создать дашборд**, разложить чарты.
4. **Настроить общие фильтры** на уровне дашборда. Если чарты на разных датасетах — следить за унификацией имён колонок (см. раздел «Фильтры дашборда на несколько датасетов»).
5. **Финальная проверка** — по чек-листу в конце скилла.

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

## Типовые SQL-паттерны

### Кликабельная ссылка на задачу

```sql
CONCAT(
    '<a href="', '{{portal_url()}}',
    '/workgroups/group/<GROUP_ID>/tasks/task/view/',
    CAST(t.ID AS VARCHAR),
    '/" target="_blank">',
    t.TITLE,
    '</a>'
) AS task_link
```

`{{portal_url()}}` — Jinja-макрос Superset, подставит домен портала.

### Кликабельная ссылка на сделку

```sql
CONCAT(
    '<a href="', '{{portal_url()}}',
    '/crm/deal/details/',
    CAST(d.id AS VARCHAR),
    '/" target="_blank">',
    d.title,
    '</a>'
) AS deal_link
```

### Кликабельная ссылка на контакт (с ФИО)

```sql
CONCAT(
    '<a href="', '{{portal_url()}}',
    '/crm/contact/details/',
    CAST(c.ID AS VARCHAR),
    '/" target="_blank">',
    TRIM(CONCAT(
        COALESCE(c.LAST_NAME, ''), ' ',
        COALESCE(c.NAME, ''), ' ',
        COALESCE(c.SECOND_NAME, '')
    )),
    '</a>'
) AS contact_link
```

### Сумма затраченного времени по задаче

`task_elapsed_time.ELAPSED_TIME` хранится в **секундах**.

```sql
COALESCE(SUM(et.ELAPSED_TIME), 0)                    AS elapsed_seconds,
ROUND(COALESCE(SUM(et.ELAPSED_TIME), 0) / 3600.0, 2) AS elapsed_hours
```

### Длительность как строка `Hh MMm`

```sql
CONCAT(
    CAST(COALESCE(SUM(et.ELAPSED_TIME), 0) / 3600 AS VARCHAR),
    'h ',
    LPAD(CAST(MOD(COALESCE(SUM(et.ELAPSED_TIME), 0) / 60, 60) AS VARCHAR), 2, '0'),
    'm'
) AS elapsed_human
```

⚠️ Минус строки: не суммируется и не сортируется в чартах. Для агрегации — миллисекунды + формат «Продолжительность в мс».

### Длительность округлённая до минут (без секунд в выводе)

```sql
(COALESCE(SUM(et.ELAPSED_TIME), 0) / 60) * 60 * 1000 AS elapsed_ms_rounded
```

В метрике чарта подавать `SUM(elapsed_ms_rounded)`, формат «Продолжительность в мс» → `1d 16h 50m`.

### Год-месяц (для группировки по месяцам)

```sql
DATE_FORMAT(d.begindate, '%Y-%m') AS year_month
```

⚠️ Поле строковое (`'2026-04'`). Чтобы отсортировать хронологически в чарте — в «Сортировке запроса» добавить колонку `year_month` с агрегатной функцией **MIN** + направление по возрастанию. Лексикографическая сортировка `YYYY-MM` совпадает с хронологической.

### Работа с `task.tags`

`task.tags` в BI хранится одной строкой VARCHAR. На разведанных порталах формат — `"Тег1, Тег2, Тег3"` (разделитель — запятая + пробел). Формат разделителя проверять разведкой на каждом портале:

```sql
SELECT ID, TITLE, TAGS
FROM bitrix24.task
WHERE TAGS IS NOT NULL
  AND TAGS <> ''
  AND LENGTH(TAGS) > 20    -- чтобы поймать задачу с несколькими тегами
ORDER BY ID DESC
LIMIT 5;
```

Когда у задачи в группе всегда один тег (одна задача = одна компания/категория) — `tags` можно использовать как есть, одной колонкой, без `UNNEST`. Это частый случай для отчётов «время по клиентам», где клиент = тег.

### Длительность: миллисекунды в SQL, форматирование в UI

⚠️ **Главная ловушка форматирования длительности.** Пресет Superset «Продолжительность в мс» применяется ко **всему**, что попало в метрику, без разбора смысла. Если подать в метрику с этим форматом число часов (`elapsed_hours`) — Superset воспримет его как миллисекунды и покажет миллиарды `dhms`.

Правило: длительность для агрегируемых чартов кладётся в датасет именно как **миллисекунды, округлённые до минут**:

```sql
(elapsed_time / 60) * 60 * 1000 AS elapsed_ms
```

В чарте: метрика `SUM(elapsed_ms)` → вкладка «Кастомизация» → «Форматирование» → пресет «Продолжительность в мс» → выводит `1d 16h 50m` без секунд.

Если для круговых/числовых чартов нужны именно часы — держать их **отдельной колонкой** `elapsed_hours` (`ROUND(elapsed_time / 3600.0, 2)`) и не применять к ней формат «мс». В датасете живут обе колонки, каждая под свой тип чарта.

### Шаблон датасета «учёт времени по задачам и клиентам»

Плоский датасет: одна строка = одна запись учёта времени, тег задачи прикладывается как есть (рассчитано на «один тег = одна компания»).

```sql
SELECT
    et.id                                 AS elapsed_id,
    et.task_id,
    CONCAT(
        '<a href="', '{{portal_url()}}',
        '/workgroups/group/<GROUP_ID>/tasks/task/view/',
        CAST(et.task_id AS VARCHAR),
        '/" target="_blank">',
        COALESCE(t.title, CONCAT('Задача #', CAST(et.task_id AS VARCHAR))),
        '</a>'
    )                                     AS task_link,
    et.user_name                          AS responsible_name,
    et.date_start,
    et.elapsed_time                       AS elapsed_seconds,
    (et.elapsed_time / 60) * 60 * 1000    AS elapsed_ms,
    ROUND(et.elapsed_time / 3600.0, 2)    AS elapsed_hours,
    et.comment_text,
    NULLIF(TRIM(t.tags), '')              AS tags
FROM bitrix24.task_elapsed_time et
LEFT JOIN bitrix24.task t ON t.id = et.task_id
WHERE t.group_id = <GROUP_ID>
```

Имена колонок (`responsible_name`, `tags`) выбраны под совпадение с другими типовыми датасетами портала — это нужно для общих фильтров дашборда (см. раздел «Фильтры дашборда на несколько датасетов»).

Чарты на этот датасет:
- Таблица «По компаниям» — измерение `tags`, метрика `SUM(elapsed_ms)`.
- Таблица «По сотрудникам» — измерение `responsible_name`, метрика та же.
- Круговая «Распределение по клиентам» — измерение `tags`, метрика `SUM(elapsed_hours)`.

Time column во всех чартах: `date_start`.

---

## Накопительная воронка продаж

Накопительная воронка = «сделка достигла этапа N, если хоть раз была на этапе с `sort >= sort(N)`». Решает проблему перескоков (сделка прыгнула с «Новой» сразу в «Квалифицирован» — все промежуточные засчитываются).

**Источник данных** — `crm_deal_stage_history`, а не текущее `stage_id` из `crm_deal`. Иначе сделки в БРАКе теряют историю прохождения.

### Шаблон датасета воронки

```sql
WITH deal_max_sort AS (
    -- максимальный sort среди РАБОЧИХ стадий, на которых побывала сделка
    SELECT
        h.deal_id,
        MAX(s.sort) AS max_sort_reached
    FROM bitrix24.crm_deal_stage_history h
    JOIN bitrix24.crm_stages s
        ON s.status_id = h.stage_id
       AND s.entity_type_id = 2
       AND s.category_id = h.category_id
    WHERE h.category_id = <CATEGORY_ID>
      AND s.semantics IS DISTINCT FROM 'F'   -- браковые стадии исключаем из max_sort
    GROUP BY h.deal_id
),
deal_was_lose AS (
    -- сделки, которые хоть раз были в браке
    SELECT DISTINCT h.deal_id
    FROM bitrix24.crm_deal_stage_history h
    JOIN bitrix24.crm_stages s
        ON s.status_id = h.stage_id
       AND s.entity_type_id = 2
       AND s.category_id = h.category_id
    WHERE h.category_id = <CATEGORY_ID>
      AND s.semantics = 'F'
)
SELECT
    d.id                                       AS deal_id,
    d.title,
    d.assigned_by_name                         AS responsible,
    d.source_name                              AS source,
    d.begindate,
    DATE_FORMAT(d.begindate, '%Y-%m')          AS year_month,
    d.stage_name                               AS current_stage,
    d.stage_semantic_id                        AS semantic,
    COALESCE(ms.max_sort_reached, 0)           AS max_sort_reached,

    -- Флаги достижения этапов (sort-значения берём из crm_stages)
    CASE WHEN COALESCE(ms.max_sort_reached, 0) >= 10  THEN 1 ELSE 0 END AS reached_stage_1,
    CASE WHEN COALESCE(ms.max_sort_reached, 0) >= 20  THEN 1 ELSE 0 END AS reached_stage_2,
    -- ... и так по всем рабочим стадиям
    CASE WHEN d.stage_semantic_id = 'S' THEN 1 ELSE 0 END AS reached_won,
    CASE WHEN dl.deal_id IS NOT NULL THEN 1 ELSE 0 END    AS reached_lose,

    1 AS total_deal
FROM bitrix24.crm_deal d
LEFT JOIN deal_max_sort  ms ON ms.deal_id = d.id
LEFT JOIN deal_was_lose  dl ON dl.deal_id = d.id
WHERE d.category_id = '<CATEGORY_ID>'   -- VARCHAR в строке!
```

### Конверсия в чарте (метрика через SQL)

В таблице добавить новую метрику через **«+ Добавить метрику» → «Через SQL»** или «Свободная форма»:

```sql
CAST(SUM(reached_won) AS DOUBLE) / NULLIF(SUM(reached_new), 0)
```

Метку — «Конверсия в успех», формат — «Процент с 2 знаками».

---

## Телефония и звонки

Датасет `telephony_call` соответствует REST-методу `voximplant.statistic.get`. Одна строка = один звонок.

### Ключевые поля

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

⚠️ **Длительность разговора — это `call_duration`, НЕ `record_duration`.** Несмотря на название «Продолжительность разговора в секундах» в схеме, `record_duration` фактически содержит длительность файла записи и часто пустое/мусорное. Перед любым отчётом по успешности звонков сверять:

```sql
SELECT
    SUM(CASE WHEN call_duration >= 60 THEN 1 ELSE 0 END)   AS call_ge_60,
    SUM(CASE WHEN record_duration >= 60 THEN 1 ELSE 0 END) AS rec_ge_60,
    MAX(call_duration) AS max_call,
    MAX(record_duration) AS max_rec
FROM bitrix24.telephony_call
WHERE call_type = '1';
```

Если `max_call` десятки/сотни секунд, а `max_rec` — единицы или NULL → использовать `call_duration`.

### Связки

- `telephony_call.crm_entity_id = crm_lead.id` при `crm_entity_type = 'LEAD'`
- `telephony_call.crm_entity_id = crm_deal.id` при `crm_entity_type = 'DEAL'`
- `telephony_call.crm_entity_id = crm_contact.id` при `crm_entity_type = 'CONTACT'`
- `telephony_call.crm_entity_id = crm_company.id` при `crm_entity_type = 'COMPANY'`

### Разведка перед телефонным отчётом

Обязательный мини-чек-лист на новом портале:

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

### Что считается «дозвоном» — варианты

- `call_duration >= 60` — содержательный разговор (фильтрует приветствия и сбросы) ← **по умолчанию**
- `call_duration > 0` — любой состоявшийся разговор
- `call_status_code_id = '200'` — успех по коду АТС

### SQL-паттерн: «с какой попытки дозвонились» (сделки, фильтр по воронке)

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

### SQL-паттерн: «с какой попытки дозвонились» (лиды)

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

### SQL-паттерн: качество звонков по номерам АТС

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

---

## Лиды

Основные поля `crm_lead` (отличия от сделок):

| Поле | Тип | Назначение |
|---|---|---|
| `id` | BIGINT | ID лида (связка со звонками через `telephony_call.crm_entity_id` при `crm_entity_type = 'LEAD'`) |
| `date_create` | TIMESTAMP | Дата создания — основной фильтр для «новых заявок» |
| `date_modify` | TIMESTAMP | Дата изменения |
| `date_closed` | TIMESTAMP | Дата закрытия |
| `status_id` | VARCHAR | Код стадии (`NEW`, `IN_PROCESS`, `PROCESSED`, `JUNK`, `CONVERTED` или кастомные `UC_*`) |
| `status_semantic_id` | VARCHAR | `P` / `S` / `F` — в процессе / успех / провал |
| `assigned_by_id` | BIGINT | Ответственный (ID) |
| `source_id` | VARCHAR | Источник лида |
| `phone` | VARCHAR | Телефоны (множественное, через разделитель) |
| `email` | VARCHAR | Email (множественное) |
| `opportunity` | FLOAT | Ожидаемая сумма |
| `utm_source`, `utm_medium`, `utm_campaign` | VARCHAR | UTM-метки |

⚠️ **У лидов нет `category_id`.** Воронок в обычном смысле у лидов не бывает. В JOIN со `crm_stages` использовать только `status_id` + `entity_type_id = 1`, без `category_id`.

История стадий лидов — в отдельной таблице `crm_lead_status_history` (не путать с `crm_deal_stage_history`).

---

## Смарт-процессы

В Битрикс24 смарт-процессы (СП) — это пользовательские CRM-сущности (счета, проекты, заявки и т.п.) с собственными воронками и стадиями. В BI-конструкторе они хранятся в **отдельных таблицах для каждого типа**.

### Структура

- `crm_smart_proc` — справочник типов смарт-процессов портала
- `crm_dynamic_items_<typeId>` — элементы смарт-процесса конкретного типа (одна таблица = один тип)
- `crm_dynamic_items_prod_<typeId>` — товарные позиции элементов смарт-процесса
- `crm_entity_stage_history` — универсальная история стадий по **всем** смарт-процессам портала

### Зарезервированный ID

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

### История стадий смарт-процессов: `crm_entity_stage_history`

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

### Различия трёх таблиц истории

| Таблица | Для какой сущности | FK на основную таблицу |
|---|---|---|
| `crm_deal_stage_history` | Сделки | `deal_id` |
| `crm_lead_status_history` | Лиды | `lead_id` (уточнить разведкой) |
| `crm_entity_stage_history` | Смарт-процессы (все типы) | `owner_id` + фильтр по `owner_type_id` |

### Разведка перед отчётом по смарт-процессу

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

---

## Раскраска ячеек таблицы

### Что НЕ работает

- **Штатное «Условное форматирование»** в Superset — только для **числовых** колонок. Для строковых столбцов выбор колонки пуст.
- **CSS `:contains()`** — это селектор jQuery, в чистом CSS его нет. Дашборд выдаст ошибку `RPAREN`.
- **`label_colors` в JSON metadata дашборда** — красит **категориальные чарты** (bar/pie/line), но **не** ячейки таблицы.
- **Раскрасить всю строку штатным способом нельзя.** Можно только через `:has()` + HTML-маркер в ячейке (хрупко).

### Что работает — раскраска отдельных ячеек через SQL

Оборачиваем значение в `<div style="background-color:...">` через `CONCAT` + `CASE`. Цвет вычисляется в SQL по любому условию.

#### Бейдж стадии по семантике

```sql
CONCAT(
    '<div style="display:inline-block; padding:4px 10px; border-radius:12px; font-weight:600; ',
    CASE
        WHEN d.stage_semantic_id = 'S' THEN 'background-color:#E6F4EA; color:#1E7E34;'  -- зелёный
        WHEN d.stage_semantic_id = 'F' THEN 'background-color:#FDECEA; color:#B71C1C;'  -- красный
        ELSE                                'background-color:#E3F2FD; color:#0D47A1;'  -- голубой
    END,
    '">',
    d.stage_name,
    '</div>'
) AS current_stage
```

#### Бейдж по числовому условию

```sql
CONCAT(
    '<div style="padding:4px 8px; border-radius:8px; ',
    CASE
        WHEN amount >= 100000 THEN 'background-color:#C8E6C9;'
        WHEN amount >= 50000  THEN 'background-color:#FFF9C4;'
        ELSE                       'background-color:#FFCDD2;'
    END,
    '">',
    CAST(amount AS VARCHAR),
    '</div>'
) AS amount_colored
```

⚠️ Для рендеринга HTML в таблице чарта тип чарта должен быть **«Таблица»**. В сводных таблицах HTML может не рендериться.

---

## Статусы и значения полей

### `task.STATUS` (как ВЫГЛЯДИТ в датасете BI, не в API!)

В BI-конструкторе статусы приходят **строками на русском**:

- `'Ждёт выполнения'`
- `'Выполняется'`
- `'Ожидает контроля'`
- `'Завершена'`
- `'Отложена'`

### `task.TAGS`

Приходит **одной строкой**. Формат разделителей зависит от портала, проверять через `SELECT *`.

### `crm_deal.stage_semantic_id`

- `S` — успех (терминальная стадия)
- `F` — провал/брак (терминальная)
- `NULL`, `'P'` или прочее — рабочая стадия

---

## Форматирование в Superset

### Длительность

В **Меры → метрика → Форматирование → Формат даты/времени** есть пресет **«Продолжительность в мс»** (использует `pretty-ms`). Подаём в метрику число в **миллисекундах**.

Особенности:
- Автоматически добавляет дни (`1d 16h 50m 23s`) — отключить нельзя через формат, только обрезать в SQL (округлить до минут, чтобы убрать секунды).
- Локализация на русский невозможна — всегда `d/h/m/s`. Если нужен русский — формировать строкой в SQL через `CONCAT` + `LPAD`.
- Альтернативы D3-формата: `,d` (целое), `.1f` (одна цифра после точки), `,.2f` (две).

### Даты

Кликнуть по полю-измерению типа datetime → **«Формат даты/времени»** → вписать паттерн:

- `%d.%m.%Y` → `28.04.2026`
- `%d.%m.%Y %H:%M` → `28.04.2026 14:30`
- `%Y-%m-%d` → `2026-04-28` (ISO)

### Сортировка строкового year_month

В разделе **«Сортировка запроса»** в настройках чарта:
- Колонка: `year_month`
- Агрегатная функция: **MIN**
- Направление: по возрастанию

Лексикографическая MIN от `'2026-04'`/`'2026-05'` совпадает с хронологической.

### Имена колонок

Переименовываются прямо в чарте — кликнуть по плашке метрики/измерения, изменить «Метка». На сам датасет это не влияет.

---

## Чарты

### «Столбчатая диаграмма» в Superset

Это и есть Bar Chart. **Ось X = Измерения**, **Ось Y = Метрики**.

### Таблица с барами в ячейках

Если нужны бары встроенные в строки (как «top-N»):
- Тип чарта: **«Таблица»**
- Режим запроса: **`Aggregate`**
- В разделе **«Настроить»** включить **«Наложить гистограммы на ячейки»**.

### Итоговая строка в таблице

**«Настроить» → «Показать итоги»**. Работает только в режиме `Aggregate`.

### Режимы запроса в таблице

- `Aggregate` — группировка с `GROUP BY` по измерениям. Метрики агрегируются. Итоги работают.
- `Raw Records` — выводит сырые строки датасета без агрегации.

Для отчётов «список сделок» правильный выбор — `Raw Records`. Для «воронка по сотрудникам» — `Aggregate`.

### От SQL к первому чарту: «Сохранить и исследовать»

После того как SQL прогнан в SQL Lab, кнопка **«Сохранить и исследовать»** (не просто «Сохранить») за один шаг: сохраняет SQL как виртуальный датасет **и** сразу открывает экран создания первого чарта на его основе. Это стандартный путь от «SQL готов» к «первому чарту».

### Дублирование чарта

В существующем чарте: **«…» (меню вверху справа) → «Сохранить как»** → новое имя. Открывается копия с теми же настройками — меняешь измерение/метрику и сохраняешь. Удобно для серии однотипных чартов с разными разрезами (по компаниям, по сотрудникам, по источникам и т.п.) на одном датасете.

---

## Дашборды

### Создание

**Дашборды → + Дашборд** → перетащить чарты из боковой панели.

### Вкладки

Можно добавлять вкладки внутри дашборда — удобно группировать чарты. Фильтры дашборда **общие для всех вкладок**.

### Фильтры дашборда

Открывается через панель «Фильтры» → «Добавить/изменить фильтры».

**Типичные типы фильтров:**

- **«Временной интервал» (Time range)** — для диапазона дат. Применяется к time-колонке чарта. По умолчанию можно поставить «Текущий месяц», «Последние 7 дней» и т.п.
- **«Значение» (Value)** — для категориальных фильтров (ответственный, статус, тег). Поддерживает множественный выбор.
- **«Числовой диапазон»** — для сумм, количеств.

**Область применения** — обычно «Все графики». Можно ограничить конкретными чартами.

⚠️ Фильтр «Временной интервал» применяется к time-колонке чарта. Если в чарте указано несколько datetime-полей, возьмётся то, что помечено как основное.

---

## Фильтры дашборда на несколько датасетов

Неочевидная механика Superset 6, на которой легко споткнуться, ожидая поведения «как в других BI».

### Как фильтр на самом деле находит чарты

Фильтр на дашборде в **«Настройках»** жёстко привязан к одной колонке одного датасета. Но в **«Области применения»** он может применяться к чартам из **других** датасетов — Superset на лету сопоставляет колонки **по имени**.

То есть фильтр «Ответственный», созданный на колонке `responsible_name` датасета A, при отметке чарта из датасета B попробует найти в B колонку с тем же именем `responsible_name`. Найдёт — применит фильтр. Не найдёт — чарт просто не отфильтруется, **без ошибки, тихо**.

⚠️ Per-chart выбора колонки в UI **нет**. По аналогии с другими BI его часто ищут — в Superset этого нет в принципе. Сопоставление только по совпадению имени.

### Следствие: унификация имён колонок

Чтобы один фильтр дашборда покрывал чарты из разных датасетов — **колонки в этих датасетах должны называться одинаково**.

Практика: при создании нового датасета на дашборд, где уже есть фильтры, посмотреть, как названы ключевые колонки в существующих датасетах, и в SQL нового датасета сделать `AS <то же имя>`.

Типовые «общие» имена для портала:
- `responsible_name` — исполнитель / ответственный / автор работы
- `tags` — теги задачи (когда один тег = одна категория/компания)
- `date_start`, `created_date`, `closed_date` — даты-таймлайны

### ⚠️ Не объединять колонки с разным смыслом

Если две колонки называются одинаково, но означают **разное** (в датасете A `date_start` = «когда выполнена работа», в датасете B `date_start` = «когда создана задача») — не сводить их под один фильтр через переименование. Фильтр применится тихо и даст бессмысленный результат. Лучше держать два фильтра с разными именами колонок.

### «Область применения» в редакторе фильтра

Вкладка **«Область применения»** показывает дерево всех чартов дашборда. Можно отметить чарты на **любом** датасете, не только на том, где создан фильтр. Сопоставление колонок — автоматическое по имени (см. выше). Per-chart настройки колонки в этом дереве нет.

---

## Грабли и решения

| Симптом | Причина | Решение |
|---|---|---|
| `Schema must be specified when session schema is not set` | Нет схемы по умолчанию | Префикс `bitrix24.` перед именем таблицы |
| `Cannot apply operator: bigint = varchar` | Типы не совпадают в JOIN | `CAST(x AS VARCHAR)` или `CAST(y AS BIGINT)` |
| Markdown-ссылка `[текст](url)` показывается как текст | По умолчанию рендерится как plain text | Использовать HTML `<a href="...">` |
| `'a' \|\| 'b'` или `'a' + 'b'` в SQL → ошибка | Trino не поддерживает | `CONCAT('a', 'b')` |
| `a % b` → ошибка | Trino требует функцию | `MOD(a, b)` |
| Длительность показывает `1d 16h 50m 23s`, нужно без секунд | `pretty-ms` всегда показывает все юниты | Округлить в SQL до минут: `(seconds / 60) * 60 * 1000` |
| `H:MM` (русский «9 ч. 03 мин») | D3-format не локализуется | Делать строкой в SQL через `CONCAT` + `LPAD` |
| Метрика-строка не агрегируется | Bar Chart требует число | Для агрегации использовать миллисекунды/часы как число |
| Итоги в таблице не показываются | `Raw Records` или опция выключена | Режим `Aggregate` + «Показать итоги» |
| Фильтр временного интервала «не цепляется» | В чарте не указана time-колонка | В настройках чарта явно выбрать time-колонку |
| `year_month` сортируется неправильно (`2026-04` после `2026-12`) | Лексикографическая сортировка по умолчанию ОК для `YYYY-MM`, но Superset может игнорировать | Добавить в «Сортировку запроса» с агрегатом MIN, направление — по возрастанию |
| Условное форматирование не показывает строковую колонку | Штатно работает только для чисел | Раскрасить через CONCAT + HTML `<div style="background-color:...">` в SQL |
| CSS-селектор `:contains()` выдаёт `RPAREN` | Это jQuery, не CSS | Использовать `:has()` + HTML-маркер либо красить ячейки в SQL |
| `label_colors` в дашборде не красит таблицу | Применяется только к категориальным чартам | Красить ячейки через SQL+HTML |
| В импортированных сделках `date_create` врёт (= дата импорта) | Системное поле, при импорте перезаписывается | Использовать `begindate` — редактируемое поле, в импорте можно проставить реальную дату |
| `crm_deal.stage_id` не джойнится по `crm_stages.id` | `stage_id` хранит код, не ID | JOIN через `crm_stages.status_id = crm_deal.stage_id` + `entity_type_id = 2` + кастинг `category_id` |
| Фильтр `record_duration >= 60` отправляет 100% номеров в «недозвон» | `record_duration` фактически содержит длительность файла записи (часто NULL или 1–4 сек), а не разговора | Использовать `call_duration` (FLOAT, в секундах) |
| `telephony_call.call_type = 1` не возвращает строк | Поле строковое, не числовое | `call_type = '1'` |
| `redial_attempt` не показывает серию попыток менеджера | Поле — попытки автодозвона в рамках **одного** звонка | Серию собирать через `ROW_NUMBER() OVER (PARTITION BY phone_number ORDER BY call_start_time)` |
| У одного «номера» в `phone_number` оказались разные клиенты | Префиксы в номерах различаются (`+79991234567` vs `79991234567`) | Нормализация в CTE: `REGEXP_REPLACE(phone_number, '[^0-9]', '')` и взять последние 10–11 цифр |
| У лидов нет `category_id` | У лидов нет воронок в обычном смысле | В JOIN со `crm_stages` не использовать `category_id`, только `status_id` + `entity_type_id = 1` |
| Отчёт по «всем звонкам» неинформативен — менеджеры названивают по старым контактам | Нужен срез по «новым заявкам», а не по всем звонкам в принципе | Фильтр через CTE с целевыми лидами/сделками + JOIN по `crm_entity_id` |
| Не могу найти таблицу со смарт-процессом по имени | Каждый тип СП — отдельная таблица `crm_dynamic_items_<typeId>`, `typeId` портально-специфичный (кроме 31 = счета) | `SHOW TABLES IN bitrix24 LIKE 'crm_dynamic_items_%'` или `SELECT * FROM bitrix24.crm_smart_proc` |
| Хочу историю стадий смарт-процесса, но в `crm_deal_stage_history` его нет | Сделки/лиды/СП хранятся в РАЗНЫХ таблицах истории | Для смарт-процессов — `crm_entity_stage_history` с фильтром `owner_type_id = <typeId>` |
| Поля `task_elapsed_time` не совпадают с документацией REST | BI-схема отличается от REST: длительность называется `elapsed_time` (не `seconds`), нет `created_date`/`date_stop`/`minutes`/`source` | Ориентироваться на справочную таблицу полей в скилле, проверять разведкой |
| Формат «Продолжительность в мс» показывает миллиарды `dhms` | Пресет применён к колонке, где не миллисекунды (например, число часов) | В метрику с этим форматом подавать только `elapsed_ms`; часы держать отдельной колонкой без формата «мс» |
| Фильтр дашборда тихо не применяется к части чартов | Чарт на другом датасете, где нет колонки с тем же именем | Унифицировать имена колонок между датасетами (`responsible_name`, `tags`, даты) |
| Ищу per-chart выбор колонки для фильтра — не нахожу | В Superset 6 его нет в принципе, сопоставление только по имени колонки | Унификация имён колонок; для разного смысла — отдельные фильтры |
| Фильтр по дате объединил колонки с разным смыслом, результат бессмысленный | Одинаковое имя колонки при разном смысле (`date_start` = «выполнена работа» vs «создана задача») | Не сводить под один фильтр через переименование — держать два фильтра |

---

## Чек-лист перед сдачей отчёта

- [ ] Получено ТЗ от пользователя (что собрать, как показать, какие фильтры).
- [ ] План согласован с пользователем до начала сборки.
- [ ] Сделана разведка `SELECT *` по реальным записям перед написанием финального SQL.
- [ ] Уточнён у пользователя URL портала.
- [ ] Виртуальный датасет сохранён в SQL Lab под понятным именем.
- [ ] Каждый чарт сохранён под понятным именем.
- [ ] Фильтр по времени реально цепляется к time-колонке чартов.
- [ ] Если чарты на разных датасетах — имена ключевых колонок унифицированы под общие фильтры.
- [ ] Длительность для агрегируемых чартов подаётся как `elapsed_ms`, формат «мс» не применён к колонкам-часам.
- [ ] Кликабельные ссылки открываются в новой вкладке (`target="_blank"`).
- [ ] В таблицах с агрегацией включены итоги (если нужны).
- [ ] Даты отформатированы (без лишнего времени).
- [ ] Длительность отображается в нужных единицах.
- [ ] Для воронок проверен корректный учёт перескоков (через историю стадий).
- [ ] Для отчётов по звонкам: проверено, что используется `call_duration`, а не `record_duration`.
- [ ] Для отчётов по звонкам: `call_type` сравнивается со строкой (`'1'`, не `1`).
- [ ] Для отчётов по смарт-процессам: использована правильная таблица истории (`crm_entity_stage_history` с фильтром `owner_type_id`, а не `crm_deal_stage_history`).
