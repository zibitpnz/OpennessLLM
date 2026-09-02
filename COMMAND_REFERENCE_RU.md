# OpennessLLM Command Reference

Версия инструмента: `0.12.3`.

Создано: `Zibitpnz`.

Этот файл является подробным справочником CLI-команд `OpennessLLM`. Источник
истины для краткого списка команд всегда:

```cmd
.\OpennessLLM\run.cmd --help
.\OpennessLLM\run.cmd version
```

## 1. Общая модель работы

`OpennessLLM` - командная оболочка вокруг TIA Portal Openness SDK. Инструмент
предназначен для работы человека или LLM с TIA Portal проектом через короткие
команды, отчеты и guarded write workflow.

Есть четыре класса команд:

```text
Local-only      Не открывают TIA Portal и не требуют project file.
Read-only       Читают открытый или headless TIA проект, но не пишут в него.
Probe/copy-only Пишут только во временную копию проекта или локальный workspace.
Write           Могут изменить TIA проект, требуют явный --apply.
```

Write-команды TIA-проекта в версии `0.12.3`:

```text
apply-clone
compile-block
compile-all
delete-block
set-attribute
create-test-visual-fb
hmi-project-texts-apply
```

Важно: компиляция в TIA Portal считается write-командой, потому что TIA может
изменить compile state проекта. Поэтому `compile-block` и `compile-all` требуют
явный `--apply` для реального запуска компиляции.

Отдельная runtime write-команда PLC:

```text
plc-runtime-write
```

Она не открывает TIA Portal и не меняет проект, но может изменить значения в
живом PLC. Поэтому реальная запись требует два явных флага:
`--apply --i-know-this-writes-plc`. Без них команда работает как dry-run.

## 2. Общие параметры

```text
--project <path>      Явный путь к *.apXX проекту.
--api-dir <path>      Явный путь к Siemens.Engineering PublicAPI.
--headless            Запустить TIA Portal без UI.
--attach              Подключиться к уже открытому TIA Portal.
--attach-index <n>    Выбрать процесс TIA Portal, если их несколько.
--out <path>          Выходной каталог. Для workflow обычно .\CLONE_PROJECT.
--in <path>           Входной каталог для offline команд и HMI probes.
--patch <path>        JSONL patch file для hmi-apply-preflight.
--map <path>          CSV-файл карты runtime-смещений или папка с plc-runtime-map.csv.
--software-path <p>   Фокус PLC clone/status команд на одном software path/name.
--hmi-target-path <p> Фокус HMI части status/init-workspace на одном HMI target path/name.
--force               Перезаписывать export-файлы, где команда это поддерживает.
--apply               Разрешить реальное write-действие.
--save                Сохранить TIA проект после успешной write-команды.
--no-backup           Отключить backup там, где это разрешено.
--json                Машиночитаемый JSON для поддерживаемых lookup-команд.
--max <n>             Лимит вывода tree.
--group <path>        Человекочитаемый PLC block group display path. Root можно указывать как _root.
--group-key <key>     Escaped PLC block group key, например Libraries/Units%2Fsensors.
--name <name>         Имя блока, HMI объекта или другого target.
--number <n>          Номер блока или номер для create/test команд.
--number-space <x>    Пространство номеров: FB, FC, DB или OB.
--language <lang>     Язык для visual test blocks: LAD, FBD, GRAPH, ALL.
--extension <ext>     Расширение PLC source export: scl, awl, db.
--scope <name>        Scope для clean-local или plc-runtime-snapshot: db/all.
--host <ip/name>      PLC host для plc-runtime-* команд.
--rack <n>            S7 rack для plc-runtime-* команд.
--slot <n>            S7 slot для plc-runtime-* команд.
--connection-type <n> S7 remote TSAP high byte: 1=PG, 2=OP, 3=basic.
--db <n/name>         DB number или DB name для plc-runtime-read/write/snapshot.
--start <n>           Начальный byte offset для plc-runtime-probe.
--size <n>            Количество байт для plc-runtime-probe.
--var <path>          Путь переменной из runtime-карты.
--vars <a,b,c>        Список переменных для plc-runtime-snapshot.
--var-list <path>     Файл со списком переменных для plc-runtime-snapshot.
--from <path>         Начальная переменная диапазона snapshot.
--to <path>           Конечная переменная диапазона snapshot.
--range <start:size>  Byte-range для plc-runtime-snapshot.
--max-read-bytes <n>  Максимальный размер одного S7 ReadVar при snapshot, default 222.
--single-read         Требовать один S7 ReadVar для выбранного snapshot-диапазона.
--print-values        Печатать snapshot values в консоль.
--value <value>       Значение для plc-runtime-write.
--i-know-this-writes-plc Второй обязательный флаг реальной PLC runtime записи.
```

