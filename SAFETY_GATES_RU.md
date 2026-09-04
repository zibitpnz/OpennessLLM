# OpennessLLM Safety Gates

Этот файл объясняет защитные механизмы `OpennessLLM`: почему команды требуют
dry-run, `--apply`, backup, check reports и collateral gates.

## 1. Главный принцип

TIA Portal проект содержит скрытые связи, compile state, HMI object identities,
Instance DB relationships и другие данные, которые легко повредить прямой
генерацией XML или blind import.

Поэтому production workflow строится так:

```text
read-only snapshot
локальный анализ
dry-run/preflight
отчеты gates
явный --apply
post-check
accept baseline только после проверки
```

LLM не должна писать в проект "по догадке". Она должна использовать команды,
которые сами проверяют текущее состояние проекта.

## 2. Классы команд по риску

### Local-only

Не открывают TIA Portal:

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

Риск: только локальные файлы workspace/output. Исключение: `clean-local --apply`
может удалить разрешенные локальные generated artifacts.

`plc-runtime-probe`, `plc-runtime-read` и `plc-runtime-snapshot` не открывают
TIA Portal, но подключаются к живому PLC по S7comm. Они должны оставаться
read-only. `plc-runtime-snapshot` пишет только локальные диагностические файлы в
`CLONE_PROJECT\_runtime_snapshots` или указанный `--out`.

`plc-runtime-map` начиная с `0.12.1` включает Global DB и Instance DB. Global DB
Data-поля попадают в карту как `write-candidate`, но это не разрешение на запись:
реальная PLC runtime-запись по-прежнему возможна только через отдельную команду
`plc-runtime-write` с двумя явными флагами.

### PLC runtime write

Не открывает TIA Portal и не меняет проект, но может изменить значения в живом
PLC:

```text
plc-runtime-write
```

Реальная запись требует два флага:

```cmd
--apply --i-know-this-writes-plc
```

Без обоих флагов команда обязана быть dry-run. Перед реальной записью LLM должна
получить явное подтверждение человека, назвать DB/переменную/offset/старое и
новое значение. Команда дополнительно блокирует:

```text
read-only строки runtime-карты;
неподдерживаемые типы;
маски выходов CommandMask / AllowedOutputMask со старшими битами выше 24.
```

### Read-only TIA commands

Подключаются к TIA или открывают проект, но не вызывают write/import/delete:

```text
tree
inventory
status
check-all
init-workspace
hmi-inventory
hmi-export-xml
hmi-init-clone
hmi-check
hmi-sync-clone
hmi-import-capabilities
hmi-textlist-model-probe
hmi-screen-model-probe
hmi-project-texts-probe
clone-folders
init-clone
check-clone
export-xml
export-documents
export-source
inspect
```

Замечание: `hmi-sync-clone` и `sync-clone` не пишут в TIA, но меняют baseline в
`CLONE_PROJECT`. Это acceptance action, его нельзя делать автоматически без
понимания результата.

### Copy-only probes

Пишут только в отдельную копию проекта:

```text
hmi-import-probe-copy
hmi-project-texts-import-probe-copy
```

Эти команды не должны использовать `--attach`, потому что они создают и открывают
отдельный copied project.

### Write commands

Могут изменить текущий TIA проект:

```text
apply-clone
compile-block
compile-all
delete-block
set-attribute
create-test-visual-fb
hmi-project-texts-apply
```

Для реального действия требуют `--apply`.

## 3. `--apply` gate

По умолчанию write-команды работают как dry-run, если это возможно.

Пример:

```cmd
.\OpennessLLM\run.cmd apply-clone --attach --out .\CLONE_PROJECT
```

Это строит план, preflight и issues, но не пишет в TIA.

Реальная запись:

```cmd
.\OpennessLLM\run.cmd apply-clone --attach --out .\CLONE_PROJECT --apply --save
```

Почему это важно:

```text
LLM может ошибиться в интерпретации задачи;
проект мог измениться после последнего чтения;
source file мог быть изменен вручную;
TIA SDK может вернуть неожиданные capabilities;
HMI import может давать collateral changes.
```

Правило: если команда поддерживает dry-run, сначала запускать dry-run.

## 4. Backup gate

Production write-команды, которые могут менять проект, обычно создают backup
папки перед real apply.

`--no-backup` существует для тестов и специальных случаев, но production gates
могут блокировать его:

```text
apply-clone production apply не должен идти с --no-backup;
hmi-project-texts-apply production apply не должен идти с --no-backup;
compile commands позволяют --no-backup, но это осознанный режим.
```

