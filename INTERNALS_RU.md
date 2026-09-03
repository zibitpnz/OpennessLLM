# OpennessLLM Internals

Подробное описание того, что `OpennessLLM` делает "под капотом": как он
подключается к TIA Portal, какие данные считает источником истины, какие связи
проверяет, как строит preflight/gates и почему иногда блокирует запись.

Создано: `Zibitpnz`.

Документ предназначен для человека и LLM. Он не заменяет код, но дает рабочую
ментальную модель, чтобы не читать весь `Program.cs` перед каждой задачей.

## 1. Главная идея архитектуры

`OpennessLLM` не пытается сделать LLM прямым генератором TIA XML. Вместо этого
он строит промежуточный слой:

```text
TIA Portal project
  -> read-only snapshots
  -> compact reports and metadata
  -> local editable workspace
  -> preflight/gates
  -> explicit guarded write
  -> post-check and baseline acceptance
```

LLM должна работать преимущественно с:

```text
CLONE_PROJECT\_root\...              PLC source files
CLONE_PROJECT\_metadata\...          machine-readable PLC metadata
CLONE_PROJECT\*.csv                  human/LLM-readable reports
CLONE_PROJECT\_runtime_maps\...      PLC runtime DB offset maps
CLONE_PROJECT\_runtime_snapshots\... PLC runtime value captures
CLONE_PROJECT\_hmi_metadata\digest\  compact HMI indexes
CLONE_PROJECT\*_summary.txt          decisions and verdicts
```

Прямой TIA SDK доступ, XML import/export, compile providers и project save
остаются внутри инструмента и защищены командами/gates.

## 2. Слои инструмента

Условно программа состоит из таких слоев:

```text
CLI layer
  Парсит команду и общие параметры.

Command classification layer
  Решает, команда local-only, read-only, copy-only probe или write.

Project/API resolution layer
  Находит *.apXX, определяет версию проекта и подбирает Siemens PublicAPI.

TIA session layer
  Attach к открытому TIA Portal или headless open project.

Inventory layer
  Обходит Project.DeviceGroups, devices, software, PLC blocks, tags, HMI targets.

PLC clone layer
  Создает CLONE_PROJECT, source files, metadata и diff/check reports.

PLC apply layer
  Строит план изменений, preflight gates, применяет через External Sources.

PLC runtime layer
  Подключается к живому PLC по S7comm / ISO-on-TCP, строит карты DB offsets,
  читает переменные, снимает read-only snapshots и выполняет строго guarded
  runtime-запись.

HMI snapshot/digest layer
  Экспортирует HMI XML и превращает его в компактные CSV/JSON/Markdown.

HMI apply strategy layer
  Проверяет patch, collateral, copy-only rehearsal и ProjectTexts XLSX apply.

Compiler diagnostics layer
  Вызывает TIA CompileProvider и печатает рекурсивные compiler messages.

Self-test layer
  Проверяет offline части без TIA Portal.
```

## 3. Источники истины

В разные моменты workflow источником истины являются разные сущности.

### Live TIA project

Источник истины для текущего реального проекта:

```text
открытый TIA Portal project;
blocks, tags, devices, HMI objects;
compile state;
hidden engineering links.
```

Команды `check-clone`, `hmi-check`, `compile-*`, `status` читают live TIA
project.

### CLONE_PROJECT

Источник истины для локальной рабочей копии:

```text
CLONE_PROJECT\_root\...
CLONE_PROJECT\_metadata\blocks.jsonl
CLONE_PROJECT\plc-blocks.csv
CLONE_PROJECT\clone-check-blocks.csv
```

PLC source edits должны идти через `CLONE_PROJECT\_root`, а не через сырой XML.

### Runtime maps

Источник истины для runtime-чтения/записи переменных PLC:

```text
CLONE_PROJECT\_runtime_maps\plc-runtime-map.csv
CLONE_PROJECT\_runtime_maps\plc-runtime-map.md
CLONE_PROJECT\_runtime_maps\DB_*.md
CLONE_PROJECT\_runtime_maps\plc-runtime-map-summary.txt
```

Эти файлы создаются командой `plc-runtime-map` из `CLONE_PROJECT\_root`,
`plc-blocks.csv` и sidecar metadata. Карта включает classic non-optimized
Global DB из `.db` файлов и Instance DB через связанный FB. Они не заменяют live
TIA project: если структура FB/DB изменилась, карту нужно перестроить.

### Runtime snapshots

Источник истины для конкретного runtime-среза значений PLC:

```text
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-summary.txt
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-values.csv
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-values.md
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-values.json
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-raw.hex
CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-read-ranges.csv
```