Если `--project` не указан, инструмент пытается найти единственный `*.apXX`
рядом с текущей папкой проекта. Если найдено несколько проектов, нужно передать
`--project` явно.

Если `--api-dir` не указан, API ищется через:

```text
TIA_OPENNESS_API_DIR
registry / installed Portal path
standard C:\Program Files\Siemens\Automation\Portal VXX\PublicAPI\VXX\net48
legacy C:\Program Files\Siemens\Automation\Portal VXX\PublicAPI\VXX
```

Версия API должна совпадать с версией проекта, например `*.ap21` требует
PublicAPI `V21`. Начиная с `0.10.6`, инструмент принимает как новую раскладку
PublicAPI с `Siemens.Engineering.Base.dll`, так и legacy-раскладку, где основная
сборка называется `Siemens.Engineering.dll`. Это важно для переносов на
установки TIA Portal V20.

## 3. Локальные команды

### version

Печатает версию и назначение инструмента. Не открывает TIA Portal.

```cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd --version
```

Использовать в начале любой новой LLM-сессии.

### self-test

Запускает offline regression tests без TIA Portal и без project file.

```cmd
.\OpennessLLM\run.cmd self-test
.\OpennessLLM\run.cmd self-test --out .\OpennessLLM\out\self-test-current
```

Назначение:

```text
проверить парсеры;
проверить HMI digest/preflight helpers;
проверить clone/apply gates;
проверить local-only command classification;
проверить block-info lookup index;
проверить сохранение SoftwarePath в clone metadata;
проверить plc-runtime-map для Global DB и Instance DB.
```

Когда запускать:

```text
после изменения Program.cs;
после переноса инструмента;
перед серьезной работой с проектом;
если новая LLM-сессия сомневается, что tool работает.
```

### block-info

Ищет PLC блок в локальном `CLONE_PROJECT` без открытия TIA Portal.

```cmd
.\OpennessLLM\run.cmd block-info --name 5_HM --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd block-info --number 5 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd block-info --number 5 --number-space DB --out .\CLONE_PROJECT --json
```

Что читает:

```text
CLONE_PROJECT\_metadata\blocks.jsonl
CLONE_PROJECT\plc-blocks.csv
CLONE_PROJECT\clone-check-blocks.csv
```

Что возвращает:

```text
имя блока;
номер и number space;
тип блока;
язык;
block group display path и escaped group key;
source file;
clone-check status;
metadata baseline.
```

Если имя TIA-группы само содержит `/`, например `Units/sensors`, в отчетах
появляется `GroupPathKey` с percent-encoding: `Libraries/Units%2Fsensors`.
Для точного выбора такой группы можно использовать `--group-key`.

Это основная команда для LLM, когда нужно узнать номер блока или найти блок по
номеру. Не нужно вручную искать номера в CSV, JSON или исходниках, если
`block-info` подходит.

### plc-runtime-probe

Read-only проверка прямого S7comm / ISO-on-TCP подключения к живому PLC. Команда
не открывает TIA Portal и не пишет в PLC.

Адрес `192.0.2.10` и имена DB/полей в примерах этого раздела являются
документационными. Перед запуском их необходимо заменить параметрами своего PLC.

```cmd
.\OpennessLLM\run.cmd plc-runtime-probe --host 192.0.2.10 --rack 0 --slot 2 --connection-type 1 --db 210 --start 0 --size 32 --timeout-ms 5000
```

Назначение:

```text
открыть TCP port 102;
выполнить COTP connect;
выполнить S7 setup communication;
прочитать байты DB;
вывести hex dump.
```

Ограничения:

```text
читает только DB area;
для первого диагностического чтения размер ограничен безопасным малым диапазоном;
параллельные S7-подключения к WinAC лучше не запускать, выполнять чтения последовательно.
```

### plc-runtime-map

Строит карту смещений для classic non-optimized Global DB и Instance DB из
локального `CLONE_PROJECT`. Команда не открывает TIA Portal.

Global DB читаются напрямую из `.db` файлов с `DATA_BLOCK ... STRUCT ...
END_STRUCT`. Instance DB читаются через связанный FB из `InstanceOfName`.

