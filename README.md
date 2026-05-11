# Claude Skills для Битрикс24

Коллекция [Claude Skills](https://github.com/anthropics/skills) для работы с Битрикс24 — теперь Claude (в Claude.ai, Claude Code, API) умеет делать в Б24 то, что делает живой Б24-эксперт.

Каждый скилл — это папка с `SKILL.md`: набор инструкций, SQL-паттернов и граблей, накопленных в боевых проектах. Claude подгружает их сам, когда видит подходящий запрос.

## Скиллы

| Скилл | Срабатывает на |
|---|---|
| [`bitrix24-bi-reports`](skills/bitrix24-bi-reports/SKILL.md) | «BI-конструктор», «BI Битрикса», «Superset», «отчёт в Битриксе», «дашборд в B24», «SQL Lab», «Trino», «чарт по задачам», «отчёт по сделкам», «воронка продаж», «конверсия по этапам» |

> Скоро: `bitrix24-documents` (генерация .docx из шаблонов).

## Что внутри `bitrix24-bi-reports`

Разработка отчётов и дашбордов в BI-конструкторе Битрикс24 (Trino + Apache Superset 6.0). Покрывает:

- Каталог датасетов (`task`, `task_elapsed_time`, `crm_deal`, `crm_deal_stage_history`, `crm_stages` и др.) с правильными связками между ними.
- Trino-специфика (`CONCAT` вместо `||`, `MOD` вместо `%`, кастинг типов между `crm_deal.category_id` VARCHAR и `crm_stages.category_id` BIGINT).
- SQL-паттерны: кликабельные ссылки на задачи/сделки/контакты через `{{portal_url()}}`, длительность как строка `Hh MMm`, накопительные воронки через `crm_deal_stage_history`.
- Раскраска ячеек таблиц через `CONCAT` + HTML `<div style="background-color:...">` + `CASE` — то, что штатным «Условным форматированием» Superset для строковых колонок сделать нельзя.
- Форматирование длительности (`pretty-ms`) и дат, хронологическая сортировка строкового `year_month`.
- Большая таблица типичных граблей с причинами и решениями.

## Как поставить

Скилл следует [открытому стандарту Agent Skills](https://github.com/anthropics/skills) — один и тот же `SKILL.md` работает в Claude, ChatGPT, Codex и Qwen Code. Меняется только путь установки.

### Claude.ai (Pro / Team / Enterprise)

Settings → Capabilities → Skills → загрузить папку скилла как кастомный. Подробно: [docs Anthropic](https://support.claude.com/en/articles/12512180-using-skills-in-claude).

### Claude Code

```bash
git clone https://github.com/maxadrom/maxadrom-bitrix24-skills.git
cp -r maxadrom-bitrix24-skills/skills/bitrix24-bi-reports ~/.claude/skills/
```

Личные скиллы лежат в `~/.claude/skills/`, проектные — в `.claude/skills/` репозитория. Подробно: [docs Claude Code](https://docs.claude.com/en/docs/claude-code/skills).

### ChatGPT (Plus / Team / Enterprise / Edu)

Бета. У Enterprise/Edu админ должен сначала включить скиллы в настройках workspace.

Профиль → **Skills** → **New skill** → **Upload from your computer** → загрузить папку скилла. Подробно: [help OpenAI](https://help.openai.com/en/articles/20001066-skills-in-chatgpt).

### OpenAI Codex

```bash
cp -r maxadrom-bitrix24-skills/skills/bitrix24-bi-reports ~/.codex/skills/
```

Либо внутри Codex: `$skill-installer install https://github.com/maxadrom/maxadrom-bitrix24-skills/tree/main/skills/bitrix24-bi-reports`. После установки — перезапустить Codex. Подробно: [docs Codex](https://developers.openai.com/codex/skills).

### Qwen Code

```bash
# личный скилл — доступен везде
cp -r maxadrom-bitrix24-skills/skills/bitrix24-bi-reports ~/.qwen/skills/

# или проектный — только в текущем репозитории
cp -r maxadrom-bitrix24-skills/skills/bitrix24-bi-reports .qwen/skills/
```

Перезапустить Qwen Code. Команда `/skills` покажет все установленные. Подробно: [docs Qwen Code](https://github.com/QwenLM/qwen-code/blob/main/docs/users/features/skills.md).

### Claude API

Через [Skills API endpoint](https://docs.claude.com/en/api/skills-guide#creating-a-skill).

## Контрибьютить

Грабли, паттерны, SQL-сниппеты — присылайте PR или открывайте issue. Особенно интересны:

- Нестандартные поля в датасетах конкретных порталов (тех самых, которые видны только через `SELECT *`).
- Новые SQL-паттерны под типовые отчёты (звонки, лиды, задачи по проектам).
- Грабли, которые ещё не в таблице.

## Автор

Максим — Битрикс24-эксперт, разработчик и блогер. Делаю отчёты, автоматизации и ЛК-чатботы под Б24.

- ВКонтакте: [vk.com/getmorecash](https://vk.com/getmorecash)
- Telegram: [t.me/dgtorCRM](https://t.me/dgtorCRM)
- MAX: [max.ru/id371800696102_biz](https://max.ru/id371800696102_biz)

## Лицензия

MIT — пользуйтесь, форкайте, адаптируйте под свои порталы.
