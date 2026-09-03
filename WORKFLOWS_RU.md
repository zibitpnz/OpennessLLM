# OpennessLLM Workflows

Практические сценарии применения `OpennessLLM` для человека и LLM.

Этот файл отвечает на вопрос "что делать по шагам". Подробный список команд и
параметров находится в `COMMAND_REFERENCE_RU.md`.

## 1. Первый вход новой LLM-сессии

Цель: не тратить токены на слепой поиск по файлам и не начинать с чтения
`Program.cs`.

Шаги:

```cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd --help
.\OpennessLLM\run.cmd self-test
```

Затем прочитать:

```text
OpennessLLM\LLM_START_HERE_RU.md
OpennessLLM\COMMAND_REFERENCE_RU.md
OpennessLLM\WORKFLOWS_RU.md
```

Если TIA Portal уже открыт с нужным проектом:

```cmd
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT
```

Если `status` показывает blocked состояние, сначала решить его. Не начинать
write workflow, пока непонятно, что именно blocked.

## 2. Проверка окружения и доступа к TIA Portal

Цель: убедиться, что инструмент видит TIA Openness SDK и может работать с
проектом.

Если проект открыт в TIA Portal:

```cmd
.\OpennessLLM\run.cmd tree --attach --attach-index 0 --max 100
```

Если проект нужно открыть headless:

```cmd
.\OpennessLLM\run.cmd tree --headless --project .\Project.ap21 --max 100
```

Если ошибка говорит, что пользователь не имеет доступа к Openness, запустить от
администратора:

```cmd
.\OpennessLLM\enable-openness-admin.cmd
```

После добавления пользователя в группу `Siemens TIA Openness` нужно выйти из
Windows и войти снова.

Если ошибка говорит, что не найден PublicAPI:

```cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd tree --attach --api-dir "C:\Program Files\Siemens\Automation\Portal V21\PublicAPI\V21\net48"
.\OpennessLLM\run.cmd tree --attach --api-dir "C:\Program Files\Siemens\Automation\Portal V20\PublicAPI\V20"
```

Версия PublicAPI должна соответствовать версии проекта: `*.ap21` - `V21`,
`*.ap20` - `V20`. Для TIA Portal V20 инструмент `0.10.6` поддерживает также
legacy PublicAPI path без `net48`, если там лежит `Siemens.Engineering.dll`.

## 3. Инициализация workspace для нового проекта

Цель: создать локальный `CLONE_PROJECT`, который станет рабочей копией для LLM.

```cmd
.\OpennessLLM\run.cmd init-workspace --attach --attach-index 0 --out .\CLONE_PROJECT
```

Если проект большой и нужно работать только с одним PLC/HMI target, можно сразу
сузить workspace/status команды:

```cmd
.\OpennessLLM\run.cmd init-workspace --attach --attach-index 0 --out .\CLONE_PROJECT --software-path "PLC_1" --hmi-target-path "HMI_1"
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT --software-path "PLC_1" --hmi-target-path "HMI_1"
```

Проверить результат:

```cmd
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT
```

Ожидаемые ключевые файлы:

```text
CLONE_PROJECT\workspace-init-summary.txt
CLONE_PROJECT\tool-status-summary.txt
CLONE_PROJECT\plc-blocks.csv
CLONE_PROJECT\clone-check-summary.txt
CLONE_PROJECT\_metadata\blocks.jsonl
CLONE_PROJECT\_root\...
```

Если есть HMI:

```text
CLONE_PROJECT\hmi-check-summary.txt
CLONE_PROJECT\_hmi\...
CLONE_PROJECT\_hmi_metadata\...
```

Если `init-workspace` blocked, смотреть `workspace-init-summary.txt` и
`workspace-init-steps.csv`.

## 4. Ежедневная проверка состояния

Цель: понять, можно ли безопасно продолжать работу.

```cmd
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd hmi-check --attach --attach-index 0 --out .\CLONE_PROJECT
```

Минимально смотреть:

```text
CLONE_PROJECT\tool-status-summary.txt
CLONE_PROJECT\clone-check-summary.txt
CLONE_PROJECT\hmi-check-summary.txt
```

Если PLC/HMI изменились в TIA Portal вручную и эти изменения правильные, принять
их в baseline:

```cmd
.\OpennessLLM\run.cmd sync-clone --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd hmi-sync-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Не делать `sync-clone` автоматически. Это означает "я принимаю текущий проект
как новый baseline".

После `sync-clone` новые PLC блоки, добавленные вручную в TIA Portal, должны
иметь заполненный `SoftwarePath` в `CLONE_PROJECT\plc-blocks.csv` и
`CLONE_PROJECT\_metadata\blocks.jsonl`. Если это поле пустое, сначала проверить
версию инструмента и повторить `check-clone`/`sync-clone`.

## 5. Поиск PLC блока

Цель: не искать номера и группы вручную в CSV/исходниках.

По имени:

```cmd
.\OpennessLLM\run.cmd block-info --name 5_HM --out .\CLONE_PROJECT
```

По номеру:

```cmd
.\OpennessLLM\run.cmd block-info --number 5 --out .\CLONE_PROJECT
```

По номеру и number space:

```cmd
.\OpennessLLM\run.cmd block-info --number 5 --number-space DB --out .\CLONE_PROJECT --json
```

Когда использовать:

```text
перед изменением блока;
перед созданием нового блока, чтобы проверить свободен ли номер;
после rename/number change;
после sync-clone;
когда LLM нужно быстро понять, где лежит source file.
```

## 6. Изменение существующего PLC блока

Цель: изменить source file в clone и безопасно применить в TIA.

Шаг 1. Проверить baseline:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Шаг 2. Найти блок:

```cmd
.\OpennessLLM\run.cmd block-info --name <block-name> --out .\CLONE_PROJECT
```

Шаг 3. Изменить соответствующий файл в:

```text
CLONE_PROJECT\_root\...
```

Шаг 4. После изменения заново выпустить bundle:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Шаг 5. Dry-run:

```cmd
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Шаг 6. Если preflight clean, применить, скомпилировать и сохранить:

```cmd
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT --apply --save
```

`apply-clone --apply --save` сам запускает самый широкий доступный compile после
точной post-write проверки и до `SaveProject`. При compiler errors сохранение и
публикация baseline запрещены. Отдельные `compile-block`/`compile-all` после
успешного apply не обязательны; они остаются диагностическими командами.

Перед apply проект должен быть сохранён: `Project.IsModified=false`. Если это
условие невозможно доказать, команда fail closed. Флаг
`--i-accept-saving-preexisting-project-changes` разрешён только как осознанное
опасное исключение: он подтверждает сохранение всех уже имевшихся изменений TIA
и фиксируется в audit-отчёте.

Шаг 7. При необходимости отдельно перепроверить clone:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Шаг 8. Если отдельно проверенное TIA состояние нужно принять как новое правильное состояние:

```cmd
.\OpennessLLM\run.cmd sync-clone --out .\CLONE_PROJECT
```

После успешного `apply-clone --apply --save` проект уже скомпилирован, сохранён,
а новый clone baseline опубликован из свежего post-save snapshot.

## 7. Создание нового PLC блока

Цель: добавить новый блок через clone workflow.

Шаг 1. Проверить свободный номер:

```cmd
.\OpennessLLM\run.cmd block-info --number 120 --number-space FB --out .\CLONE_PROJECT
```

Если команда ничего не находит в нужном number space, номер вероятно свободен в
baseline. Финальную проверку все равно сделает `apply-clone`.

Шаг 2. Создать source file в нужной группе:

```text
CLONE_PROJECT\_root\120_MyNewBlock.scl
```

или без номера, если должен использоваться auto-number:

```text
CLONE_PROJECT\_root\MyNewBlock.scl
```

Шаг 3. Обязательно добавить sidecar:

```text
CLONE_PROJECT\_root\120_MyNewBlock.scl.meta.json
```

Пример:

```json
{
  "blockKind": "FB",
  "numberMode": "Manual",
  "number": 120,
  "programmingLanguage": "SCL",
  "name": "MyNewBlock",
  "softwarePath": "PLC",
  "sourceOrigin": "explicit-new-local-source"
}
```

Для нового loose source задавайте точное
`sourceOrigin=explicit-new-local-source`. Без него происхождение считается
`unknown-orphaned` и при неоднозначности source-blocker gate завершится fail
closed. Непустой `softwarePath` обязателен; числовой префикс имени файла без
этого sidecar не разрешает создание блока.

`explicit-new-local-source` используется один раз. Обычный `check-clone` не
промоутит source только из-за совпадения имени/номера. После успешного
`CreateBlock` инструмент создаёт receipt, повторно экспортирует live source и
требует совпадения language и canonical hash. Только затем восстанавливаемая
транзакция меняет sidecar origin на `tracked-baseline` и публикует строку в
`plc-blocks.csv`. Не возвращайте marker обратно вручную: после применения блок
уже является tracked baseline.

Шаг 4. После создания source и sidecar заново выполнить check, затем dry-run и apply:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT --apply --save
```

Шаг 5. При необходимости дополнительный check:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

## 8. Rename PLC блока

Цель: переименовать блок без потери скрытых связей.

Поддержанный безопасный путь: rename внутри той же block group через clone
workflow.

Шаги:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Переименовать source file в `CLONE_PROJECT\_root\...`, обновить имя внутри
source text и перенести соседний `.meta.json` вместе с source, если sidecar
существует. Числовой префикс файла сохраняют: например,
`10_OldName.scl` -> `10_NewName.scl`. `check-clone` принимает такой rename
только при единственном совпадении PLC/group/type/number; неоднозначность
остаётся fail closed.
Если изменилось только имя верхнеуровневой декларации, план классифицируется как
`RenameBlock`; любые отличия attributes/interface/body/comments требуют
`RenameAndUpdateSource`.

После rename заново выпустить bundle:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Dry-run:

```cmd
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Apply:

```cmd
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT --apply --save
```

При необходимости потом:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Важно: move между block groups не поддерживается как автоматический write path.
Такой move нужно сделать вручную в TIA Portal, затем принять через
`check-clone`/`sync-clone`.

## 9. Delete PLC блока

Предпочтительный production путь: удалить source file из clone и пройти
`apply-clone`.

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Удалить файл из `CLONE_PROJECT\_root\...`.

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT --apply --save
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Если нужно удалить один блок напрямую:

```cmd
.\OpennessLLM\run.cmd delete-block --attach --attach-index 0 --name <block-name>
.\OpennessLLM\run.cmd delete-block --attach --attach-index 0 --name <block-name> --apply
```

Но direct delete дает меньше контекста, чем clone workflow.

## 10. Компиляция и исправление ошибок

Один блок:

```cmd
.\OpennessLLM\run.cmd compile-block --attach --attach-index 0 --name <block-name> --apply
```

Весь доступный compile scope:

```cmd
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply
```

Рекомендуемый порядок:

```text
1. compile-all без --apply, чтобы увидеть compile targets.
2. compile-all --apply, чтобы получить все ошибки.
3. Исправить первую понятную ошибку.
4. Снова compile-all --apply.
5. Если zero errors, при необходимости compile-all --apply --save.
```

Если ошибка вида "Number: The block X FB has an invalid number 9102":

```cmd
.\OpennessLLM\run.cmd block-info --number 102 --number-space FB --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd set-attribute --attach --attach-index 0 --target block --name X --attribute Number --value 102 --apply
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd sync-clone --out .\CLONE_PROJECT
```

`set-attribute` тут допустим как точечная repair-команда. Для обычных source
правок использовать `apply-clone`.

## 11. HMI read-only анализ

Цель: понять HMI без чтения тяжелого XML.

```cmd
.\OpennessLLM\run.cmd hmi-inventory --attach --attach-index 0 --out .\OpennessLLM\out\hmi-inventory-current
.\OpennessLLM\run.cmd hmi-export-xml --attach --attach-index 0 --out .\OpennessLLM\out\hmi-export-current --force
.\OpennessLLM\run.cmd hmi-digest --in .\OpennessLLM\out\hmi-export-current --out .\OpennessLLM\out\hmi-digest-current
```

Читать сначала:

```text
OpennessLLM\out\hmi-digest-current\hmi-digest.json
OpennessLLM\out\hmi-digest-current\hmi-screen-items.csv
OpennessLLM\out\hmi-digest-current\hmi-text-list-items.csv
OpennessLLM\out\hmi-digest-current\screens\*.md
```

XML читать только точечно, когда digest указал конкретный `RelativePath`.

## 12. HMI clone baseline

Цель: зафиксировать HMI XML snapshot в `CLONE_PROJECT`.

```cmd
.\OpennessLLM\run.cmd hmi-init-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd hmi-check --attach --attach-index 0 --out .\CLONE_PROJECT
```

Если текущий HMI в TIA Portal изменен вручную и это нужно принять:

```cmd
.\OpennessLLM\run.cmd hmi-sync-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Не использовать `hmi-sync-clone` как "починить все". Это acceptance baseline.

## 13. HMI patch preflight без записи в TIA

Цель: подготовить локальную patched XML копию и понять collateral до любого
импорта.

Шаг 1. Убедиться, что baseline чистый:

```cmd
.\OpennessLLM\run.cmd hmi-check --attach --attach-index 0 --out .\CLONE_PROJECT
```

Шаг 2. Создать JSONL patch, например:

```jsonl
{"op":"set-text-list-entry","object":"text-list-entry","textList":"Mode","from":"1","culture":"ru-RU","text":"Новый текст"}
{"op":"set-screen-item-text","object":"screen-item","screen":"01 Scheme","item":"Label_1","culture":"ru-RU","text":"Новая надпись"}
```

Шаг 3. Запустить preflight:

```cmd
.\OpennessLLM\run.cmd hmi-apply-preflight --out .\CLONE_PROJECT --patch .\hmi-patch.jsonl
```

Шаг 4. Смотреть:

```text
CLONE_PROJECT\hmi-apply-preflight-summary.txt
CLONE_PROJECT\hmi-apply-preflight-plan.csv
CLONE_PROJECT\hmi-apply-preflight-issues.csv
CLONE_PROJECT\hmi-apply-preflight-collateral.csv
CLONE_PROJECT\_hmi_preflight\patched-*\_hmi_metadata\digest\...
```

Если есть unexpected collateral, не идти к apply.

## 14. HMI ProjectTexts copy-only rehearsal

Цель: доказать на копии проекта, что ProjectTexts import изменит только
ожидаемые HMI texts.

```cmd
.\OpennessLLM\run.cmd hmi-project-texts-import-probe-copy --project .\Project.ap21 --in .\CLONE_PROJECT\_hmi_preflight\patched-YYYYMMDD-HHMMSS --out .\CLONE_PROJECT
```

Важно:

```text
не использовать --attach;
команда открывает отдельную копию проекта;
результат нужен как gate для production apply.
```

Смотреть:

```text
hmi-project-texts-import-probe-copy-summary.txt
hmi-project-texts-import-probe-copy-targets.csv
hmi-project-texts-import-probe-copy-object-diff.csv
hmi-project-texts-import-probe-copy-collateral.csv
```

Если collateral unexpected, production apply запрещен.

## 15. HMI ProjectTexts production apply

Цель: применить выбранные HMI text changes через guarded ProjectTexts XLSX path.

Шаг 1. Apply preflight:

```cmd
.\OpennessLLM\run.cmd hmi-project-texts-apply-preflight --attach --attach-index 0 --in .\CLONE_PROJECT\_hmi_preflight\patched-YYYYMMDD-HHMMSS --out .\CLONE_PROJECT --language ru-RU
```

Шаг 2. Если preflight accepted и copy-only rehearsal accepted:

```cmd
.\OpennessLLM\run.cmd hmi-project-texts-apply --attach --attach-index 0 --in .\CLONE_PROJECT\_hmi_preflight\patched-YYYYMMDD-HHMMSS --out .\CLONE_PROJECT --language ru-RU --apply
```

Шаг 3. Если нужно сохранить:

```cmd
.\OpennessLLM\run.cmd hmi-project-texts-apply --attach --attach-index 0 --in .\CLONE_PROJECT\_hmi_preflight\patched-YYYYMMDD-HHMMSS --out .\CLONE_PROJECT --language ru-RU --apply --save
```

Шаг 4. Проверить HMI:

```cmd
.\OpennessLLM\run.cmd hmi-check --attach --attach-index 0 --out .\CLONE_PROJECT
```

Шаг 5. Если результат принят:

```cmd
.\OpennessLLM\run.cmd hmi-sync-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Для source-language import:

```cmd
--update-source-language
```

использовать только если copy-only rehearsal явно accepted source-language mode.

## 16. Runtime map для PLC read/write/snapshot

Цель: построить локальную карту classic non-optimized DB-смещений перед
`plc-runtime-read`, `plc-runtime-snapshot` или dry-run `plc-runtime-write`.

```cmd
.\OpennessLLM\run.cmd plc-runtime-map --in .\CLONE_PROJECT --out .\OpennessLLM\out\plc-runtime-map-current
```

Проверить результат:

```text
CLONE_PROJECT\_runtime_maps\plc-runtime-map-summary.txt
CLONE_PROJECT\_runtime_maps\plc-runtime-map.csv
CLONE_PROJECT\_runtime_maps\DB_*.md
```

Начиная с `0.12.1`, карта включает Global DB из `.db` файлов и Instance DB через
`InstanceOfName`. Если изменялись `.db`, `.scl` или clone metadata, карту нужно
перестроить перед runtime-чтением/снимком/записью.

## 17. Перенос инструмента на другой проект или компьютер

Копировать только portable files из `PORTABLE_MANIFEST_RU.md`.

Минимально:

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
OpennessLLM\.artifactignore
```

Не копировать как часть чистого инструмента:

```text
OpennessLLM\bin
OpennessLLM\out
CLONE_PROJECT
```

На новом месте:

```cmd
.\OpennessLLM\build.cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd self-test
.\OpennessLLM\run.cmd init-workspace --attach --attach-index 0 --out .\CLONE_PROJECT
```

## 18. После сжатия контекста LLM

Если контекст был потерян или сжат, восстановить состояние так:

```cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
```

Прочитать:

```text
OpennessLLM\LLM_START_HERE_RU.md
CLONE_PROJECT\tool-status-summary.txt
CLONE_PROJECT\clone-check-summary.txt
CLONE_PROJECT\hmi-check-summary.txt
```

Если задача про конкретный блок:

```cmd
.\OpennessLLM\run.cmd block-info --name <block-name> --out .\CLONE_PROJECT
```

Если задача про HMI:

```text
CLONE_PROJECT\_hmi_metadata\digest\...
CLONE_PROJECT\hmi-check-objects.csv
```

Не пытаться восстанавливать состояние по памяти.