Эти файлы создаются командой `plc-runtime-snapshot`. Они являются
диагностическим снимком момента чтения, а не source baseline.

### HMI digest

Источник истины для LLM-анализа HMI:

```text
CLONE_PROJECT\_hmi_metadata\digest\hmi-screen-items.csv
CLONE_PROJECT\_hmi_metadata\digest\hmi-screen-bindings.csv
CLONE_PROJECT\_hmi_metadata\digest\hmi-event-handlers.csv
CLONE_PROJECT\_hmi_metadata\digest\hmi-text-list-items.csv
CLONE_PROJECT\_hmi_metadata\digest\screens\*.md
```

Сырой HMI XML является полным snapshot, но не первым форматом для LLM.

### Reports

Источник истины для решений gates:

```text
*_summary.txt
*_gate.csv
*_issues.csv
*_collateral.csv
*_objects.csv
```

Если отчет говорит `blocked`, `failed`, `error`, `unexpected collateral`,
`source blocker`, `stale`, `duplicate`, это важнее предположений LLM.

## 4. Разбор команды и режимов

При запуске CLI делает:

```text
1. Парсит имя команды.
2. Парсит общие параметры: --project, --api-dir, --attach, --out, --in и т. д.
3. Проверяет, известна ли команда.
4. Если команда local-only, выполняет ее без TIA.
5. Иначе разрешает project/API и открывает/attach TIA session.
6. Если команда write, требует явное --apply для реального действия.
```

Local-only команды не требуют project file:

```text
version
self-test
block-info
hmi-digest
hmi-apply-preflight
sync-clone
clean-local
plc-runtime-probe
plc-runtime-map
plc-runtime-read
plc-runtime-snapshot
```

`plc-runtime-probe`, `plc-runtime-read` и `plc-runtime-snapshot` local-only
только с точки зрения TIA: они не открывают Portal, но подключаются к живому PLC
по TCP/102.

Write-команды:

```text
apply-clone
compile-block
compile-all
delete-block
set-attribute
create-test-visual-fb
hmi-project-texts-apply
```

Отдельно стоит `plc-runtime-write`: она не пишет в TIA project, но может менять
значения в живом PLC. Для реальной записи нужны оба флага
`--apply --i-know-this-writes-plc`; без них команда обязана быть dry-run.

## 5. Project/API resolution

Если команда требует TIA project, инструмент должен понять:

```text
какой *.apXX проект использовать;
какая версия TIA Portal нужна;
где лежит Siemens.Engineering PublicAPI;
как открыть проект: attach или headless.
```

Логика:

```text
--project указан
  -> используется он.

--project не указан
  -> инструмент ищет единственный *.apXX рядом с текущей папкой проекта.

Найдено несколько *.apXX
  -> команда блокируется и просит явный --project.

Project extension *.ap21
  -> ожидается PublicAPI V21.

Project extension *.ap20
  -> ожидается PublicAPI V20.
```

PublicAPI ищется через:

```text
--api-dir
TIA_OPENNESS_API_DIR
registry / installed Portal locations
standard Portal path under C:\Program Files\Siemens\Automation\Portal VXX\PublicAPI\VXX\net48
legacy Portal path under C:\Program Files\Siemens\Automation\Portal VXX\PublicAPI\VXX
```

Если версия API не совпадает с версией проекта, команда блокируется. Это
важно: TIA Openness assemblies version-sensitive.

С версии `0.10.6` резолвер API принимает две раскладки Siemens assemblies:
новую `Siemens.Engineering.Base.dll` и legacy `Siemens.Engineering.dll`.
Legacy path нужен для машин с TIA Portal V20, где PublicAPI может лежать без
подкаталога `net48`.

## 6. TIA session model

Есть два рабочих режима:

```text
--attach
  Подключиться к уже открытому TIA Portal process.

--headless / default open
  Открыть проект из файла через TIA Openness.
```

Если открыто несколько TIA процессов:

```cmd
--attach-index <n>
```

Copy-only HMI import probes не используют `--attach`, потому что они создают и
открывают отдельную копию проекта. Это защищает основной проект от test import.

## 7. Inventory: как инструмент видит проект

Inventory layer обходит проект через TIA Openness SDK и строит внутренний
snapshot.

Для PLC собираются:

```text
devices и device items;
software containers;
PLC software;
block groups, включая nested groups;
blocks;
tag tables;
tags;
attributes блоков.
```

Для HMI собираются:

```text
HMI targets;
screens и screen folders;
tag tables;
text lists;
graphic lists;
scripts;
connections;
runtime object type names;
SDK object references для export/probe.
```

