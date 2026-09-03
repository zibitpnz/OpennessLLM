# Portable manifest для OpennessLLM

Дата: 2026-08-27.

Имя инструмента: `OpennessLLM`.
Текущая версия: `0.12.3`.
Создано: `Zibitpnz`.
Текущая переносимая папка инструмента: `OpennessLLM`.

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
OpennessLLM\.artifactignore
OpennessLLM\.gitattributes
OpennessLLM\.gitignore
```

## Не копировать как часть чистого инструмента

```text
OpennessLLM\bin
OpennessLLM\obj
OpennessLLM\out
OpennessLLM\.git
CLONE_PROJECT
```

Эти каталоги являются локальными build/output/workspace артефактами конкретного
проекта. Они пересоздаются командами:

```cmd
.\OpennessLLM\build.cmd
.\OpennessLLM\run.cmd init-workspace --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd self-test
```

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
