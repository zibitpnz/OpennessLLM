# LLM START HERE

Этот файл является первой точкой входа для любой LLM-сессии, которая работает с
`OpennessLLM` и TIA Portal проектом. Он не привязан к Codex, Claude, ChatGPT или
другому конкретному агенту.

Создано: `Zibitpnz`.

Цель: быстро понять инструмент и текущее состояние проекта без ручного поиска по
исходникам, XML и большим CSV.

## 1. Сначала понять инструмент

Выполнить:

```cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd --help
.\OpennessLLM\run.cmd self-test
```

После этого прочитать:

```text
OpennessLLM\README.md
OpennessLLM\COMMAND_REFERENCE_RU.md
OpennessLLM\WORKFLOWS_RU.md
OpennessLLM\SAFETY_GATES_RU.md
OpennessLLM\INTERNALS_RU.md
OpennessLLM\TROUBLESHOOTING_RU.md
OpennessLLM\CODEX_HANDOFF.md
```

`CODEX_HANDOFF.md` называется исторически, но содержит короткую техническую
памятку, полезную для любой LLM.

## 2. Сначала спросить инструмент о проекте

Если TIA Portal уже открыт с нужным проектом:

```cmd
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Если workspace еще не создан:

```cmd
.\OpennessLLM\run.cmd init-workspace --attach --attach-index 0 --out .\CLONE_PROJECT
```

Если в каталоге несколько `*.apXX` проектов, нужно явно передавать `--project`.

## 3. Не искать номера блоков вручную

Для PLC блоков сначала использовать `block-info`, а не читать CSV/JSON/source
файлы вручную:

```cmd
.\OpennessLLM\run.cmd block-info --name <block-name> --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd block-info --number <number> --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd block-info --number <number> --number-space FB --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd block-info --number <number> --number-space DB --out .\CLONE_PROJECT --json
```

Эта команда локальная: она не открывает TIA Portal и читает уже подготовленную
metadata baseline из `CLONE_PROJECT`.

## 4. Runtime-доступ к PLC

Для чтения фактических значений из живого PLC сначала построить карту смещений:

```cmd
.\OpennessLLM\run.cmd plc-runtime-map --in .\CLONE_PROJECT --out .\OpennessLLM\out\plc-runtime-map-current
```

Карта сохраняется также в:

```text
CLONE_PROJECT\_runtime_maps
```

Там есть `plc-runtime-map.csv` для инструмента и `DB_*.md` для человека/LLM.
Начиная с версии `0.12.1`, карта включает classic non-optimized Global DB из
`.db` файлов и Instance DB через `InstanceOfName`/FB declaration.

Адрес `192.0.2.10` и имена DB/полей ниже являются документационными примерами.
Перед запуском их нужно заменить параметрами целевого PLC и проекта.

Чтение переменной:

```cmd
.\OpennessLLM\run.cmd plc-runtime-read --host 192.0.2.10 --db DB_Test_Outputs --var Online --map .\CLONE_PROJECT\_runtime_maps --timeout-ms 5000
```

Снимок значений одного DB:

```cmd
.\OpennessLLM\run.cmd plc-runtime-snapshot --host 192.0.2.10 --db DB_Test_Inputs --map .\CLONE_PROJECT\_runtime_maps --out .\CLONE_PROJECT\_runtime_snapshots --timeout-ms 5000
```

Выборочный снимок:

```cmd
.\OpennessLLM\run.cmd plc-runtime-snapshot --host 192.0.2.10 --db DB_Test_Inputs --vars Online,DataValid,InputWord0,InputWord0Valid --map .\CLONE_PROJECT\_runtime_maps --out .\CLONE_PROJECT\_runtime_snapshots --print-values
```

Снимки сохраняются в `CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS`.
Для больших DB смотреть `snapshot-read-ranges.csv`: несколько S7-диапазонов
означают последовательное чтение, а не строгий атомарный снимок всего DB.

Проверка сырых байтов DB:

```cmd
.\OpennessLLM\run.cmd plc-runtime-probe --host 192.0.2.10 --rack 0 --slot 2 --db 210 --start 0 --size 32 --timeout-ms 5000
```

Runtime-запись в PLC возможна, но это отдельный опасный режим. Сначала всегда
делать dry-run:

```cmd
.\OpennessLLM\run.cmd plc-runtime-write --host 192.0.2.10 --db DB_Test_Outputs --var Output_1 --value true --map .\CLONE_PROJECT\_runtime_maps --timeout-ms 5000
```

Реальную запись выполнять только после явного подтверждения человека и только с
двумя флагами:

```cmd
--apply --i-know-this-writes-plc
```

## 5. PLC write workflow

Для PLC правок основной путь:

```text
check-clone
изменить файлы в CLONE_PROJECT
check-clone повторно после изменений
apply-clone dry-run
apply-clone --apply --save
compile-block или compile-all
check-clone
sync-clone, если нужно принять новое состояние в clone baseline
```

Команды:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
REM Изменить source/sidecar, затем обязательно обновить bundle:
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT --apply --save
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

`apply-clone` и `compile-all` являются write-командами. Для `apply-clone`
реальные изменения требуют `--apply --save` и свежий check после всех локальных
изменений.

## 6. Диагностика компиляции

Один блок:

```cmd
.\OpennessLLM\run.cmd compile-block --attach --attach-index 0 --name <block-name> --apply
```

Широкая компиляция проекта/доступных software targets:

```cmd
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply --save
```

Без `--apply` команда только показывает стратегию и цели компиляции. С `--apply`
печатает рекурсивные сообщения TIA compiler, включая вложенные описания ошибок.

## 7. HMI workflow

Для анализа HMI сначала использовать read-only команды:

```cmd
.\OpennessLLM\run.cmd hmi-inventory --attach --attach-index 0
.\OpennessLLM\run.cmd hmi-export-xml --attach --attach-index 0
.\OpennessLLM\run.cmd hmi-digest --in <hmi-export-dir>
.\OpennessLLM\run.cmd hmi-check --attach --attach-index 0 --out .\CLONE_PROJECT
```

XML не должен быть первым источником для LLM. Сначала смотреть digest/check
отчеты. Сырые XML читать только точечно, когда digest уже указал конкретный
объект.

## 8. Чего не делать в начале

- Не начинать с чтения всего `Program.cs`.
- Не искать номера блоков руками по CSV, JSON или source файлам, если подходит
  `block-info`.
- Не читать полный HMI XML без необходимости.
- Не запускать write-команды без dry-run и понимания gate reports.
- Не выполнять `plc-runtime-write --apply --i-know-this-writes-plc` без явного
  подтверждения человека: это запись в живой PLC.
- Не использовать старые исторические файлы из `OpennessProbe` как источник
  актуального поведения `OpennessLLM`.

## 9. Когда читать код

Код читать только если:

- `--help`, README и этот файл не отвечают на вопрос;
- команда ведет себя не так, как ожидается;
- нужно изменить сам инструмент;
- нужно проверить конкретный gate, parser или TIA SDK reflection path.

В остальных случаях сначала использовать CLI команды и generated reports.