Ключевой момент: traversal должен обходить не только корневые devices, но и
`Project.DeviceGroups`, иначе проекты с grouped devices будут видны неполно.

## 8. PLC metadata model

Для каждого PLC блока инструмент старается сохранить:

```text
Name
GroupPath
TypeName
BlockKind
ProgrammingLanguage
Number
NumberSpace
NumberMode
AutoNumber
InstanceOfName
SourcePath
SourceSha256
CurrentSourceSha256
ExportStatus
CheckStatus
```

Почему это нужно:

```text
Name/GroupPath      найти блок и сохранить group structure.
NumberSpace         отличать FB5 от DB5.
NumberMode          понимать manual/auto numbering.
InstanceOfName      защитить Instance DB связи.
SourceSha256        понять, менялся ли clone file.
CurrentSourceSha256 понять, менялся ли live TIA source после check-clone.
CheckStatus         принять решение: unchanged/changed/added/removed/blocker.
```

Machine-readable view:

```text
CLONE_PROJECT\_metadata\blocks.jsonl
CLONE_PROJECT\_metadata\groups.jsonl
CLONE_PROJECT\_metadata\clone-manifest.json
```

Human-readable view:

```text
CLONE_PROJECT\plc-blocks.csv
CLONE_PROJECT\clone-check-blocks.csv
```

## 9. init-clone: что происходит

`init-clone` создает PLC workspace.

Под капотом:

```text
1. Собирает live inventory.
2. Создает CLONE_PROJECT\_root.
3. Создает nested folders по PLC block groups.
4. Для каждого поддержанного блока генерирует source file через ExternalSourceGroup.GenerateSource().
5. Считает SHA-256 source files.
6. Пишет plc-blocks.csv.
7. Пишет _metadata\blocks.jsonl и clone-manifest.json.
8. Создает начальный check report.
```

Если source export невозможен, блок не должен молча считаться безопасным для
write workflow. Он получает export/source blocker status.

## 10. check-clone: как строится diff

`check-clone` сравнивает live TIA project с локальным `CLONE_PROJECT`.

Под капотом:

```text
1. Собирает live inventory.
2. Экспортирует live source для блоков, где это возможно.
3. Считает live source SHA-256.
4. Читает clone metadata baseline.
5. Читает текущие files в CLONE_PROJECT\_root.
6. Сравнивает baseline, live TIA и clone files.
7. Пишет block/group/source-blocker/workspace-inventory/summary reports во временный staging.
8. Atomic replace публикует отчёты, затем последним записывает
   `clone-check-bundle.json` с schema/run ID, row counts, SHA-256, точным
   compare directory, normalized project identity, выбранным `SoftwarePath` и
   хешами всех source/sidecar/manifest/metadata файлов.
9. `apply-clone` / `sync-clone` принимают только полностью проверенный bundle.
```

До invalidation старого bundle и создания `_compare` команда проверяет, что
выбран ровно один `PlcSoftware` и у него доступен `ExternalSourceGroup`. Ошибка
scope поэтому не меняет существующий workspace.

Типовые статусы:

```text
unchanged       TIA, baseline и clone file согласованы.
changed         clone source отличается от baseline или live source.
added           блок есть в TIA, но не был в baseline, или clone-only file.
removed         блок был в baseline, но отсутствует в TIA или clone.
source-blocker  source export/check невозможен или небезопасен.
unsupported     объект не поддержан текущим workflow.
```

`check-clone` не является write-командой. Он готовит доказательства для
последующего `apply-clone`.

## 11. sync-clone: принятие PLC baseline

`sync-clone` не открывает TIA Portal и не пишет в проект. Он локально принимает
последний результат `check-clone` как новый baseline `CLONE_PROJECT`.

Что обновляется:

```text
CLONE_PROJECT\plc-blocks.csv;
CLONE_PROJECT\_metadata\blocks.jsonl;
CLONE_PROJECT\_metadata\clone-manifest.json;
source files under CLONE_PROJECT\_root.
```

Если блок был создан в TIA Portal и впервые появился в `check-clone` как
project-side added block, `sync-clone` должен перенести в baseline полный
identity record, включая `SoftwarePath`. Начиная с `0.12.2`, это поле
сохраняется и в `plc-blocks.csv`, и в `_metadata\blocks.jsonl`.

Файловые операции выполняются не над рабочим `_root`, а над полной копией в
`_sync-staging`. Там же заранее строятся новые manifests и metadata. При любой
ошибке staging удаляется, команда возвращает non-zero, а старые `_root`,
manifests, metadata и bundle остаются неизменными. Commit сначала переносит
старое состояние в `_sync-backups`; если установка нового состояния не
завершилась, выполняется rollback.

