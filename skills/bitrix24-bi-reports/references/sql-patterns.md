# Типовые SQL-паттерны

Часть скилла `bitrix24-bi-reports`. Технические детали шага 5 «Сборка». Диалект — Trino (см. «Среда» в `SKILL.md`).

## Стандартный workflow разработки отчёта

ТЗ, план и разведка к этому моменту уже сделаны.

1. **Написать SQL для виртуального датасета** в SQL Lab → кнопка «Сохранить и исследовать» (сохраняет датасет и сразу открывает создание первого чарта).
2. **Создать чарты** один за другим, все на общем датасете. Однотипные — через «Сохранить как» (см. `references/superset-ui.md`).
3. **Создать дашборд**, разложить чарты.
4. **Настроить общие фильтры** на уровне дашборда. Если чарты на разных датасетах — следить за унификацией имён колонок (см. `references/superset-ui.md`).
5. **Финальная проверка** — по чек-листу в `SKILL.md`.

Если в датасете нужен фильтр по дате прямо внутри SQL — см. `references/jinja-superset.md`.

---

## Кликабельные ссылки

### На задачу

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

### На сделку

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

### На контакт (с ФИО)

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

⚠️ Markdown-ссылка `[текст](url)` в таблице чарта рендерится как plain text — использовать HTML `<a href="...">`. Для рендеринга HTML тип чарта должен быть «Таблица».

---

## Длительность

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

### Миллисекунды в SQL, форматирование в UI

⚠️ **Главная ловушка форматирования длительности.** Пресет Superset «Продолжительность в мс» применяется ко **всему**, что попало в метрику, без разбора смысла. Если подать в метрику с этим форматом число часов (`elapsed_hours`) — Superset воспримет его как миллисекунды и покажет миллиарды `dhms`.

Правило: длительность для агрегируемых чартов кладётся в датасет именно как **миллисекунды, округлённые до минут**:

```sql
(elapsed_time / 60) * 60 * 1000 AS elapsed_ms
```

В чарте: метрика `SUM(elapsed_ms)` → вкладка «Кастомизация» → «Форматирование» → пресет «Продолжительность в мс» → выводит `1d 16h 50m` без секунд.

Если для круговых/числовых чартов нужны именно часы — держать их **отдельной колонкой** `elapsed_hours` (`ROUND(elapsed_time / 3600.0, 2)`) и не применять к ней формат «мс». В датасете живут обе колонки, каждая под свой тип чарта.

---

## Год-месяц (группировка по месяцам)

```sql
DATE_FORMAT(d.begindate, '%Y-%m') AS year_month
```

⚠️ Поле строковое (`'2026-04'`). Чтобы отсортировать хронологически в чарте — в «Сортировке запроса» добавить колонку `year_month` с агрегатной функцией **MIN** + направление по возрастанию. Лексикографическая сортировка `YYYY-MM` совпадает с хронологической.

---

## Работа с `task.tags`

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

## Шаблон датасета «учёт времени по задачам и клиентам»

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

Имена колонок (`responsible_name`, `tags`) выбраны под совпадение с другими типовыми датасетами портала — это нужно для общих фильтров дашборда (см. `references/superset-ui.md`).

Чарты на этот датасет:
- Таблица «По компаниям» — измерение `tags`, метрика `SUM(elapsed_ms)`.
- Таблица «По сотрудникам» — измерение `responsible_name`, метрика та же.
- Круговая «Распределение по клиентам» — измерение `tags`, метрика `SUM(elapsed_hours)`.

Time column во всех чартах: `date_start`.