Backup не заменяет preflight. Backup нужен как rollback safety, а preflight -
чтобы не делать плохую запись вообще.

Для `apply-clone` backup создаётся после всех pre-write gates под удерживаемым
`TiaPortal.ExclusiveAccess`. Если активный `--out` вложен в каталог проекта, он
исключается из project backup: clone workspace защищён собственным backup/audit
механизмом и его `.opennessllm-workspace.lock` нельзя отпускать перед мутацией.
Неполная резервная копия после ошибки удаляется и не считается созданной.

## 5. Save gate

Для большинства команд `--apply` и `--save` разделены. Исключение —
`apply-clone`: его baseline публикуется только после сохранения TIA, поэтому
real apply требует оба флага.

```text
--apply  Выполнить действие в открытом TIA проекте.
--save   Сохранить проект после успешного действия.
```

Почему раздельно:

```text
можно проверить результат визуально в TIA перед сохранением;
compile может изменить state без необходимости немедленного save;
post-apply gates могут rejected результат, и тогда save не должен происходить.
```

Правило: `apply-clone` под `TiaPortal.ExclusiveAccess` проверяет исходный
`Project.IsModified=false`, точные postconditions, выполняет compile, получает
свежие pre/post-save snapshots и только затем публикует baseline. Для остальных
команд использовать `--save` только когда результат принят.

Если проект уже dirty или `IsModified` недоступен, real apply fail closed.
Высокорисковый флаг `--i-accept-saving-preexisting-project-changes` явно
разрешает сохранить все существовавшие изменения и записывает это решение в
audit-отчёт.

## 6. PLC clone baseline gate

PLC workflow основан на `CLONE_PROJECT`.

Baseline содержит:

```text
source files в CLONE_PROJECT\_root;
plc-blocks.csv;
clone-check-blocks.csv;
_metadata\blocks.jsonl;
_metadata\clone-manifest.json;
source SHA-256 hashes;
Number/NumberSpace/NumberMode/AutoNumber;
InstanceOfName для Instance DB.
```

Перед `apply-clone --apply` нужно свежее:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --out .\CLONE_PROJECT
```

`check-clone` выполняется после любых изменений source, sidecar или manifest.
Schema 5 связывает bundle с полным отсортированным workspace inventory и с
версиями matcher/write-safety policy; edit,
add, delete и rename после check отклоняются до TIA write. Реальный apply требует
`--apply --save`, а неполный `--name`/`--group` selection запрещён при наличии
других dirty rows.

Если baseline dirty, `apply-clone` должен остановиться или показать issues.

## 7. PLC stale source gate

Опасная ситуация:

```text
LLM сделала check-clone;
пользователь изменил блок в TIA вручную;
LLM применяет старый clone source;
ручная правка пользователя теряется.
```

Защита:

```text
check-clone записывает CurrentSourceSha256;
перед real apply инструмент экспортирует live source для изменяемых блоков;
если live SHA отличается от CurrentSourceSha256, apply блокируется.
```

Что делать при срабатывании:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --out .\CLONE_PROJECT
```

Затем вручную решить конфликт: принять TIA изменение, обновить clone или
объединить изменения.

## 8. PLC source blocker gate

Некоторые блоки могут не иметь безопасного source round-trip.

Примеры:

```text
unsupported language;
export source failed;
visual LAD/FBD/GRAPH source не проверен;
Instance DB с опасной сменой InstanceOfName;
source text не соответствует ожидаемому типу.
```

Классификация «блокирует ли source blocker запись» — одна общая функция
(`SourceBlockedStatusBlocksWrite`), которую используют все pre-write gate,
after-write проверка, formatting-reconciliation, `status` / `check-all`,
`init-workspace` и отчёт `clone-check-source-blockers.csv`. Их вердикты не могут
разойтись.

**Всегда блокируют (fail closed):**

```text
source-blocked-language-converted   блок был STL/SCL в клоне, стал LAD/FBD/GRAPH в TIA;
source-blocked-export-error         source export отслеживаемого блока не удался;
любой неизвестный source-blocked-*  новые/незнакомые статусы блокируют по умолчанию.
```

**`source-blocked-current-only`** (блок есть только в live-проекте на
неподдерживаемом языке) — информационный **только если** выполнено оба:

1. нет строки `removed`, которая может быть тем же блоком (совпадает
   number space + number **или** имя), и
2. нет строки `removed` без точного устойчивого провенанса
   `explicit-new-local-source`, у которой тот же `SoftwarePath` и number space.

Пункт 2 — fail closed на случай, когда у отслеживаемого блока сменились
**и имя, и номер** до конвертации в visual или потерялась строка manifest.
Loose-файл в `_root` без точного sidecar
`sourceOrigin=explicit-new-local-source` получает провенанс
`unknown-orphaned` и не получает исключение для нового clone-only блока.

