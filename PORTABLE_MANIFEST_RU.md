# Portable manifest для OpennessLLM

Дата версии: 2026-09-07.

Имя инструмента: `OpennessLLM`.
Текущая версия: `0.12.14`.
Статус: кандидат, ещё не опубликованный релиз (`Unreleased` в CHANGELOG).
Создано: `Zibitpnz`.
Текущая переносимая папка инструмента: `OpennessLLM`.

Актуальные версии схем и write policy приведены в
[README](README.md#current-version-and-compatibility). Документация относится к
исходникам этой копии инструмента; старый EXE или другая ветка могут иметь другую
версию. После переноса исходников выполнить `build.cmd` и `run.cmd version` из
папки новой копии. `run.cmd` не пересобирает уже существующий EXE автоматически.

В текущей версии поздние правки при rollback сохраняются в постоянном `_rollback`
внутри backup транзакции, а результат commit проверяется по журналу и
установленным компонентам. Completion schema `2` сохраняет полные подробности
ошибок и их историю при recovery новым процессом. Publication journal schema `5`,
check-bundle schema `7`, write policy `clone-write-policy-v13`. После обновления
нужен свежий `check-clone`; незавершённые транзакции со старым журналом требуют
ручного разбора с сохранением evidence, а не удаления файлов ради продолжения.

Папку clone workspace размещать по короткому пути: `apply-clone` с непустым
планом проверяет `before-write/workspace-path-budget` до project backup и записи
в TIA, включая dry-run. Полные пути файлов должны быть короче 260, каталогов —
короче 248 единиц UTF-16 с учётом вложенных служебных каталогов. Перенос EXE сам
по себе не сокращает путь workspace. После безопасного переноса workspace нужны
новые `check-clone` и dry-run; незавершённые транзакции сначала разбираются по
исходным путям. См. [ограничения путей](README.md#workspace-path-limits).

Следующие упоминания старых версий обозначают начало поддержки возможностей,
а не текущую версию переносимого инструмента.

Начиная с версии `0.12.2`, переносимый инструмент содержит исправление `sync-clone`:
новые блоки, добавленные в TIA Portal и принятые в baseline, сохраняют
`SoftwarePath` в `plc-blocks.csv` и `CLONE_PROJECT\_metadata\blocks.jsonl`.

Начиная с версии `0.12.1`, переносимый инструмент содержит прямой runtime-доступ к PLC
по S7comm / ISO-on-TCP: `plc-runtime-probe`, `plc-runtime-map`,
`plc-runtime-read`, `plc-runtime-snapshot`, `plc-runtime-write`. Карты смещений
сохраняются в `CLONE_PROJECT\_runtime_maps`, снимки значений - в
`CLONE_PROJECT\_runtime_snapshots`. `plc-runtime-map` поддерживает classic
non-optimized Global DB (`DATA_BLOCK ... STRUCT`) и Instance DB.

Наследуется поддержка из `0.10.6`: V20-compatible PublicAPI resolution,
`PublicAPI\VXX\net48\Siemens.Engineering.Base.dll` и legacy
`PublicAPI\VXX\Siemens.Engineering.dll`, а также фильтры `--software-path` и
`--hmi-target-path`.

## Копировать

Это явный список файлов переносимого комплекта исходников. Собирать его нужно
в новом пустом каталоге, копируя только перечисленные файлы, а не всю рабочую
папку рекурсивно. Локальные Git-исключения не фильтруют обычное копирование или
ZIP; `.artifactignore` действует только в инструментах, которые его учитывают.

```text
OpennessLLM\Program.cs
OpennessLLM\build.cmd
OpennessLLM\build.ps1
OpennessLLM\run.cmd
OpennessLLM\run.ps1
OpennessLLM\enable-openness-admin.cmd
OpennessLLM\enable-openness-admin.ps1
OpennessLLM\README.md
OpennessLLM\LLM_START_HERE_RU.md
OpennessLLM\COMMAND_REFERENCE_RU.md
OpennessLLM\WORKFLOWS_RU.md
OpennessLLM\SAFETY_GATES_RU.md
OpennessLLM\INTERNALS_RU.md
OpennessLLM\TROUBLESHOOTING_RU.md
OpennessLLM\CODEX_HANDOFF.md
OpennessLLM\PORTABLE_MANIFEST_RU.md
OpennessLLM\CHANGELOG.md
OpennessLLM\CONTRIBUTING.md
OpennessLLM\SECURITY.md
OpennessLLM\LICENSE
OpennessLLM\.artifactignore
OpennessLLM\.gitattributes
OpennessLLM\.gitignore
```

## Не копировать как часть чистого инструмента

```text
OpennessLLM\bin
OpennessLLM\obj
OpennessLLM\out
OpennessLLM\tests
OpennessLLM\reviews
OpennessLLM\artifacts
OpennessLLM\clean-local-last
OpennessLLM\.git
CLONE_PROJECT
```

Локальные тесты, отзывы, отчёты и проекты сохранять отдельно; исключение из
публикации не означает их удаление. В worktree `.git` может быть файлом, а не
каталогом — он также не входит в переносимый комплект. Не включать сборки
Siemens, резервные копии проектов и содержимое рабочих PLC/HMI-клонов.

Сборка и встроенная offline-проверка чистого комплекта не требуют локального
тестового стенда, подключения к TIA Portal или PLC:

```cmd
.\OpennessLLM\build.cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd self-test --out .\OpennessLLM\out\self-test-portable
```

Перед выпуском отдельно проверить состав архива. Для исходного комплекта он
должен соответствовать списку выше; сгенерированные при проверке `bin` и `out`
не добавлять автоматически. Если выпускается отдельный бинарный комплект,
его состав, происхождение EXE и SHA-256 нужно зафиксировать отдельно. Подготовка
переносимой копии сама по себе не означает разрешение на публикацию релиза.

Внутри `CLONE_PROJECT` также не переносить как часть чистого инструмента:

```text
CLONE_PROJECT\_runtime_maps
CLONE_PROJECT\_runtime_snapshots
```

Их нужно перестраивать/переснимать для нового проекта.

## Внешние каталоги

Не удалять автоматически:

```text
AdditionalFiles
IM
Logs
Openness
src
System
tmp
UserFiles
Vci
XRef
C:\TIA_PROJECT_BACKUPS
C:\TIA_HMI_IMPORT_PROBE
```

Это TIA project data или recovery/probe-копии. Удалять их можно только
осознанно вручную, вне автоматического cleanup инструмента.

## PLC write workflow

Для production PLC правок использовать guarded clone workflow:

```cmd
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT --apply --save
```

Инструмент больше не генерирует PLC XML для записи в проект.
