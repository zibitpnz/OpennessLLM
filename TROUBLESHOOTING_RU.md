# OpennessLLM Troubleshooting

Справочник по типовым проблемам при работе `OpennessLLM` с TIA Portal.

Общее правило: сначала сохранить текст ошибки, затем проверить `version`,
`--help`, `status`, relevant summary reports. Не исправлять проект вслепую.

## 1. TIA Portal не найден или нет running process

Симптомы:

```text
No running TIA Portal process was found.
Start TIA Portal or run without --attach.
```

Что делать:

```text
1. Открыть нужный проект в TIA Portal вручную.
2. Повторить команду с --attach.
3. Если открыто несколько TIA процессов, указать --attach-index.
```

Команды:

```cmd
.\OpennessLLM\run.cmd tree --attach --attach-index 0 --max 100
.\OpennessLLM\run.cmd tree --attach --attach-index 1 --max 100
```

Если не нужно подключаться к открытому TIA, использовать headless:

```cmd
.\OpennessLLM\run.cmd tree --headless --project .\Project.ap21 --max 100
```

## 2. Нет прав Siemens TIA Openness

Симптомы:

```text
access denied
Openness group
user is not allowed to access TIA Portal Openness
```

Что делать:

```cmd
.\OpennessLLM\enable-openness-admin.cmd
```

Запускать из elevated shell. Потом выйти из Windows и войти снова. Простого
перезапуска PowerShell часто недостаточно, потому что group membership читается
при входе пользователя.

## 3. Не найден `*.apXX` проект

Симптомы:

```text
Project file was not found.
Pass --project <path-to-project.apNN> or run from the project folder.
```

Что делать:

```cmd
.\OpennessLLM\run.cmd tree --project "C:\Path\Project.ap21" --headless --max 100
```

Если проект уже открыт:

```cmd
.\OpennessLLM\run.cmd tree --attach --attach-index 0 --max 100
```

## 4. Найдено несколько `*.apXX`

Симптомы:

```text
More than one TIA Portal project file was found.
Pass --project <path> to choose one explicitly.
```

Что делать:

```cmd
.\OpennessLLM\run.cmd status --attach --attach-index 0 --project "C:\Path\Project.ap21" --out .\CLONE_PROJECT
```

Правило: если в папке несколько проектов, всегда передавать `--project`.

## 5. Не найден TIA Openness PublicAPI

Симптомы:

```text
TIA Portal Openness PublicAPI directory was not found.
Use --api-dir or set TIA_OPENNESS_API_DIR.
```

Что делать:

```cmd
.\OpennessLLM\run.cmd tree --attach --api-dir "C:\Program Files\Siemens\Automation\Portal V21\PublicAPI\V21\net48" --max 100
.\OpennessLLM\run.cmd tree --attach --api-dir "C:\Program Files\Siemens\Automation\Portal V20\PublicAPI\V20" --max 100
```

Или задать переменную окружения:

```cmd
set TIA_OPENNESS_API_DIR=C:\Program Files\Siemens\Automation\Portal V21\PublicAPI\V21\net48
set TIA_OPENNESS_API_DIR=C:\Program Files\Siemens\Automation\Portal V20\PublicAPI\V20
```

Для PowerShell:

```powershell
$env:TIA_OPENNESS_API_DIR = "C:\Program Files\Siemens\Automation\Portal V21\PublicAPI\V21\net48"
$env:TIA_OPENNESS_API_DIR = "C:\Program Files\Siemens\Automation\Portal V20\PublicAPI\V20"
```

## 6. Версия PublicAPI не совпадает с проектом

Симптомы:

```text
TIA Openness API version V20 does not match project version V21.
Use a matching --api-dir.
```

Что делать:

```text
*.ap21 -> PublicAPI\V21\net48
*.ap20 -> PublicAPI\V20\net48
*.ap20 -> PublicAPI\V20
```

Для TIA Portal V20 допустима legacy-раскладка без `net48`, если в каталоге есть
`Siemens.Engineering.dll`. Начиная с `0.10.6`, инструмент поддерживает эту
раскладку наряду с `Siemens.Engineering.Base.dll`.

Команда:

```cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd tree --project .\Project.ap21 --api-dir "C:\Program Files\Siemens\Automation\Portal V21\PublicAPI\V21\net48" --max 100
```

## 7. PowerShell script execution disabled

Симптомы:

```text
running scripts is disabled on this system
ExecutionPolicy
```

Что делать:

Использовать `.cmd` wrappers:

```cmd
.\OpennessLLM\build.cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd self-test
```

PowerShell scripts являются удобством, но не обязательны.

## 8. Build fails

Базовая проверка:

```cmd
.\OpennessLLM\build.cmd
```

Если ошибка связана с C# syntax или missing method, смотреть последние изменения
в `Program.cs`.

Если ошибка связана с Siemens assemblies:

```text
проверить установлен ли TIA Portal;
проверить PublicAPI path;
проверить, что build script находит Siemens.Engineering.Base.dll;
проверить версию Portal.
```

После успешного build:

```cmd
.\OpennessLLM\run.cmd self-test
```

## 9. self-test failed

Симптомы:

```text
Failed: N
self-test summary shows failed cases
```

Что делать:

```text
1. Открыть self-test output directory.
2. Посмотреть self-test-summary.txt и self-test-results.csv.
3. Не работать с production write-командами, пока offline tests не понятны.
```

Команда:

```cmd
.\OpennessLLM\run.cmd self-test --out .\OpennessLLM\out\self-test-current
```

Типовые причины:

```text
сломали CSV/JSON parser;
сломали HMI digest;
сломали apply gates;
сломали local-only/write classification;
сломали block-info lookup.
```

## 10. status показывает Blocked

Команда:

```cmd
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT
```

Смотреть:

```text
CLONE_PROJECT\tool-status-summary.txt
CLONE_PROJECT\tool-status.json
CLONE_PROJECT\clone-check-summary.txt
CLONE_PROJECT\hmi-check-summary.txt
```

Типовые причины:

```text
CLONE_PROJECT не инициализирован;
PLC clone dirty;
HMI clone dirty;
есть source blockers;
HMI XML export/parse errors;
baseline отсутствует или устарел.
```

Если workspace отсутствует:

```cmd
.\OpennessLLM\run.cmd init-workspace --attach --attach-index 0 --out .\CLONE_PROJECT
```

Если изменения в TIA правильные и их нужно принять:

```cmd
.\OpennessLLM\run.cmd sync-clone --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd hmi-sync-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Но sync делать только после понимания diff.

## 11. block-info ничего не нашел

Команда:

```cmd
.\OpennessLLM\run.cmd block-info --name <name> --out .\CLONE_PROJECT
```

Что проверить:

```text
существует ли CLONE_PROJECT;
есть ли CLONE_PROJECT\_metadata\blocks.jsonl;
запускался ли init-clone/init-workspace;
не старый ли baseline;
правильно ли имя: TIA block name отличается от filename stem.
```

Обновить baseline:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd sync-clone --out .\CLONE_PROJECT
```

Если ищем по номеру, учитывать number space:

```cmd
.\OpennessLLM\run.cmd block-info --number 5 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd block-info --number 5 --number-space FB --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd block-info --number 5 --number-space DB --out .\CLONE_PROJECT
```

## 12. check-clone показывает changed/added/removed

Команда:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Смотреть:

```text
clone-check-summary.txt
clone-check-blocks.csv
```

Решения:

```text
Если изменения сделаны в clone и их нужно применить в TIA -> apply-clone.
Если изменения сделаны в TIA и правильные -> sync-clone.
Если изменения конфликтуют -> вручную объединить source/baseline.
```

Не делать `sync-clone`, если непонятно, откуда diff.

## 13. apply-clone preflight failed

Симптомы:

```text
apply-clone preflight failed with N error(s)
See apply-clone-preflight-issues.csv.
```

Смотреть:

```text
apply-clone-preflight-summary.txt
apply-clone-preflight-plan.csv
apply-clone-preflight-issues.csv
apply-clone-gate.csv
```

Типовые issue codes:

```text
CURRENT_SOURCE_STALE
CURRENT_SOURCE_HASH_MISSING
DUPLICATE_FINAL_NUMBER
VISUAL_SOURCE_UNVERIFIED
GROUP_MOVE_FORBIDDEN
INSTANCE_DB_*
SOURCE_BLOCKER
```