Ещё блокируют: коллизия номера нового clone-only блока с live visual-блоком;
«забыл сначала удалить LAD-блок» при замене на SCL.

`BlockingSourceBlockerCount` считает и по основному отчёту, и по
`clone-check-source-blockers.csv` (строки `Severity=error`; старый формат без
колонки — fail closed), берёт максимум — неполный/устаревший основной отчёт не
спрячет блокер.

`check-clone` публикует отчёты как единый atomic evidence bundle. До поиска API
и attach записывается durable `clone-check-attempt.json`, который отзывает старую
авторизацию. Marker `clone-check-bundle.json` сначала публикуется со state
`reports-prepared` и содержит общий schema/run ID,
row counts, SHA-256, точный `_compare` directory, нормализованный путь проекта,
версию проекта, стабильный project object ID при его доступности и выбранный
набор `SoftwarePath`. `apply-clone` сверяет target identity с открытым проектом
и полный workspace inventory до построения плана и любой TIA-записи. Diff и
inventory строятся из одного immutable snapshot локальных файлов, clone source
hash сверяются с ним, а live workspace повторно проверяется непосредственно до
перехода marker в `authoritative-complete`; только после этого attempt marker
удаляется. Незавершённый attempt блокирует `apply-clone` и `sync-clone`, в том
числе после crash или неудачного attach/open. `.opennessllm-workspace.lock` внутри clone исключает обход
межпроцессной блокировки регистром пути или обычным alias и считается доверенным
control file при `init-workspace --force`, поэтому не попадает в backup move.
`check-clone` держит `TiaPortal.ExclusiveAccess` на всём authoritative interval,
требует clean project до/после экспорта и аннулирует старый marker до начала
сбора: любая ошибка оставляет write authorization отсутствующим. TEMP snapshot
удаляется строгим owned lease-ом на всех путях выхода; ошибка cleanup завершает
команду ошибкой и по возможности оставляет audited quarantine. Clone workspace
и рекурсивные копии fail closed на junction/symlink/reparse point. Старые
bundle schema для записи больше не
принимается: после обновления нужен новый `check-clone`.

При сравнении baseline с live TIA сначала резервируются пары с одинаковым
доступным `TiaObjectId`, и только затем применяются path/logical fallback.
Разные доступные ID дают блокирующий `object-replaced-or-mismatched`. Одновременные
rename и renumber при недоступном ID дают блокирующий
`ambiguous-rename-and-renumber`, поэтому из такого состояния нельзя автоматически
получить destructive apply. Оставшиеся number/no-ID кандидаты рассматриваются
глобально: только взаимно однозначная изолированная number-пара разрешена, а
неоднозначный компонент даёт `ambiguous-object-correlation` и не порождает
Rename/Delete/Create plan.

Успешный `status`/`check-all` без выбранного PLC и ранний результат
`ExistingWorkspace` у `init-workspace` завершают refresh без PLC bundle: attempt
удаляется, но прежняя PLC-авторизация остаётся отозванной. Ошибка PLC evidence,
даже если общий status report уже записан, завершает команду ошибкой и не может
перевести provisional marker в `authoritative-complete`.

`init-clone` и `check-clone` требуют ровно один выбранный `PlcSoftware`; в
multi-PLC проекте read-only clone нужно ограничить через `--software-path`.
`apply-clone` пока fail closed, если в открытом проекте больше одного
`PlcSoftware`, даже при scoped bundle: это исключает выбор write-target по
порядку enumeration.

`explicit-new-local-source` — одноразовое состояние. Совпадение metadata само
по себе не расходует его: нужен receipt успешного `CreateBlock`, связанный с
check run, выбранным PLC, target identity, source hash/language и live object.
Экспортированный live source обязан совпасть по языку и canonical hash.
Дубликаты в batch отклоняются до sidecar mutation; sidecar и manifest меняются
через восстанавливаемый `_manifest-publish`. Если manifest позже потерян,
consumed sidecar даёт `unknown-orphaned`.

Для `DeleteBlock` preflight заранее различает live-only блок (manifest row не
нужен) и tracked missing-source блок (сохраняется immutable clone identity и
должна существовать ровно одна строка manifest). Поэтому ошибка количества или
identity обнаруживается до TIA write, а post-check расходует только доказанную
tracked-строку.

`SourceOrigin` в `plc-blocks.csv` независимо от mutable `Status` фиксирует
`exported-source` либо `inventory-only-unsupported`. Legacy и противоречивые
missing-source строки считаются `unknown-orphaned`.