Это важно для:

```text
block-info lookup;
apply-clone gates;
проектов с несколькими PLC software targets;
корректного отличия project-side added block от clone-only source.
```

## 12. block-info: почему LLM не должна искать номера вручную

`block-info` строит lookup index из локальных metadata/report файлов:

```text
_metadata\blocks.jsonl
plc-blocks.csv
clone-check-blocks.csv
```

Он умеет искать:

```text
по точному имени блока;
по stem имени файла, например 5_HM или 5_HM.db;
по номеру;
по номеру и NumberSpace;
по group path.
```

Почему это лучше ручного поиска:

```text
номер блока может повторяться в разных spaces;
filename может содержать numeric prefix, но TIA block name другой;
baseline и latest check status лежат в разных файлах;
LLM экономит токены и время;
логика поиска единая и проверяется self-test.
```

## 13. apply-clone: общий pipeline

`apply-clone` - основной PLC write workflow.

Pipeline:

```text
1. Прочитать и проверить atomic clone-check bundle.
2. Собрать live inventory и до плана сверить project path/version/object ID и
   единственный `SoftwarePath` с bundle.
3. Прочитать CLONE_PROJECT baseline и текущие clone files.
4. Построить apply plan только для проверенного PlcSoftware.
5. Классифицировать операции: update/create/delete/rename/noop/blocker.
6. Запустить preflight checks.
7. Записать preflight reports.
8. Если dry-run, остановиться до TIA writes.
9. Если --apply, выполнить before-write gates.
10. Создать backup, если требуется.
11. Проверить live source drift для изменяемых blocks.
12. Применить операции через TIA SDK / External Sources.
13. Проверить результат в изолированной копии workspace: post-check, staged
    sync, затем второй полностью чистый post-check.
14. Перестроить source paths/manifests/metadata только в staging.
15. Сохранить TIA проект (real apply без --save запрещён).
16. Транзакционно опубликовать `_root`, manifests и metadata с rollback backup.
17. Только после save/publish выпустить свежий authorization bundle.
```

Ключевые отчеты:

```text
apply-clone-preflight-summary.txt
apply-clone-preflight-plan.csv
apply-clone-preflight-issues.csv
apply-clone-summary.txt
apply-clone-gate.csv
apply-clone-operations.csv
_apply-reports\apply-clone-preflight-plan.jsonl
_apply-reports\apply-clone-preflight-issues.jsonl
_apply-reports\apply-clone-gate.jsonl
_apply-reports\apply-clone-operations.jsonl
```

## 14. apply-clone plan: какие операции распознаются

Поддержанные операции:

```text
UpdateSource     Обновить source существующего блока.
CreateBlock      Создать новый clone-only блок.
DeleteBlock      Удалить блок, если gates разрешают.
RenameBlock      Переименовать блок внутри той же group.
Noop             Нет изменений.
Blocked          Небезопасная или неподдержанная ситуация.
```

Новые блоки обязаны задавать metadata через sidecar:

```text
MyNewBlock.scl
MyNewBlock.scl.meta.json
```

Поддерживаемые sidecar поля:

```text
blockKind
numberMode
number
autoNumber
programmingLanguage
name
instanceOfName
softwarePath
sourceOrigin
```

Для source, которого нет в `plc-blocks.csv`, безопасное происхождение по
умолчанию — `unknown-orphaned`. Только точное sidecar-значение
`sourceOrigin=explicit-new-local-source` подтверждает намеренно добавленный
новый локальный source, причём в том же валидном flat JSON обязателен непустой
`softwarePath`. Malformed/nested sidecar, потеря или неполнота manifest не дают
этого исключения; loose source также не наследует первый software path из manifest.

Это one-shot provenance: `check-clone` сам по совпадению metadata ничего не
промоутит. Только успешный `CreateBlock` создаёт receipt с check run ID,
SoftwarePath, target identity, source hash/language и live object identity.
Экспортированный live source обязан совпасть по language и canonical hash.
One-to-one batch затем через восстанавливаемый `_manifest-publish` переводит
sidecar в `tracked-baseline` и публикует manifest. При последующей потере
manifest такой source становится `unknown-orphaned`, а не снова explicit-new.

`plc-blocks.csv` содержит отдельный durable `SourceOrigin`:

```text
exported-source                source действительно экспортировался;
inventory-only-unsupported     source никогда не создавался из-за языка.
```

Изменение одного mutable `Status` не стирает историю. Legacy или
противоречивые missing-source строки становятся `unknown-orphaned`.

Если sidecar отсутствует, numeric prefix filename может быть распознан как
manual number для диагностики, но CreateBlock не разрешается.