```cmd
.\OpennessLLM\run.cmd plc-runtime-map --in .\CLONE_PROJECT --out .\OpennessLLM\out\plc-runtime-map-current
```

Что читает:

```text
CLONE_PROJECT\plc-blocks.csv;
CLONE_PROJECT\_root\**\*.scl;
CLONE_PROJECT\_root\**\*.db;
CLONE_PROJECT\_root\**\*.meta.json, если source-файл еще не попал в plc-blocks.csv.
```

Поиск под `_root` рекурсивный: PLC block groups в clone не требуют отдельного
запуска карты для каждой папки.

Что пишет:

```text
OpennessLLM\out\plc-runtime-map-current\plc-runtime-map.csv;
OpennessLLM\out\plc-runtime-map-current\plc-runtime-map.md;
OpennessLLM\out\plc-runtime-map-current\DB_*.md;
OpennessLLM\out\plc-runtime-map-current\plc-runtime-map-summary.txt;
CLONE_PROJECT\_runtime_maps\plc-runtime-map.csv;
CLONE_PROJECT\_runtime_maps\plc-runtime-map.md;
CLONE_PROJECT\_runtime_maps\DB_*.md;
CLONE_PROJECT\_runtime_maps\plc-runtime-map-summary.txt.
```

Правила расчета:

```text
Bool пакуются по битам;
перед не-Bool переменной выполняется byte alignment;
границы секций FB VAR_INPUT / VAR_OUTPUT / VAR_IN_OUT / VAR выравниваются на четный байт;
Global DB Data-секция считается непрерывной структурой без FB section-boundary alignment;
VAR_TEMP и VAR CONSTANT не занимают память instance DB и не попадают в карту;
Struct и вложенные Struct раскрываются по путям вида Outer.Inner.Value;
вложенный FB раскрывается через его SCL declaration;
TCON, TDISCON, TSEND, TRCV учитываются как system FB известного размера;
Array[... ] of Byte поддерживается;
quoted DB field names вроде "Source__Target_busy" поддерживаются и пишутся в карту без кавычек.
```

Если SCL/DB структура изменилась, карту нужно перестроить перед
`plc-runtime-read` или `plc-runtime-write`.

### plc-runtime-read

Читает одну переменную из живого PLC по имени DB и пути переменной из карты.

```cmd
.\OpennessLLM\run.cmd plc-runtime-read --host 192.0.2.10 --db DB_Test_Outputs --var Online --map .\CLONE_PROJECT\_runtime_maps --timeout-ms 5000
.\OpennessLLM\run.cmd plc-runtime-read --host 192.0.2.10 --db 211 --var AllowedOutputMask --map .\CLONE_PROJECT\_runtime_maps --timeout-ms 5000
```

Поддерживаемые типы чтения:

```text
Bool;
Byte;
Word;
Int;
DWord;
DInt;
Real.
```

Команда читает минимальный диапазон DB, декодирует значение и печатает raw hex.
Для диагностики модулей ввода/вывода нужно читать данные из instance DB
функционального блока, например `DB_Test_Outputs.AllowedOutputMask`.

### plc-runtime-snapshot

Read-only снимок значений из живого PLC по runtime-карте. Команда не открывает
TIA Portal и ничего не пишет в PLC.

Полный снимок одного DB:

```cmd
.\OpennessLLM\run.cmd plc-runtime-snapshot --host 192.0.2.10 --rack 0 --slot 2 --db DB_Test_Inputs --map .\CLONE_PROJECT\_runtime_maps --out .\CLONE_PROJECT\_runtime_snapshots --timeout-ms 5000
```

Выборочный снимок списка переменных:

```cmd
.\OpennessLLM\run.cmd plc-runtime-snapshot --host 192.0.2.10 --db DB_Test_Inputs --vars Online,DataValid,InputWord0,InputWord0Valid --map .\CLONE_PROJECT\_runtime_maps --out .\CLONE_PROJECT\_runtime_snapshots --print-values
```

Диапазон между переменными:

```cmd
.\OpennessLLM\run.cmd plc-runtime-snapshot --host 192.0.2.10 --db DB_Test_Inputs --from Online --to LastInputValid --map .\CLONE_PROJECT\_runtime_maps --out .\CLONE_PROJECT\_runtime_snapshots
```

Низкоуровневый byte-range:

```cmd
.\OpennessLLM\run.cmd plc-runtime-snapshot --host 192.0.2.10 --db DB_Test_Inputs --range 0:180 --map .\CLONE_PROJECT\_runtime_maps --out .\CLONE_PROJECT\_runtime_snapshots
```

Все DB из карты:

```cmd
.\OpennessLLM\run.cmd plc-runtime-snapshot --host 192.0.2.10 --scope all --map .\CLONE_PROJECT\_runtime_maps --out .\CLONE_PROJECT\_runtime_snapshots
```

Что пишет:

```text
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-summary.txt;
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-values.csv;
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-values.md;
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-values.json;
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-raw.hex;
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-read-ranges.csv.
```

Важное ограничение:

```text
один S7 ReadVar диапазон одного DB - самый близкий к "одному моменту" срез;
большие DB читаются несколькими диапазонами до --max-read-bytes, default 222;
несколько диапазонов и несколько DB читаются последовательно;
snapshot-read-ranges.csv показывает реальные интервалы чтения и их статус.
```

Если нужен строгий один S7-запрос, использовать `--single-read`. Команда
завершится ошибкой, если выбранный диапазон нужно читать несколькими запросами.

### plc-runtime-write

Осторожная запись одной переменной в живой PLC по имени DB и пути переменной из
карты. Это не запись в TIA-проект, но это реальное изменение значения в
работающем PLC.

Dry-run по умолчанию:

```cmd
.\OpennessLLM\run.cmd plc-runtime-write --host 192.0.2.10 --db DB_Test_Outputs --var Output_1 --value true --map .\CLONE_PROJECT\_runtime_maps --timeout-ms 5000
```

Реальная запись:

```cmd
.\OpennessLLM\run.cmd plc-runtime-write --host 192.0.2.10 --db DB_Test_Outputs --var Output_1 --value true --map .\CLONE_PROJECT\_runtime_maps --timeout-ms 5000 --apply --i-know-this-writes-plc
```

Защиты:

```text
без --apply запись не выполняется;
с --apply, но без --i-know-this-writes-plc запись не выполняется;
read-only строки карты не записываются;
Bool пишется через read-modify-write одного байта;
после реальной записи выполняется read-back;
для CommandMask / AllowedOutputMask выходных модулей запрещены биты выше 24 выходов.
```

Поддерживаемые типы записи:

```text
Bool;
Byte;
Word;
Int;
DWord;
DInt;
Real.
```

### hmi-digest

Offline parser HMI XML export. Не открывает TIA Portal.

```cmd
.\OpennessLLM\run.cmd hmi-digest --in .\OpennessLLM\out\hmi-export-current --out .\OpennessLLM\out\hmi-digest-current
```

Назначение: превратить тяжелый HMI XML в компактные CSV/JSON/Markdown индексы.

Типичные выходные файлы:

```text
hmi-digest.json
hmi-xml-files.csv
hmi-screen-items.csv
hmi-screen-bindings.csv
hmi-event-handlers.csv
hmi-tag-details.csv
hmi-text-list-items.csv
screens\*.md
```

LLM должна сначала читать digest, а не полный XML.

### hmi-apply-preflight

Offline/read-only HMI patch preflight. Не пишет в TIA Portal. Пишет только
локальную patched-копию XML внутри `CLONE_PROJECT`.

```cmd
.\OpennessLLM\run.cmd hmi-apply-preflight --out .\CLONE_PROJECT --patch .\patch.jsonl
```

Требует предварительно:

```text
hmi-init-clone
hmi-check
hmi-digest metadata внутри CLONE_PROJECT
```

Выходные файлы:

```text
CLONE_PROJECT\hmi-apply-preflight-summary.txt
CLONE_PROJECT\hmi-apply-preflight-plan.csv
CLONE_PROJECT\hmi-apply-preflight-issues.csv
CLONE_PROJECT\hmi-apply-preflight-collateral.csv
CLONE_PROJECT\_hmi_preflight\patched-*\...
```

Поддерживаемые patch операции зависят от текущей версии, но включают text-list
entry, screen item text, geometry attributes, selected links, event parameters,
duplicate/move screen items. Если операция не поддержана, preflight пишет issue
с `UNSUPPORTED_OPERATION`.

### sync-clone

Локально принимает последний результат `check-clone` в PLC clone baseline.

```cmd
.\OpennessLLM\run.cmd sync-clone --out .\CLONE_PROJECT
```