`apply-clone` и `sync-clone` используют одну и ту же cross-report проверку.
`sync-clone` выполняет её до изменения source-файлов или manifest. Затем вся
новая версия `_root`, manifests и metadata строится в `_sync-staging`. Любая
ошибка возвращает non-zero и не публикует baseline; commit использует
`_sync-backups` и rollback. Непосредственно перед commit снова сверяется live
workspace fingerprint. Для accepted added/changed/moved sources sidecar
нормализуется в `tracked-baseline`. Пустой, отсутствующий или неизвестный `Severity`, а
также malformed строка dedicated report блокируют операцию. Неблокирующим
считается только явный `Severity=warning` для
`source-blocked-current-only`.

Несопоставимые pre-existing LAD / F_LAD блоки (fail-safe и т.п.) не блокируют —
это позволяет вести STL/SCL-правки в таких проектах. В
`clone-check-source-blockers.csv` они идут с `Severity=warning`, блокирующие —
с `Severity=error`.

`apply-clone --apply --save` после точной проверки ожидаемой block/group identity
и language-aware SCL/STL token stream разрешает только plan-explained
reconciliation. Затем он компилирует самый широкий SDK-supported scope до
`SaveProject`; compiler errors запрещают save и публикацию baseline. Свежие
pre-save и post-save inventory/check должны оставаться чистыми и стабильными.
Отдельный `compile-all --apply` нужен только для диагностики либо изменений вне
clone workflow.

До первой записи сверяется не только выбранный план: полный current-side набор,
metadata и source hashes всех экспортируемых PLC blocks/groups должны совпасть с
bundle под той же `ExclusiveAccess`. Доступные TIA object IDs обязательны для
pre-state и Create/Update/Rename/Delete continuity; недоступные IDs явно
помечаются `unproven`. Комментарии являются частью canonical content. Pure rename
использует immutable pre-write source. Ошибка удаления временного ExternalSource,
его остаток или изменение полного ExternalSource set запрещают `SaveProject`.
Каждый `GenerateSource` обязан создать ожидаемый файл. После полного pre-state
экспорта повторно проверяется `Project.IsModified`; новое dirty/unavailable
состояние блокирует backup и mutation без явного unsafe override. Нужные live
source bytes сначала копируются в immutable staging, затем owned каталог
`_preflight\authoritative-*` строго удаляется до backup и первой TIA write.
Ошибка cleanup приводит к audited `_preflight-quarantine`, before-write failure
и гарантированному отсутствию TIA mutation.

Для LAD/FBD/GRAPH действует дополнительная осторожность. Нужна явная проверка
round-trip или sidecar marker `visualSourceVerified=true`, если workflow это
предусматривает.

## 9. PLC number gate

TIA block numbers живут в number spaces:

```text
FB
FC
DB
OB
```

Одинаковый номер может существовать в разных spaces, например `FB5` и `DB5`.
Поэтому поиск номера должен использовать:

```cmd
.\OpennessLLM\run.cmd block-info --number 5 --number-space FB --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd block-info --number 5 --number-space DB --out .\CLONE_PROJECT
```

Final duplicate number gate в `apply-clone` проверяет, что после всех create,
delete, rename и number changes не возникает конфликтов.

## 10. PLC group move gate

Автоматический move блока между PLC block groups запрещен.

Причина: TIA Openness не дает безопасного публичного API для перемещения блока,
а delete/recreate может сломать скрытые связи.

Правильный workflow:

```text
1. Сделать move вручную в TIA Portal.
2. Запустить check-clone.
3. Если move принят, выполнить sync-clone.
```

Rename внутри той же group поддерживается через clone workflow, но group move -
нет.

## 11. PLC Instance DB gate

Instance DB связан с FB через `InstanceOfName`.

Опасные операции:

```text
сменить InstanceOfName;
удалить FB, у которого есть Instance DB;
создать Instance DB, если referenced FB отсутствует;
применить DB раньше referenced FB.
```

Защита:

```text
metadata хранит InstanceOfName;
apply-clone проверяет referenced FB;
Instance DB применяются после FB/FC/OB sources;
опасные изменения блокируются.
```

## 12. HMI XML gate

HMI XML тяжелый и не предназначен как прямой LLM output.

Правило:

```text
hmi-export-xml нужен как полный snapshot;
hmi-digest нужен как рабочий формат для анализа;
hmi-apply-preflight может патчить только локальную копию XML;
blind XML import в основной проект запрещен как production workflow.
```

Причина: XML import может менять больше объектов, чем ожидалось, или потерять
скрытые связи.