## 15. PLC checks внутри apply-clone

### Source blocker check

Блокирует запись, если source round-trip небезопасен:

```text
source не экспортируется;
unsupported language;
LAD/FBD/GRAPH не подтвержден;
непонятный block kind;
metadata неполная.
```

### Stale source check

Перед real apply инструмент повторно экспортирует live source для изменяемых
блоков и сравнивает SHA с `CurrentSourceSha256` из последнего `check-clone`.

Если отличается:

```text
TIA изменился после check-clone;
clone apply может потереть чужую/ручную правку;
apply блокируется.
```

### Duplicate number check

Проверяет финальное состояние номеров после всех операций.

Важно: проверка идет по number spaces:

```text
FB
FC
DB
OB
```

`FB5` и `DB5` не конфликтуют, но два `FB5` конфликтуют.

### Group move check

Автоматический move между PLC block groups запрещен. Rename внутри той же group
поддерживается, move между groups требует ручного действия в TIA Portal и
последующего `sync-clone`.

### Instance DB check

Проверяет:

```text
referenced FB существует;
InstanceOfName не меняется опасно;
Instance DB применяются после FB;
удаление FB не оставляет опасные Instance DB связи.
```

## 16. HMI snapshot: почему XML все равно нужен

TIA Openness экспортирует HMI объекты в XML. Поэтому полный read-only snapshot
создается через:

```cmd
hmi-export-xml
hmi-init-clone
hmi-check
```

Но XML не должен быть основным форматом для LLM. Он:

```text
большой;
тяжелый для контекста;
чувствителен к hidden/internal attributes;
опасен как прямой объект генерации.
```

Поэтому следующий слой - `hmi-digest`.

## 17. HMI digest: как XML становится пригодным для анализа

`hmi-digest` читает exported XML и строит компактные индексы:

```text
hmi-xml-files.csv
hmi-screen-items.csv
hmi-screen-bindings.csv
hmi-event-handlers.csv
hmi-tag-details.csv
hmi-text-list-items.csv
hmi-digest.json
screens\*.md
```

Digest извлекает:

```text
экраны;
screen items;
геометрию;
тексты;
bindings;
events;
tags;
text list entries;
relative XML paths;
comparable hashes.
```

Comparable hash старается игнорировать технические volatile поля вроде Created,
чтобы не считать каждый export значимым изменением.

## 18. hmi-check: сравнение HMI baseline и live snapshot

`hmi-check` делает:

```text
1. Экспортирует текущий HMI XML во временный compare directory.
2. Строит current HMI manifest/digest.
3. Сравнивает current snapshot с CLONE_PROJECT\_hmi baseline.
4. Пишет hmi-check-objects.csv и hmi-check-summary.txt.
```

Статусы помогают понять:

```text
какие HMI XML объекты unchanged;
какие изменились;
какие появились/исчезли;
где export/parse blockers;
можно ли делать HMI preflight/apply.
```

Если `hmi-check` dirty, HMI write workflow должен остановиться до acceptance или
разбора diff.

## 19. hmi-sync-clone: acceptance baseline

`hmi-sync-clone` не пишет в TIA Portal. Он принимает текущий live HMI snapshot в
`CLONE_PROJECT`.

Под капотом:

```text
1. Делает current HMI snapshot.
2. Проверяет blockers.
3. Создает backup старого HMI baseline.
4. Заменяет _hmi и _hmi_metadata.
5. Запускает verification hmi-check.
6. Пишет sync summary/json/report.
```

Это не "починить ошибку". Это инженерное решение: текущее HMI состояние
становится новым baseline.

## 20. HMI patch preflight

`hmi-apply-preflight` - local-only команда. Она не открывает TIA Portal и не
импортирует XML.

Под капотом:

```text
1. Читает HMI baseline digest из CLONE_PROJECT.
2. Читает hmi-check-objects.csv, чтобы убедиться, что target clean.
3. Читает JSONL patch.
4. Валидирует каждую patch operation.
5. Копирует _hmi в _hmi_preflight\patched-*.
6. Применяет DOM patch только к локальной XML копии.
7. Повторно строит digest для patched snapshot.
8. Сравнивает expected changes с actual digest changes.
9. Пишет plan/issues/collateral.
```

Если collateral unexpected, нельзя идти к import strategy.

## 21. Поддерживаемые HMI patch concepts

Текущая preflight-модель работает с ограниченным набором операций:

```text
set-text-list-entry
set-screen-item-text
set-attribute для selected geometry attributes
set-link для selected link kinds
set-event-parameter
duplicate-screen-items
move-screen-items
```

Если patch просит неподдержанную операцию, preflight пишет issue:

```text
UNSUPPORTED_OPERATION
UNSUPPORTED_OBJECT
UNSUPPORTED_ATTRIBUTE
UNSUPPORTED_LINK
```

Это намеренно. Лучше явно расширять allowlist, чем разрешить LLM произвольный
XML patch.

## 22. Почему HMI ProjectTexts XLSX стал production write path

Прямой `TextLists.Import(...Override)` или blind XML import оказались слишком
рискованными:

```text
может заменять объект целиком;
может затронуть hidden links;
может дать collateral changes;
не всегда понятно, что именно будет изменено.
```

ProjectTexts XLSX лучше для текстовых изменений:

```text
экспортирует переводимые texts;
позволяет точечно изменить target culture cells;
работает через штатный ProjectTexts import path;
можно репетировать на копии проекта;
можно сравнить before/after HMI digest.
```

Поэтому production HMI write path сейчас:

```text
hmi-apply-preflight
hmi-project-texts-import-probe-copy
hmi-project-texts-apply-preflight
hmi-project-texts-apply --apply
hmi-check
hmi-sync-clone после acceptance
```

## 23. HMI ProjectTexts import probe on copy

Copy-only rehearsal делает:

```text
1. Берет patched preflight directory.
2. Создает отдельную копию TIA project.
3. Экспортирует ProjectTexts XLSX before.
4. Патчит XLSX target culture cells.
5. Импортирует XLSX в копию проекта.
6. Экспортирует HMI XML after из копии.
7. Строит digest/diff.
8. Пишет target/collateral reports.
```

Команда не должна использовать `--attach`, потому что attach означал бы работу с
основным открытым проектом.

## 24. HMI ProjectTexts apply final gates

Перед import в основной проект проверяется:

```text
explicit --apply;
--in patched directory существует;
target language задан;
backup policy разрешена;
live HMI baseline clean;
copy-only rehearsal accepted;
patched dir совпадает с rehearsal;
target/source culture mode разрешен;
source-language update требует --update-source-language;
unexpected collateral отсутствует.
```

После import проверяется:

```text
after HMI export;
after digest;
target rows changed as expected;
object diff accepted;
collateral accepted;
gate summary accepted;
save policy.
```

Если post-apply rejected, команда падает и указывает summary. Это значит, что
импорт был выполнен, но результат не принят gates; требуется инженерный разбор.

## 25. Compiler diagnostics internals

`compile-block`:

```text
находит PLC block;
получает CompileProvider;
без --apply показывает dry-run;
с --apply вызывает Compile();
печатает CompilerResult.
```

`compile-all`:

```text
сначала ищет самый широкий compile target;
пытается project-level CompileProvider;
если project-level недоступен, ищет compile-capable software targets;
обычно это PLC software и HMI runtime software;
компилирует каждый target;
суммирует errors/warnings.
```

Compiler messages печатаются рекурсивно, потому что TIA SDK часто кладет
реальное описание ошибки во вложенные `CompilerResultMessage.Messages`, а
верхний уровень содержит только aggregate state.

Печатаются:

```text
State
ErrorCount
WarningCount
Path
DateTime
Description
nested messages
```

Если errors > 0, команда завершается ошибкой. `--save` выполняется только при
zero errors.

## 26. Reports as API для LLM

Для LLM отчеты являются public API инструмента. Их нужно предпочитать чтению
`Program.cs`.

PLC:

```text
plc-blocks.csv
clone-check-blocks.csv
clone-check-summary.txt
apply-clone-preflight-plan.csv
apply-clone-preflight-issues.csv
apply-clone-gate.csv
apply-clone-summary.txt
```

PLC runtime:

```text
_runtime_maps\plc-runtime-map.csv
_runtime_maps\plc-runtime-map.md
_runtime_maps\DB_*.md
_runtime_maps\plc-runtime-map-summary.txt
_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-summary.txt
_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-values.csv
_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-values.md
_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-values.json
_runtime_snapshots\YYYYMMDD-HHMMSS\snapshot-read-ranges.csv
```

HMI:

```text
hmi-check-summary.txt
hmi-check-objects.csv
_hmi_metadata\digest\*.csv
hmi-apply-preflight-plan.csv
hmi-apply-preflight-issues.csv
hmi-apply-preflight-collateral.csv
hmi-project-texts-*-summary.txt
hmi-project-texts-*-gate.csv
hmi-project-texts-*-collateral.csv
```

Status:

```text
tool-status-summary.txt
tool-status.json
workspace-init-summary.txt
workspace-init.json
```

## 27. Error philosophy

Инструмент предпочитает fail closed:

```text
если связь непонятна - blocked;
если source stale - blocked;
если collateral unexpected - blocked;
если language unsupported - blocked;
если API version mismatch - blocked;
если несколько project candidates - blocked;
если command could write but нет --apply - dry-run или error.
```

Это сделано специально для LLM workflow. Лучше остановиться и попросить
инженерный разбор, чем молча сделать опасную запись.

## 28. Self-test coverage

`self-test` проверяет offline части:

```text
HMI digest basics;
comparable hash behavior;
JSONL patch parser;
HMI apply preflight fixture;
screen item geometry move;
ProjectTexts XLSX path handling;
CSV unicode/quote roundtrip;
portable project/API resolution helpers;
block-info lookup index;
sync-clone SoftwarePath metadata acceptance;
clean-local classification;
HMI ProjectTexts final gates;
apply-clone gates;
canonical source formatting.
```

Self-test не заменяет real TIA integration run, но быстро ловит регрессии в
parser/gate/report логике.

## 29. Когда читать Program.cs

Читать код нужно, если:

```text
команда ведет себя не так, как описано;
нужно добавить новую команду;
нужно расширить HMI patch allowlist;
нужно изменить gate;
нужно проверить конкретный SDK reflection path;
self-test failed и отчетов недостаточно.
```

Не читать весь `Program.cs` для обычной работы с проектом. Сначала:

```cmd
.\OpennessLLM\run.cmd --help
.\OpennessLLM\run.cmd status --attach --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd block-info --name <block> --out .\CLONE_PROJECT
```

## 30. Практическая карта "что проверяет инструмент"

PLC:

```text
проект/API version;
наличие TIA session;
видимость Project.DeviceGroups;
block group path;
block name and file stem;
block number and number space;
manual/auto number mode;
source export status;
source file SHA;
live source SHA;
clone baseline freshness;
source blockers;
rename vs move;
delete safety;
Instance DB -> FB relationship;
duplicate final numbers;
compile errors/warnings.
```

HMI:

```text
HMI target visibility;
XML export status;
XML parse status;
object relative paths;
digest comparable hashes;
hmi-check clean/dirty status;
patch selector uniqueness;
supported operation/object/attribute/link;
target object clean in hmi-check;
expected vs actual digest changes;
unexpected collateral;
copy-only import rehearsal;
ProjectTexts target/source culture mode;
post-apply object/collateral diff.
```

Local/tooling:

```text
portable file set;
build output;
self-test regression status;
generated artifacts classification;
workspace transient artifacts;
version command and help surface.
```

## 31. PLC runtime internals

Runtime-слой добавлен для чтения фактических значений из живого PLC без TIA
Portal. Он не заменяет TIA Openness: Openness остается инженерным каналом для
проекта, runtime-доступ нужен для диагностики и точечной guarded записи.

### S7 runtime client

`S7RuntimeClient` реализован внутри `Program.cs` без внешних зависимостей:

```text
TCP connect к port 102;
COTP connect;
S7 setup communication;
S7 ReadVar для DB bytes;
S7 WriteVar для DB bytes.
```

Параметры подключения:

```text
--host
--rack
--slot
--connection-type
--timeout-ms
```

Параметры подключения задаются по следующей схеме. Адрес ниже взят из
документационного диапазона и должен быть заменен адресом целевого PLC:

```text
host 192.0.2.10
rack 0
slot 2
TCP 102
```

Чтения лучше выполнять последовательно: WinAC может закрывать параллельные
S7-подключения.

### Runtime map builder

`plc-runtime-map` строит карту из локального clone:

```text
CLONE_PROJECT\plc-blocks.csv;
CLONE_PROJECT\_root\**\*.scl;
CLONE_PROJECT\_root\**\*.db;
CLONE_PROJECT\_root\**\*.meta.json.
```

Если source-файл уже есть в `plc-blocks.csv`, используется строка манифеста.
Если файл есть в `_root`, но еще отсутствует в CSV, он подхватывается через
sidecar metadata. Это важно после ручного добавления новых блоков в clone.
Поиск под `_root` рекурсивный: блоки в TIA block groups не должны выпадать из
карты только из-за того, что лежат не в корне clone.

Карта сохраняется в два места:

```text
OpennessLLM\out\plc-runtime-map-current\...
CLONE_PROJECT\_runtime_maps\...
```

В `CLONE_PROJECT\_runtime_maps` пишутся:

```text
plc-runtime-map.csv      machine-readable map для read/write;
plc-runtime-map.md       общая Markdown-карта;
DB_*.md                  человекочитаемая карта по каждому Global DB / Instance DB;
plc-runtime-map-summary.txt.
```

### Classic DB layout rules

