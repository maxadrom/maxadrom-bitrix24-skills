# Jinja-фильтры по дате и Time Column

Часть скилла `bitrix24-bi-reports`. Открывать, когда нужен фильтр по периоду **внутри SQL виртуального датасета** — то есть когда временной фильтр дашборда должен резать данные ещё на уровне запроса, а не только в чарте.

Официальная документация Битрикса:
- [Использование SQL Lab и Jinja](https://helpdesk.bitrix24.ru/open/20351750/) — паттерн Jinja-фильтра.
- [Как настроить фильтры по дате в SQL-запросе](https://helpdesk.bitrix24.ru/open/24771482/) — общая стратегия.
- [Как работают фильтры по датам в BI Конструкторе](https://helpdesk.bitrix24.ru/open/19554660/) — фильтры дашборда, Time Range, Time Column.

---

## Паттерн Jinja-фильтра по дате

Битриксовый паттерн фильтра в `WHERE`:

```sql
WHERE
    {% if from_dttm %}
      col >= from_iso8601_timestamp('{{ from_dttm }}') AND
    {% endif %}
    {% if to_dttm %}
      col < from_iso8601_timestamp('{{ to_dttm }}') AND
    {% endif %}
    true
```

### Ключевые моменты

1. **`from_dttm` / `to_dttm` подаются как ISO-строка**, не как Python-объект `datetime`. Поэтому:
   - `.strftime("%Y-%m-%d")` **падает** с ошибкой `'str object' has no attribute 'strftime'`.
   - Не нужны срезы `[:10]` или `REPLACE`. Trino-функция `from_iso8601_timestamp(str)` парсит ISO напрямую.

2. **Использовать truthy-проверку** `{% if from_dttm %}`, **не** `{% if from_dttm is not none %}`. При сохранении датасета Битриксов Superset подаёт `from_dttm` как **пустую строку**, не как `None`. `is not none` пропустит блок, и `from_iso8601_timestamp('')` упадёт.

3. **`true` в конце `WHERE`** — гарантирует валидный SQL при отсутствии всех фильтров (когда все Jinja-блоки выпали).

4. **Многострочные Jinja-блоки в строковых литералах SQL могут ломать соседние слова** (наблюдали ошибку `mismatched input 'FUL'` вместо `FULL`). В таких случаях использовать однострочные `{{ x if y else z }}` через тернарник; конкатенация строк в Jinja — через `~`.

### Каст для фильтрации по DATE

Если колонка фильтрации — `DATE`, а не `TIMESTAMP` (например, дни, разложенные через `SEQUENCE`), оборачивать в `CAST(... AS DATE)`:

```sql
WHERE
    {% if from_dttm %}
      day >= CAST(from_iso8601_timestamp('{{ from_dttm }}') AS DATE) AND
    {% endif %}
    {% if to_dttm %}
      day < CAST(from_iso8601_timestamp('{{ to_dttm }}') AS DATE) AND
    {% endif %}
    true
```

---

## Time Column в чарте — НЕ через `CURRENT_TIMESTAMP`

⚠️ **Анти-паттерн.** Для зацепления временного фильтра чарта (Time Column) нельзя создавать виртуальную колонку с выражением `CURRENT_TIMESTAMP`:

- `CURRENT_TIMESTAMP` в Trino возвращает `timestamp with time zone`.
- Superset подаёт границы фильтра как строку (`varchar`).
- Сравнение `timestamp with time zone <= varchar` падает с `TYPE_MISMATCH`.
- Даже обёртка `CAST(CURRENT_TIMESTAMP AS TIMESTAMP)` (без зоны) не помогает — `timestamp <= varchar` тоже падает.

**Правильно (по документации Битрикса):** в финальный `SELECT` датасета добавить **реальную колонку даты** — либо колонку из данных (`date_create`), либо вычисленную через Jinja:

```sql
SELECT
    {% if from_dttm %}
      CAST(from_iso8601_timestamp('{{ from_dttm }}') AS TIMESTAMP)
    {% else %}
      TIMESTAMP '2000-01-01 00:00:00'
    {% endif %}
                                                            AS date_create,
    ...
```

После сохранения датасета — обязательно нажать «**Синхронизировать столбцы из источника**» во вкладке «Столбцы», чтобы Superset подхватил новое поле. Затем в чарте выбрать его как Time Column.

---

## Чек-лист настройки датасета с Jinja-фильтром

1. Сохранить SQL как виртуальный датасет («Сохранить и исследовать»).
2. Открыть редактирование датасета → вкладка «Столбцы» → нажать «**Синхронизировать столбцы из источника**» (иначе новые/вычисленные колонки Superset не увидит).
3. В чарте: указать Time Column (реальная колонка даты, не `CURRENT_TIMESTAMP`), задать Time Range (напр. «Этот месяц»).
4. Проверить, что фильтр периода реально режет данные — поменять диапазон и убедиться, что цифры меняются.