## 13. HMI check gate

Перед HMI patch/apply baseline должен быть clean:

```cmd
.\OpennessLLM\run.cmd hmi-check --attach --out .\CLONE_PROJECT
```

Если `hmi-check-objects.csv` содержит non-unchanged targets, patch preflight или
ProjectTexts apply должны блокироваться.

Что делать:

```text
если TIA изменение правильное - hmi-sync-clone;
если clone должен победить - разобраться вручную;
если export/parse error - сначала исправить blocker.
```

## 14. HMI patch collateral gate

`hmi-apply-preflight` создает локальный patched snapshot и повторный digest.

Gate сравнивает:

```text
что ожидалось изменить по patch;
что реально изменилось в digest/collateral;
есть ли unexpected rows outside target.
```

Если collateral unexpected, нельзя переходить к import/apply strategy.

## 15. HMI copy-only import gate

Перед production HMI ProjectTexts apply нужно доказать стратегию на копии:

```cmd
.\OpennessLLM\run.cmd hmi-project-texts-import-probe-copy --project .\Project.ap21 --in <patched-dir> --out .\CLONE_PROJECT
```

Gate accepted только если:

```text
импорт прошел в копии;
target rows изменены как ожидалось;
unexpected collateral отсутствует;
object diff не показывает побочных изменений.
```

Если copy-only probe failed, production apply запрещен.

## 16. HMI ProjectTexts final gates

`hmi-project-texts-apply` перед import проверяет:

```text
explicit --apply;
наличие --in patched dir;
наличие target language;
backup policy;
clean live HMI baseline;
accepted copy-only rehearsal;
target/source language mode;
отсутствие unexpected collateral;
актуальность live export перед import.
```

После import проверяет:

```text
object diffs;
collateral diffs;
target texts;
copy gate consistency;
save policy.
```

Если post-apply gate rejected, команда падает с ошибкой и указывает summary.

## 17. Compile gates

`compile-block` и `compile-all` требуют `--apply`.

Без `--apply`:

```text
compile-block сообщает dry-run;
compile-all показывает compile strategy и targets.
```

С `--apply`:

```text
выполняется TIA CompileProvider;
печатаются recursive compiler messages;
errors приводят к non-zero exit;
--save выполняется только при zero errors.
```

`compile-all` сначала пытается самый широкий compile provider. Если project-level
provider недоступен, использует software target fallback.

## 18. Cleanup gates

`clean-local` по умолчанию audit-only.

Запрещено:

```cmd
.\OpennessLLM\run.cmd clean-local --apply
```

Разрешенный destructive scope должен быть явным:

```cmd
.\OpennessLLM\run.cmd clean-local --scope probe-generated --apply
```

`workspace-transient` в текущей версии используется как audit для временных
папок workspace. Удалять вручную только после просмотра отчета.

## 19. Какие отчеты смотреть перед write

Перед `apply-clone --apply`:

```text
clone-check-summary.txt
clone-check-blocks.csv
apply-clone-preflight-summary.txt
apply-clone-preflight-plan.csv
apply-clone-preflight-issues.csv
apply-clone-gate.csv
```

Перед `hmi-project-texts-apply --apply`:

```text
hmi-check-summary.txt
hmi-apply-preflight-summary.txt
hmi-apply-preflight-issues.csv
hmi-apply-preflight-collateral.csv
hmi-project-texts-import-probe-copy-summary.txt
hmi-project-texts-import-probe-copy-collateral.csv
hmi-project-texts-apply-preflight-summary.txt
hmi-project-texts-apply-preflight-gate.csv
```

После write:

```text
compile output;
check-clone;
hmi-check;
apply summary;
post-apply gate reports.
```

## 20. Когда можно делать sync

`sync-clone` и `hmi-sync-clone` означают:

```text
текущее состояние TIA проекта принято как новый baseline.
```

Можно делать, если:

```text
изменение было намеренным;
compile/check прошли;
визуальная проверка HMI выполнена, если это HMI;
нет unresolved collateral или dirty status.
```

Нельзя делать, если:

```text
sync нужен только чтобы убрать ошибку;
непонятно, почему baseline dirty;
есть подозрение на потерю пользовательской правки;
copy-only rehearsal failed.
```

## 21. Минимальное правило для LLM

Если LLM не уверена, write-команда это или нет:

```cmd
.\OpennessLLM\run.cmd --help
```

Если команда принимает `--apply`, сначала запускать без `--apply`.

Если отчет содержит слово:

```text
blocked
failed
error
unexpected collateral
source blocker
stale
duplicate
```

нужно остановиться и разобраться до записи.