Команда не открывает TIA Portal. Ее нужно запускать только после осознанного
`check-clone`, когда текущее состояние проекта считается правильным baseline.

Начиная с `0.12.2`, если `check-clone` нашел новый блок, созданный в TIA Portal,
`sync-clone` сохраняет для него `SoftwarePath` и в `plc-blocks.csv`, и в
`CLONE_PROJECT\_metadata\blocks.jsonl`. Это важно для последующих lookup/gates и
для проектов с несколькими PLC software targets.

### clean-local

Аудит или удаление локальных generated artifacts. Не открывает TIA Portal.

```cmd
.\OpennessLLM\run.cmd clean-local
.\OpennessLLM\run.cmd clean-local --scope probe-generated
.\OpennessLLM\run.cmd clean-local --scope probe-generated --apply
.\OpennessLLM\run.cmd clean-local --scope workspace-transient
```

Scopes:

```text
audit                Только классификация. По умолчанию.
probe-generated      Может удалить OpennessLLM\out при --apply.
workspace-transient  Аудит временных папок CLONE_PROJECT compare/preflight.
```

`clean-local --apply` с `--scope audit` запрещен. Нужно явно выбрать destructive
scope.

## 4. Project bootstrap и статус

### init-workspace

Создает или обновляет локальный workspace `CLONE_PROJECT` для PLC и HMI в одной
команде. С точки зрения TIA проекта команда read-only.

```cmd
.\OpennessLLM\run.cmd init-workspace --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd init-workspace --attach --attach-index 0 --out .\CLONE_PROJECT --software-path "PLC_1" --hmi-target-path "HMI_1"
```

Что делает:

```text
собирает PLC inventory;
экспортирует PLC source baseline;
создает CLONE_PROJECT\_root;
создает metadata baseline;
инициализирует HMI XML snapshot, если HMI target доступен;
создает HMI digest metadata;
запускает первичные check/status reports.
```

Ключевые отчеты:

```text
CLONE_PROJECT\workspace-init-summary.txt
CLONE_PROJECT\workspace-init-steps.csv
CLONE_PROJECT\workspace-init.json
CLONE_PROJECT\tool-status-summary.txt
```

### status / check-all

Проверяет готовность PLC/HMI workspace одной командой.

```cmd
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd check-all --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT --software-path "PLC_1" --hmi-target-path "HMI_1"
```

`check-all` является alias для `status`.

Что делает:

```text
проверяет наличие CLONE_PROJECT;
запускает/оценивает PLC clone check;
запускает/оценивает HMI clone check;
пишет общий readiness verdict.
```

Ключевые отчеты:

```text
CLONE_PROJECT\tool-status-summary.txt
CLONE_PROJECT\tool-status.json
CLONE_PROJECT\clone-check-summary.txt
CLONE_PROJECT\hmi-check-summary.txt
```

## 5. Read-only inspection commands

### tree

Печатает дерево проекта: devices, PLC blocks, tags. Удобно для быстрого обзора.

```cmd
.\OpennessLLM\run.cmd tree --attach --attach-index 0 --max 1000
.\OpennessLLM\run.cmd tree --headless --project .\Project.ap21 --max 500
```

### inventory

Пишет структурированный inventory проекта.

```cmd
.\OpennessLLM\run.cmd inventory --attach --attach-index 0 --out .\OpennessLLM\out\inventory-current
```

Типичные файлы:

```text
project-summary.txt
devices.csv
blocks.csv
tags.csv
inventory.json
```

### inspect

Печатает runtime type information для первых найденных объектов. Это
диагностическая команда для понимания TIA SDK surface.

```cmd
.\OpennessLLM\run.cmd inspect --attach --attach-index 0
```

Использовать, когда нужно понять, какие attributes/compositions доступны у
конкретных SDK объектов.

## 6. PLC clone workflow

### clone-folders

Создает структуру папок PLC block groups под `CLONE_PROJECT\_root`, но не
экспортирует все source файлы.

```cmd
.\OpennessLLM\run.cmd clone-folders --attach --attach-index 0 --out .\CLONE_PROJECT
```

Обычно вместо этой команды удобнее использовать `init-clone` или
`init-workspace`.

### init-clone

Создает PLC clone baseline: папки, source files, CSV и JSONL metadata.

```cmd
.\OpennessLLM\run.cmd init-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd init-clone --attach --attach-index 0 --out .\CLONE_PROJECT --software-path "PLC_1"
```

Основные результаты:

```text
CLONE_PROJECT\_root\...
CLONE_PROJECT\plc-blocks.csv
CLONE_PROJECT\clone-check-blocks.csv
CLONE_PROJECT\clone-check-groups.csv
CLONE_PROJECT\clone-check-source-blockers.csv
CLONE_PROJECT\clone-check-summary.txt
CLONE_PROJECT\clone-check-bundle.json
CLONE_PROJECT\_metadata\clone-manifest.json
CLONE_PROJECT\_metadata\blocks.jsonl
CLONE_PROJECT\_metadata\groups.jsonl
CLONE_PROJECT\_metadata\schema-version.txt
```

### check-clone

Сравнивает текущий TIA проект с `CLONE_PROJECT`.

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT --software-path "PLC_1"
```

Типичные статусы:

```text
unchanged
changed
added
removed
source-blocker
unsupported
```

Перед любым `apply-clone --apply` нужно иметь свежий `check-clone`.

### apply-clone

Основной PLC write workflow. Применяет изменения source files из
`CLONE_PROJECT` обратно в TIA Portal через External Sources.

Dry-run:

```cmd
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Реальное применение:

```cmd
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT --apply
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT --apply --save
```

Поддерживает:

```text
изменение source существующих блоков;
создание clone-only блоков;
delete блоков, если это безопасно;
rename внутри той же PLC group;
создание missing nested group path для новых блоков;
Instance DB ordering после FB/FC/OB sources.
```

Запрещает или блокирует:

```text
move между block groups;
удаление FB с Instance DB, если это опасно;
смену InstanceOfName для Instance DB;
duplicate final block numbers;
устаревший source после последнего check-clone;
непроверенные LAD/FBD/GRAPH source round-trip без visualSourceVerified.
```

Ключевые отчеты:

```text
apply-clone-preflight-summary.txt
apply-clone-preflight-plan.csv
apply-clone-preflight-issues.csv
apply-clone-summary.txt
apply-clone-gates.csv
apply-clone-operations.csv
_metadata\apply-clone-preflight-plan.jsonl
_metadata\apply-clone-preflight-issues.jsonl
```

## 7. PLC export and diagnostics

### export-source

Генерирует PLC source files через `ExternalSourceGroup.GenerateSource()`.

```cmd
.\OpennessLLM\run.cmd export-source --attach --attach-index 0 --name OB1 --extension awl --out .\CLONE_PROJECT\source
.\OpennessLLM\run.cmd export-source --attach --attach-index 0 --name FB_Openness_Test --extension scl --out .\CLONE_PROJECT\source
.\OpennessLLM\run.cmd export-source --attach --attach-index 0 --name DB_Main --extension db --out .\CLONE_PROJECT\source
```

Команда полезна для точечного debug, но основной baseline лучше вести через
`init-clone`/`check-clone`.

### export-xml

Экспортирует blocks/tag tables в XML, если объект поддерживает `Export()`.

```cmd
.\OpennessLLM\run.cmd export-xml --attach --attach-index 0 --out .\OpennessLLM\out\export-current --force
```

Использовать осторожно: XML полезен для анализа SDK structure, но не является
основным способом изменения PLC.

### export-documents

Пробует экспорт PLC block documents через `ExportAsDocuments()`.

```cmd
.\OpennessLLM\run.cmd export-documents --attach --attach-index 0 --name FB_Openness_Test --out .\CLONE_PROJECT\documents
```

Диагностическая команда. Наличие документов зависит от типа блока и SDK.

### compile-block

Компилирует один PLC блок. Dry-run без `--apply`.

```cmd
.\OpennessLLM\run.cmd compile-block --attach --attach-index 0 --name FB_Openness_Test
.\OpennessLLM\run.cmd compile-block --attach --attach-index 0 --name FB_Openness_Test --apply
.\OpennessLLM\run.cmd compile-block --attach --attach-index 0 --name FB_Openness_Test --apply --save
```

Опции:

```text
--name <name>       Обязательно.
--group <path>      Если нужно сузить поиск.
--apply             Реально компилировать.
--save              Сохранить проект после успешной компиляции.
--no-backup         Не создавать backup перед --apply.
```

Выводит рекурсивные TIA compiler messages, включая вложенные `Description` и
`Path`. Если TIA возвращает errors, команда завершается ошибкой.

### compile-all

Компилирует самый широкий SDK-supported scope.

```cmd
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply --save
```

Поведение:

```text
без --apply печатает стратегию и targets;
с --apply пытается project-level CompileProvider;
если project-level недоступен, берет все compile-capable software targets;
печатает messages по каждому target;
если errors > 0, команда падает с non-zero exit;
--save сохраняет проект только при zero errors.
```

В текущем тестовом проекте TIA SDK не exposes compile provider на Project, но
exposes provider на PLC software и HMI runtime software, поэтому используется
software CompileProvider fallback.

## 8. PLC write helpers

### set-attribute

Экспериментальная write-команда для установки SDK attribute.

```cmd
.\OpennessLLM\run.cmd set-attribute --attach --attach-index 0 --target block --name OB1 --attribute HeaderAuthor --value Codex
.\OpennessLLM\run.cmd set-attribute --attach --attach-index 0 --target block --name OB1 --attribute HeaderAuthor --value Codex --apply --save
```

Поддерживаемые targets:

```text
block
tag-table
tag
```

Использовать точечно. Для production PLC source edits основной путь -
`apply-clone`.

### delete-block

Удаляет один PLC block. Dry-run без `--apply`.

```cmd
.\OpennessLLM\run.cmd delete-block --attach --attach-index 0 --name SomeBlock
.\OpennessLLM\run.cmd delete-block --attach --attach-index 0 --name SomeBlock --apply --save
```

Для production delete через clone baseline предпочтительнее `apply-clone`,
потому что там больше preflight/gate отчетов.

### create-test-visual-fb

Создает тестовые LAD/FBD/GRAPH function blocks через SDK.

```cmd
.\OpennessLLM\run.cmd create-test-visual-fb --attach --attach-index 0 --language LAD --number 9001
.\OpennessLLM\run.cmd create-test-visual-fb --attach --attach-index 0 --language ALL --apply --save
```

Это тестовая/диагностическая команда. Не использовать как основной production
workflow.

### clone

Копирует папку проекта в safe working folder.

```cmd
.\OpennessLLM\run.cmd clone --project .\Project.ap21 --out C:\TIA_PROJECT_BACKUPS\Project_copy
```

Практически чаще backup создают сами write-gates перед apply, но команда
полезна для ручной подготовки копии.

## 9. HMI read-only commands

### hmi-inventory

Пишет read-only inventory HMI targets, screens, tag tables, text lists, scripts и
связанных объектов.

```cmd
.\OpennessLLM\run.cmd hmi-inventory --attach --attach-index 0 --out .\OpennessLLM\out\hmi-inventory-current
```

### hmi-export-xml

Экспортирует HMI screens, tag tables, text lists, graphic lists, scripts,
connections и related objects в XML.

```cmd
.\OpennessLLM\run.cmd hmi-export-xml --attach --attach-index 0 --out .\OpennessLLM\out\hmi-export-current --force
```

XML нужен как полный snapshot, но для LLM-анализа сначала использовать
`hmi-digest`.

### hmi-init-clone

Инициализирует HMI baseline внутри `CLONE_PROJECT`.

```cmd
.\OpennessLLM\run.cmd hmi-init-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Создает:

```text
CLONE_PROJECT\_hmi\...
CLONE_PROJECT\_hmi_metadata\...
CLONE_PROJECT\hmi-clone-summary.txt
```

### hmi-check

Сравнивает текущий HMI XML snapshot из TIA Portal с HMI baseline в
`CLONE_PROJECT`.

```cmd
.\OpennessLLM\run.cmd hmi-check --attach --attach-index 0 --out .\CLONE_PROJECT
```

Ключевые отчеты:

```text
hmi-check-summary.txt
hmi-check-objects.csv
_hmi_compare\current-*\...
```

### hmi-sync-clone

Принимает текущий HMI snapshot в baseline `CLONE_PROJECT`, если sync gates
разрешают это.

```cmd
.\OpennessLLM\run.cmd hmi-sync-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Использовать после визуально/инженерно принятого состояния HMI.

## 10. HMI SDK probes

Эти команды нужны для анализа возможностей TIA SDK без записи в текущий проект.

### hmi-import-capabilities

Печатает import/export/create/delete method signatures для HMI объектов.

```cmd
.\OpennessLLM\run.cmd hmi-import-capabilities --attach --attach-index 0 --out .\OpennessLLM\out\hmi-capabilities-current
```

### hmi-textlist-model-probe

Инспектирует TextList attributes/compositions без записи.