Решение зависит от issue. Не пытаться обойти через direct XML import.

## 14. CURRENT_SOURCE_STALE

Смысл: live TIA source изменился после последнего `check-clone`.

Что делать:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Затем:

```text
если TIA изменение правильное - принять через sync-clone и заново внести clone change;
если clone изменение должно победить - вручную объединить изменения;
если это чужая правка пользователя - не перетирать.
```

## 15. GROUP_MOVE_FORBIDDEN

Смысл: clone diff выглядит как перемещение блока между block groups.

Почему блокируется: TIA Openness не предоставляет безопасный публичный move API
для PLC blocks, а delete/recreate может сломать скрытые связи.

Что делать:

```text
1. Вернуть clone file в исходную group или отказаться от automatic move.
2. Если move нужен, сделать его вручную в TIA Portal.
3. Запустить check-clone.
4. Принять через sync-clone, если move корректен.
```

## 16. Duplicate или invalid block number

Симптомы compile:

```text
Number: The block X FB has an invalid number 9102.
```

Сначала найти свободный номер:

```cmd
.\OpennessLLM\run.cmd block-info --number 102 --number-space FB --out .\CLONE_PROJECT
```

Если номер свободен, можно точечно исправить attribute:

```cmd
.\OpennessLLM\run.cmd set-attribute --attach --attach-index 0 --target block --name X --attribute Number --value 102 --apply
```

Потом:

```cmd
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd sync-clone --out .\CLONE_PROJECT
```

Если проблема возникла в clone-only блоке, лучше исправить sidecar/filename и
повторить `apply-clone`.

## 17. compile-all нашел ошибки

Команда:

```cmd
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply
```

Смотреть полный вывод:

```text
Target
Compiler state
Errors/Warnings
Nested messages
Path
Description
```

Исправлять по одной понятной причине. После каждой правки:

```cmd
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply
```

Сохранять только когда zero errors:

```cmd
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply --save
```

## 18. hmi-check dirty

Команда:

```cmd
.\OpennessLLM\run.cmd hmi-check --attach --attach-index 0 --out .\CLONE_PROJECT
```

Смотреть:

```text
hmi-check-summary.txt
hmi-check-objects.csv
```

Решения:

```text
если TIA HMI изменение правильное - hmi-sync-clone;
если clone HMI baseline должен остаться - разобраться вручную;
если export/parse error - сначала решить export/parse blocker;
не запускать HMI apply, пока baseline dirty.
```

## 19. hmi-apply-preflight unsupported operation

Симптом:

```text
UNSUPPORTED_OPERATION
UNSUPPORTED_OBJECT
UNSUPPORTED_ATTRIBUTE
UNSUPPORTED_LINK
```

Что делать:

```text
1. Проверить patch JSONL.
2. Свериться с COMMAND_REFERENCE_RU.md и текущими supported operations.
3. Если операция действительно нужна, сначала проектировать новую стратегию.
4. Не пытаться импортировать вручную сырой XML в основной проект.
```

## 20. HMI collateral changes

Симптомы:

```text
unexpected collateral
hmi-apply-preflight-collateral.csv contains unexpected rows
hmi-project-texts-import-probe-copy-collateral.csv not empty
post-apply gate rejected
```

Что делать:

```text
1. Остановиться.
2. Открыть collateral CSV.
3. Понять, какие объекты изменились кроме target.
4. Если collateral expected, нужно расширить expected model/gate.
5. Если collateral unexpected, не делать production apply.
```

## 21. hmi-project-texts-apply blocked before import

Симптом:

```text
hmi-project-texts-apply blocked before import.
Inspect: hmi-project-texts-apply-summary.txt
```

Смотреть:

```text
hmi-project-texts-apply-summary.txt
hmi-project-texts-apply-gate.csv
hmi-project-texts-apply-copy-gate.csv
hmi-project-texts-apply-live-diff.csv
```

Типовые причины:

```text
нет explicit --apply;
нет --in patched dir;
не указан target language;
copy-only rehearsal не accepted;
live HMI baseline dirty;
--no-backup запрещен;
source-language import без --update-source-language;
unexpected collateral.
```