Расчет предназначен для classic non-optimized Global DB и Instance DB.

Поддержанные правила:

```text
Bool пакуется по битам в текущем байте;
перед не-Bool выполняется byte alignment;
Word, Int, DWord, DInt, Real, Any и system FB выравниваются на четный байт;
границы секций FB VAR_INPUT / VAR_OUTPUT / VAR_IN_OUT / VAR выравниваются на четный байт;
Global DB Data-секция считается непрерывной структурой без FB section-boundary alignment;
VAR_TEMP и VAR CONSTANT не занимают память instance DB и не попадают в карту;
Struct раскрывается рекурсивно, включая Struct внутри Struct;
Array[... ] of Byte поддерживается;
вложенный FB раскрывается через его SCL declaration;
TCON, TDISCON, TSEND, TRCV учитываются как system FB известных размеров;
quoted DB field names вроде "Source__Target_busy" поддерживаются и пишутся в карту без кавычек.
```

Проверенный контрольный случай:

```text
DB_Test_Outputs.Client                  offset 184
DB_Test_Outputs.CurrentStep             offset 1274
DB_Test_Outputs.ClientExecute           offset 1276.0
DB_Test_Outputs.ClientStart             offset 1278
DB_Test_Outputs.BitCommandMaskValue     offset 1362
DB_Test_Outputs.OutputMaskFeedbackValue offset 1374
```

Если в карте появляются `unknown-type`, ее нельзя использовать для записи, пока
тип не разобран или не добавлен в known-size/known-layout правила.

### Runtime read

`plc-runtime-read`:

```text
1. Читает plc-runtime-map.csv.
2. Находит DB по имени или номеру.
3. Находит VariablePath.
4. Читает минимальный диапазон DB bytes.
5. Декодирует Bool, Byte, Word, Int, DWord, DInt или Real.
6. Печатает value и raw hex.
```

Это чтение значения из instance DB PLC, а не прямой Modbus-опрос внешнего
модуля. Для модулей ввода/вывода это правильно: функциональный блок уже
положил в DB свои входы, выходы, feedback и диагностику.

### Runtime snapshot

`plc-runtime-snapshot`:

```text
1. Читает plc-runtime-map.csv.
2. Выбирает один DB, все DB, список переменных или byte-range.
3. Вычисляет непрерывный диапазон чтения для каждого DB.
4. Делит диапазон на S7 ReadVar chunks до --max-read-bytes, default 222.
5. Читает chunks последовательно через одно S7-подключение.
6. Собирает локальный byte buffer.
7. Декодирует переменные из буфера по карте.
8. Пишет CSV/Markdown/JSON/raw HEX/read-ranges в _runtime_snapshots.
```

Поддержанные режимы выбора:

```text
--db <name-or-number>              полный DB;
--scope all                        все DB из карты, последовательно;
--vars A,B,C                       список переменных;
--var-list file.txt                файл со списком переменных;
--from A --to B                    диапазон между переменными;
--range start:size                 точный byte range.
```

Ограничение по времени:

```text
один S7 ReadVar chunk одного DB - самый близкий к "одному моменту" срез;
несколько chunks одного DB читаются последовательно;
несколько DB читаются последовательно;
snapshot-read-ranges.csv всегда показывает реальные chunks и статусы.
```

Если нужен строго один S7-запрос, используется `--single-read`; команда
завершается ошибкой, когда выбранный диапазон требует несколько chunks.

### Runtime write

`plc-runtime-write` - отдельный опасный режим. Она не пишет TIA project, но
пишет байты в живой PLC.

Fail-closed правила:

```text
без --apply запись не выполняется;
без --i-know-this-writes-plc запись не выполняется;
read-only строки карты не записываются;
неподдерживаемые типы не записываются;
Bool пишется read-modify-write одного байта;
после реальной записи выполняется read-back;
CommandMask / AllowedOutputMask выходных модулей не принимают биты выше 24.
```

LLM должна перед реальной runtime-записью показать человеку:

```text
DB;
VariablePath;
datatype;
offset;
старое значение;
новое значение;
raw bytes, которые будут записаны.
```

И выполнять `--apply --i-know-this-writes-plc` только после явного подтверждения.

## 32. Короткое правило для будущей LLM

Если нужно понять, почему инструмент что-то запретил:

```text
1. Найти summary report.
2. Найти gate/issue/collateral CSV.
3. Сопоставить code/status/message.
4. Проверить этот INTERNALS_RU.md.
5. Только потом читать Program.cs.
```

Если нужно изменить проект:

```text
read-only check
dry-run/preflight
прочитать reports
--apply только после clean gates
compile/check
sync baseline только после acceptance
```