```cmd
.\OpennessLLM\run.cmd hmi-textlist-model-probe --attach --attach-index 0 --out .\OpennessLLM\out\hmi-textlist-model-current
```

### hmi-screen-model-probe

Инспектирует Screen attributes/compositions без записи.

```cmd
.\OpennessLLM\run.cmd hmi-screen-model-probe --attach --attach-index 0 --out .\OpennessLLM\out\hmi-screen-model-current
```

### hmi-project-texts-probe

Read-only export ProjectTexts XLSX для анализа translation/import strategy.

```cmd
.\OpennessLLM\run.cmd hmi-project-texts-probe --attach --attach-index 0 --out .\OpennessLLM\out\hmi-project-texts-current
```

## 11. HMI guarded write path

Основной поддержанный HMI write path сейчас - ProjectTexts XLSX для выбранных
text-list/text changes. Blind XML import в основной проект не является
production workflow.

### hmi-import-probe-copy

Импортирует patched HMI XML только в копию проекта и сравнивает collateral
changes. Не должен использоваться как production apply.

```cmd
.\OpennessLLM\run.cmd hmi-import-probe-copy --project .\Project.ap21 --in .\CLONE_PROJECT\_hmi_preflight\patched-YYYYMMDD-HHMMSS --out .\CLONE_PROJECT
```

Команда создает/открывает отдельную копию проекта. Нельзя использовать вместе с
`--attach`.

### hmi-project-texts-import-probe-copy

Импортирует patched ProjectTexts XLSX только в копию проекта и проверяет
collateral.

```cmd
.\OpennessLLM\run.cmd hmi-project-texts-import-probe-copy --project .\Project.ap21 --in .\CLONE_PROJECT\_hmi_preflight\patched-YYYYMMDD-HHMMSS --out .\CLONE_PROJECT
```

Это обязательная репетиция перед production `hmi-project-texts-apply`.

### hmi-project-texts-apply-preflight

Строит guarded apply preflight для ProjectTexts XLSX без записи в открытый
проект.

```cmd
.\OpennessLLM\run.cmd hmi-project-texts-apply-preflight --attach --attach-index 0 --in .\CLONE_PROJECT\_hmi_preflight\patched-YYYYMMDD-HHMMSS --out .\CLONE_PROJECT --language ru-RU
```

Пишет:

```text
hmi-project-texts-apply-preflight-summary.txt
hmi-project-texts-apply-preflight-targets.csv
hmi-project-texts-apply-preflight-live-diff.csv
hmi-project-texts-apply-preflight-gate.csv
_hmi_project_texts_apply_preflight\preflight-*\...
```

### hmi-project-texts-apply

Production guarded HMI ProjectTexts apply. Требует `--apply`.

```cmd
.\OpennessLLM\run.cmd hmi-project-texts-apply --attach --attach-index 0 --in .\CLONE_PROJECT\_hmi_preflight\patched-YYYYMMDD-HHMMSS --out .\CLONE_PROJECT --language ru-RU --apply
.\OpennessLLM\run.cmd hmi-project-texts-apply --attach --attach-index 0 --in .\CLONE_PROJECT\_hmi_preflight\patched-YYYYMMDD-HHMMSS --out .\CLONE_PROJECT --language ru-RU --apply --save
```

Для source-language import дополнительно требуется:

```cmd
--update-source-language
```

Команда проверяет:

```text
есть ли accepted copy-only rehearsal;
чистый ли live HMI baseline;
нет ли unexpected collateral;
разрешен ли target/source language режим;
создан ли backup;
accepted ли post-apply diff.
```

Ключевые отчеты:

```text
hmi-project-texts-apply-summary.txt
hmi-project-texts-apply-targets.csv
hmi-project-texts-apply-live-diff.csv
hmi-project-texts-apply-object-diff.csv
hmi-project-texts-apply-collateral.csv
hmi-project-texts-apply-gate.csv
hmi-project-texts-apply-copy-gate.csv
```

## 12. Рекомендуемые стартовые команды для LLM

Для любой новой сессии:

```cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd --help
.\OpennessLLM\run.cmd self-test
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT
```

Для PLC блока:

```cmd
.\OpennessLLM\run.cmd block-info --name <block-name> --out .\CLONE_PROJECT
```

Для HMI:

```cmd
.\OpennessLLM\run.cmd hmi-check --attach --attach-index 0 --out .\CLONE_PROJECT
```

Если команда не описана здесь, сначала смотреть `--help`, потом README, и только
после этого читать `Program.cs`.