## 22. hmi-import-probe-copy ругается на --attach

Симптом:

```text
hmi-import-probe-copy must not use --attach.
It creates and opens a separate copied project.
```

Что делать:

```cmd
.\OpennessLLM\run.cmd hmi-project-texts-import-probe-copy --project .\Project.ap21 --in <patched-dir> --out .\CLONE_PROJECT
```

Не использовать `--attach` для copy-only probe.

## 23. HMI target не найден

Симптомы:

```text
No HMI targets were found
HMI clone status NotPresent
```

Возможные причины:

```text
в проекте действительно нет HMI;
инструмент подключен не к тому TIA проекту;
attach-index выбран не тот;
TIA project не полностью загружен;
SDK traversal не видит HMI target этой версии.
```

Проверить:

```cmd
.\OpennessLLM\run.cmd tree --attach --attach-index 0 --max 1000
.\OpennessLLM\run.cmd hmi-inventory --attach --attach-index 0 --out .\OpennessLLM\out\hmi-inventory-current
```

## 24. Старые файлы OpennessProbe путают LLM

Симптом:

```text
LLM читает OpennessProbe\Program.cs или старые STAGE_* планы и делает выводы о текущем инструменте.
```

Правило:

```text
актуальный инструмент - OpennessLLM;
актуальный код - OpennessLLM\Program.cs;
актуальная документация - OpennessLLM\*.md;
OpennessProbe - исторический контекст, не source of truth.
```

Для новой LLM первым файлом должен быть:

```text
OpennessLLM\LLM_START_HERE_RU.md
```

## 25. Кириллица отображается как mojibake в PowerShell

Симптом:

```text
Р”Р°С‚Р°
РўРµРєСѓС‰Р°СЏ
```

Причина: файл UTF-8, консоль читает другой encoding.

Что делать:

```powershell
chcp 65001
Get-Content .\OpennessLLM\PORTABLE_MANIFEST_RU.md -Encoding UTF8
```

Это проблема отображения, а не обязательно повреждение файла.

## 26. clean-local ничего не удаляет

По умолчанию:

```cmd
.\OpennessLLM\run.cmd clean-local
```

это audit-only.

Для удаления generated output:

```cmd
.\OpennessLLM\run.cmd clean-local --scope probe-generated --apply
```

Если нужно очистить workspace transient folders, сначала audit:

```cmd
.\OpennessLLM\run.cmd clean-local --scope workspace-transient
```

Удалять вручную только после просмотра отчета.

## 27. Что делать, если непонятно

Минимальный безопасный набор:

```cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd --help
.\OpennessLLM\run.cmd self-test
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT
```

Если вопрос про PLC блок:

```cmd
.\OpennessLLM\run.cmd block-info --name <block-name> --out .\CLONE_PROJECT
```

Если вопрос про HMI:

```cmd
.\OpennessLLM\run.cmd hmi-check --attach --attach-index 0 --out .\CLONE_PROJECT
```

Если вопрос про ошибку компиляции:

```cmd
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply
```

Не переходить к `--apply`, если summary/gate reports не поняты.

## 28. `plc-runtime-map` не содержит ожидаемый DB или строк слишком мало

Проверить, что запущена версия не ниже `0.12.1`:

```cmd
.\OpennessLLM\run.cmd version
```

Перестроить карту:

```cmd
.\OpennessLLM\run.cmd plc-runtime-map --in .\CLONE_PROJECT --out .\OpennessLLM\out\plc-runtime-map-current
```

Проверить summary:

```text
CLONE_PROJECT\_runtime_maps\plc-runtime-map-summary.txt
```

Если Global DB не попал в карту, проверить:

```text
блок есть в CLONE_PROJECT\plc-blocks.csv или как .db файл под CLONE_PROJECT\_root;
TypeName блока заканчивается на GlobalDB;
.db файл содержит DATA_BLOCK и STRUCT до BEGIN;
структура classic non-optimized, а не optimized-only формат без явных полей;
имена полей в кавычках допустимы, например "Source__Target_busy".
```

Если Instance DB не попал в карту, проверить `InstanceOfName` и наличие
исходного FB `.scl` в clone.
