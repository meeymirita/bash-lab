# Сессия 5 · Функции и структура скрипта
dur: ~3 ч

## 5.1 Функции | short: Функции | est: ~30 мин
### intro
**Слова шага:** *функция*, *аргументы функции*, `return`, *вывод vs код*, `local`, *область видимости*.

**Функция** — именованный кусок скрипта, который можно вызвать много раз. Объявление:

```text
имя() {
  команды
}
```

Вызывается так же, как команда. Аргументы внутри функции — те же `$1`, `$2`, `$#`, `"$@"`, но **свои** (не путать с аргументами скрипта):

```bash run
greet() {
  echo "Привет, $1! Аргументов: $#"
}
greet Анна
greet Борис "и Вера"
type greet
```

Функция может вернуть результат **двумя разными способами**, и важно их не путать:

| Способ | Что это | Как получить |
|---|---|---|
| `return N` | **код завершения** (0–255): «получилось / не получилось» | `$?`, `if функция; then` |
| `echo …` | **текст**, «значение» | `result=$(функция)` |

```bash run
is_even() {
  (( $1 % 2 == 0 ))
}
double() {
  echo $(( $1 * 2 ))
}
if is_even 4; then echo "4 — чётное"; fi
is_even 7 || echo "7 — нечётное"
result=$(double 21)
echo "результат: $result"
```

`is_even` не печатает ничего: её ответ — код завершения последней команды (`(( … ))` вернула «истина» или «ложь»); поэтому её удобно использовать в `if`. `double` печатает число, и мы забираем его через `$(…)`.

**`local`** делает переменную видимой только внутри функции. Без `local` переменные **общие** для всего скрипта:

```bash run
total=100
with_local() {
  local total=5
  total=$((total + 1))
  echo "внутри: $total"
}
without_local() {
  total=$((total + 1))
  echo "внутри: $total"
}
with_local
echo "после with_local: $total"
without_local
echo "после without_local: $total"
```

### result
```out auto
```

`with_local` не тронула внешнюю `total`, а `without_local` изменила её. **Правило:** все переменные внутри функций объявляй через `local`.

### why
Функции убирают повторы (одно изменение — в одном месте), дают имена кускам кода («проверить_папку») и делают скрипт читаемым. А различие «код или вывод» — ключ к тому, как функции вообще общаются с остальным скриптом.

### deep Как ещё можно
- `declare -f имя` печатает код функции; `unset -f имя` удаляет её.
- Рекурсия работает: функция может вызвать саму себя (но будь осторожна с глубиной).
- Вместо `имя() { … }` можно писать `function имя { … }` — работает только в bash, поэтому мы пользуемся первой формой.
- Результат через код ограничен числами 0–255; для всего остального — `echo` и `$(…)`.

### deep Если не получилось
- **`greet: command not found`** — вызвала функцию раньше, чем объявила: в скрипте функция должна быть определена **выше** места вызова.
- **В `result` пусто** — функция ничего не напечатала (она вернула код, а не текст).

### quiz
- Чем `return 1` отличается от `echo 1` с точки зрения вызывающего?
- Что делает `local`? Что случится без него?
- Откуда функция берёт свои аргументы и чем они отличаются от аргументов скрипта?

### links
- https://www.gnu.org/software/bash/manual/html_node/Shell-Functions.html | функции | Bash: Shell Functions

## 5.2 Библиотека: source, лог и die | short: Библиотека lib/common.sh | est: ~30 мин
### intro
**Слова шага:** `source`, *библиотека функций*, *защита от двойного подключения*, *stderr*, `$BASH_SOURCE`, `die`.

Когда одни и те же функции нужны разным скриптам, их выносят в **библиотеку** — файл, который подключают командой `source` (шаг 2.1). Создадим `lib/common.sh` с функциями журнала:

```bash run
cd /work/coffeeops
cat > lib/common.sh <<'EOF'
#!/usr/bin/env bash
# Общие функции CoffeeOps. Подключение: source "$ROOT/lib/common.sh"

# защита от двойного подключения
[[ -n "${COMMON_LOADED:-}" ]] && return 0
COMMON_LOADED=1

# в каком режиме писать: info (по умолчанию) или debug
LOG_LEVEL="${LOG_LEVEL:-info}"

_ts() { date '+%F %T'; }
log()   { printf '%s [INFO]  %s\n' "$(_ts)" "$*" >&2; }
warn()  { printf '%s [WARN]  %s\n' "$(_ts)" "$*" >&2; }
debug() { [[ "$LOG_LEVEL" == debug ]] && printf '%s [DEBUG] %s\n' "$(_ts)" "$*" >&2; return 0; }
die()   { local code="${2:-1}"; printf '%s [ERROR] %s\n' "$(_ts)" "$1" >&2; exit "$code"; }
EOF
```

**Разбор.** `[[ -n … ]] && return 0` — если библиотека уже подключена, выйти из неё сразу (`return` из подключённого файла); `LOG_LEVEL="${LOG_LEVEL:-info}"` — уровень можно задать снаружи: `LOG_LEVEL=debug ./скрипт`; `printf '…' "$*"` — печать с временем; **`>&2`** — вывод идёт в **stderr** (канал ошибок и сообщений журнала), а не в `stdout` (канал данных): так журнал не смешивается с результатом скрипта (подробно — в сессии 6); `"$*"` склеивает все аргументы в одну строку; `die` печатает ошибку и завершает скрипт с кодом (по умолчанию 1).

Как скрипту найти библиотеку, откуда бы его ни запустили? По расположению **самого скрипта**:

```bash run
cat > bin/lib-demo.sh <<'EOF'
#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/common.sh"   # повторное подключение безвредно

log "библиотека подключена, корень проекта: $ROOT"
warn "это предупреждение"
debug "это видно только при LOG_LEVEL=debug"
[[ -d "${1:-}" ]] || die "нужна папка, а не '${1:-}'" 2
log "до сюда не дойдём"
EOF
chmod +x bin/lib-demo.sh
./bin/lib-demo.sh
echo "код: $?"
LOG_LEVEL=debug ./bin/lib-demo.sh orders
cd /tmp && /work/coffeeops/bin/lib-demo.sh 2>&1 | head -n 1
```

**Как найден корень.** `${BASH_SOURCE[0]}` — путь к файлу самого скрипта (пока считай «имя этого файла»; о квадратных скобках — в сессии 7); `dirname` отрезает имя файла и оставляет папку; `cd … && pwd` превращает её в абсолютный путь. Благодаря этому скрипт работает одинаково, откуда бы его ни запустили.

### result
```out auto
```

### why
Сообщения журнала с временем и уровнем — это то, что ты будешь читать, когда скрипт упал ночью. А `die` в одну строку заменяет повторяющееся «напечатать ошибку и выйти». Библиотека — единственное место, где это написано.

### deep Как ещё можно
- `.` — короткое имя `source`: `. "$ROOT/lib/common.sh"`.
- Цвета в журнале: `printf '\033[31m'` (красный) — но только если вывод идёт в терминал (`[[ -t 2 ]]`), иначе в файле журнала окажутся «мусорные» символы.
- Для больших проектов библиотеки делят по темам: `lib/log.sh`, `lib/fs.sh`.

### deep Если не получилось
- **`No such file or directory`** при `source` — неверный путь к библиотеке; проверь `ROOT` (`echo "$ROOT"`).
- **`return: can only 'return' from a function or sourced script`** — файл с `return` запущен как программа, а не подключён через `source`.

### quiz
- Зачем в библиотеке строка `[[ -n "${COMMON_LOADED:-}" ]] && return 0`?
- Почему журнал пишут в `stderr` (`>&2`), а не в обычный вывод?
- Как скрипт находит библиотеку, если запущен из другой папки?

### links
- https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html | source, return, exit | Bash: Bourne Shell Builtins

## 5.3 Опции скрипта: getopts и usage | short: getopts | est: ~30 мин
### intro
**Слова шага:** *опция (ключ)*, `getopts`, `OPTARG`, `OPTIND`, `usage`.

Хорошие утилиты принимают не только позиции (`$1`), но и **опции**: `-v` (подробно), `-d папка`, `-h` (справка). Для разбора есть встроенная команда `getopts`:

```bash run
cd /work/coffeeops
cat > bin/opts-demo.sh <<'EOF'
#!/usr/bin/env bash
usage() {
  echo "Использование: opts-demo.sh [-v] [-d ПАПКА] [-h] ФАЙЛ..."
}

verbose=0
dir="orders"
while getopts ":vd:h" opt; do
  case "$opt" in
    v) verbose=1 ;;
    d) dir="$OPTARG" ;;
    h) usage; exit 0 ;;
    :) echo "Опции -$OPTARG нужен аргумент" >&2; usage >&2; exit 2 ;;
    \?) echo "Неизвестная опция: -$OPTARG" >&2; usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

echo "verbose=$verbose dir=$dir остальное: $*"
EOF
chmod +x bin/opts-demo.sh
./bin/opts-demo.sh
./bin/opts-demo.sh -v -d logs a.txt b.txt
./bin/opts-demo.sh -h
./bin/opts-demo.sh -x
./bin/opts-demo.sh -d
echo "код: $?"
```

**Разбор.** `getopts ":vd:h" opt` читает аргументы по одному. Строка `":vd:h"`: буквы — допустимые опции; `d:` — после неё есть значение (двоеточие); двоеточие в самом начале включает «тихий» режим (ошибки обрабатываем сами). В переменной `opt` — очередная опция; значение лежит в `OPTARG`. В `case` ветки `:` и `\?` ловят «нет значения» и «неизвестная опция». После цикла `shift $((OPTIND - 1))` убирает разобранные опции, и в `$@` остаются обычные аргументы.

### result
```out auto
```

### why
Опции делают скрипт гибким без правки кода и понятным другим (`-h` покажет справку). `getopts` — стандартный способ: короткие ключи, которые работают так же, как в привычных утилитах.

### deep Как ещё можно
- Длинные опции вида `--verbose` `getopts` не понимает; для них пишут свой разбор в `case` в `while (( $# ))`, но для небольших скриптов хватает коротких.
- Опции можно склеивать: `-vd logs` — `getopts` разберёт.
- `--` — «дальше опций нет» (так передают аргументы, начинающиеся с `-`).

### deep Если не получилось
- **Опции игнорируются** — `getopts` не вызывался до обычной обработки `$1`, либо забыт `shift $((OPTIND - 1))`.
- **`OPTARG` пусто** — после буквы опции в строке нет двоеточия (`d`, а надо `d:`).

### quiz
- Что значит двоеточие после буквы в `":vd:h"` и двоеточие в самом начале?
- Где лежит значение опции `-d logs`?
- Зачем нужен `shift $((OPTIND - 1))`?

### links
- https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html | getopts | Bash: Bourne Shell Builtins

## 5.4 ShellCheck: линтер для скриптов | short: shellcheck | est: ~30 мин
### intro
**Слова шага:** *линтер*, `shellcheck`, *предупреждение SCxxxx*.

**Линтер** — программа, которая читает твой код и находит в нём вероятные ошибки **без запуска**. Для bash это `shellcheck`; он уже есть в нашем образе. Создадим скрипт с типичными ошибками:

```bash run
cd /work/coffeeops
cat > bin/bad.sh <<'EOF'
#!/usr/bin/env bash
files=$(ls orders)
for f in $files; do
  cat orders/$f | wc -l
done
cd logs
rm -rf $TMPDIR/*
echo "Готово: $count"
EOF
shellcheck bin/bad.sh
```

Каждое предупреждение имеет код `SCxxxx`, строку и объяснение; по коду можно прочитать подробности на `shellcheck.net/wiki/SC2086`. Основные, которые встречаются чаще всего:

| Код | Смысл | Как чинить |
|---|---|---|
| SC2086 | переменная без кавычек: возможна порча из-за пробелов и `*` | `"$var"` |
| SC2045 | перебор вывода `ls` | шаблон `for f in dir/*` |
| SC2164 | `cd` может не сработать | `cd dir \|\| exit` |
| SC2155 | `local x=$(cmd)` скрывает код ошибки команды | объяви и присвой отдельно |
| SC2034 | переменная задана, но не используется | убрать или экспортировать |
| SC2154 | переменная используется, но нигде не задана | проверить опечатку |
| SC2148 | нет shebang | добавить первую строку |

Исправим и проверим снова:

```bash run
cat > bin/bad.sh <<'EOF'
#!/usr/bin/env bash
for f in orders/*.csv; do
  wc -l < "$f"
done
cd logs || exit 1
rm -rf "${TMPDIR:?}"/*
echo "Готово"
EOF
shellcheck bin/bad.sh && echo "shellcheck: замечаний нет"
```

### result
```out auto
```

### why
`shellcheck` находит те самые ловушки из сессий 2–4 (кавычки, `ls`, `cd`) за секунду, до того как они навредят. Опытные люди проверяют им каждый скрипт.

### deep Как ещё можно
- Отключить предупреждение для строки: комментарий `# shellcheck disable=SC2086` над ней (с пояснением, зачем).
- `shellcheck -x` — следовать за `source`; указать, где искать подключаемый файл, можно комментарием `# shellcheck source=lib/common.sh` или настройкой `source-path=SCRIPTDIR` в файле `.shellcheckrc` (так сделаем в шаге 5.6).
- Подключить к редактору (VS Code: расширение ShellCheck) и к проверкам в GitHub Actions.
- Онлайн-версия — `shellcheck.net`: вставил код, получил результат.

### deep Если не получилось
- **`shellcheck: command not found`** — образ собран без него; пересобери образ (шаг 1.2) или поставь на Mac: `brew install shellcheck`.
- **Замечание «не понимаю»** — открой страницу вики по коду `SCxxxx`: там пример «плохо / хорошо».

### quiz
- Что такое линтер и чем он лучше «запустить и посмотреть»?
- Что означают SC2086 и SC2164? Как исправить каждое?
- Как отключить предупреждение для одной строки?

### links
- https://www.shellcheck.net/wiki/ | вики с описанием каждого SC-кода | ShellCheck Wiki
- https://github.com/koalaman/shellcheck | репозиторий и установка | ShellCheck на GitHub

## 5.5 🔨 Сломать → починить: утечка переменной из функции | short: Сломать → починить | est: ~20 мин
### intro
:::trap Сломать → починить
Функция «портит» чужую переменную, а скрипт считает неверно. Найди причину.
:::

```bash run
cd /work/coffeeops
cat > bin/leak.sh <<'EOF'
#!/usr/bin/env bash
total=0

add_item() {
  price=$1
  total=$((total + price))
}

for price in 180 120 200; do
  add_item "$price"
  echo "цена в цикле: $price, итого: $total"
done
EOF
chmod +x bin/leak.sh
./bin/leak.sh
```

Цикл перебирает цены `180 120 200`, но функция тоже называет свою переменную `price` и **перезаписывает** переменную цикла. Здесь совпадение безобидное (`price` получает то же значение), но стоит функции изменить `price` по-другому, и счёт собьётся. **Почини:** `local` для всех внутренних переменных функции:

```bash run
cat > bin/leak.sh <<'EOF'
#!/usr/bin/env bash
total=0

add_item() {
  local item_price=$1
  total=$((total + item_price))
}

for price in 180 120 200; do
  add_item "$price"
  echo "цена в цикле: $price, итого: $total"
done
EOF
./bin/leak.sh
shellcheck bin/leak.sh && echo "shellcheck: чисто"
```

Теперь пример, где утечка действительно ломает результат:

```bash run
cat > bin/leak2.sh <<'EOF'
#!/usr/bin/env bash
apply_discount() {
  i=0
  while (( i < 3 )); do ((i++)); done
}

for i in 1 2 3; do
  apply_discount
  echo "заказ номер $i"
done
EOF
chmod +x bin/leak2.sh
./bin/leak2.sh
```

### result
```out auto
```

Цикл должен печатать номера 1, 2, 3, а печатает три раза «3»: функция `apply_discount` использует свой счётчик с тем же именем `i`, доводит его до 3 и **портит** `i` цикла. Одно слово — `local i=0` — решило бы проблему.

### why
Утечка переменной — один из самых неприятных багов: функция «работает», а скрипт ведёт себя странно, причём где-то далеко от места ошибки. Правило «внутри функций — всегда `local`» избавляет от него полностью.

### deep Как ещё можно
- `shellcheck` не всегда замечает такие утечки; помогает привычка: каждая переменная функции объявляется `local` в её первой строке.
- Для констант и переменных, которые должны быть общими, используют заглавные имена (`LOG_LEVEL`) и объявляют их вне функций.

### deep Если не получилось
- **Вывод другой** — проверь, что в `leak2.sh` у функции нет слова `local`: именно его отсутствие и показывает проблему.

### quiz
- Почему переменная цикла и переменная функции столкнулись?
- Как одним словом изолировать переменную функции?
- Как отличить «общую» переменную от «внутренней» в чужом скрипте?

### outro
:::tip Приёмка шага
Ты умеешь изолировать переменные функций и узнаёшь утечки по поведению.
:::

## 5.6 Проект: рефакторинг в общую библиотеку | short: Рефакторинг проекта | est: ~35 мин
### intro
**Слова шага:** *рефакторинг*, *общая библиотека*, *структура проекта*.

Приведём проект CoffeeOps в порядок: демонстрации из сессий 2–5 переедем в папку `playground/`, а рабочие скрипты (`order.sh`, `stats.sh`, `backup.sh`) перепишем на общую библиотеку и новые приёмы.

```bash run
cd /work/coffeeops
mkdir -p playground
mv bin/hello.sh bin/setvar.sh bin/args.sh bin/all.sh bin/defaults.sh bin/nostrict.sh bin/strict.sh \
   bin/clean.sh bin/slow.sh bin/backup-broken.sh bin/lib-demo.sh bin/opts-demo.sh bin/bad.sh \
   bin/leak.sh bin/leak2.sh playground/
ls bin playground
```

Новый `stats.sh` — с опциями `-d ПАПКА`, `-v` и справкой, на библиотеке:

```bash run
cat > bin/stats.sh <<'EOF'
#!/usr/bin/env bash
# Итоги по файлам заказов. Использование: stats.sh [-d ПАПКА] [-v] [-h]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"

usage() { echo "Использование: stats.sh [-d ПАПКА] [-v] [-h]"; }

dir="$ROOT/orders"
while getopts ":d:vh" opt; do
  case "$opt" in
    d) dir="$OPTARG" ;;
    v) export LOG_LEVEL=debug ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -d "$dir" ]] || die "нет папки '$dir'" 2

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

total_all=0
for f in "$dir"/*.csv; do
  [[ -e "$f" ]] || continue
  debug "обрабатываю $f"
  rows=$(( $(wc -l < "$f") - 1 ))
  sum=$(awk -F, 'NR > 1 { s += $3 * $4 } END { print s + 0 }' "$f")
  echo "$(basename "$f"): заказов $rows, выручка $sum руб."
  echo "$sum $(basename "$f")" >> "$tmp"
  total_all=$((total_all + sum))
done

echo "ИТОГО: $total_all руб."
echo "Лучший день: $(sort -rn "$tmp" | head -n 1 | cut -d' ' -f2)"
EOF
./bin/stats.sh
./bin/stats.sh -v -d orders 2>&1 | head -n 3
./bin/stats.sh -d нет
echo "код: $?"
```

Тем же способом перепишем `order.sh` (цены и проверки те же, но ошибки идут через `die`), а `backup.sh` получит журнал:

```bash run
cat > bin/order.sh <<'EOF'
#!/usr/bin/env bash
# Использование: order.sh ТОВАР [КОЛИЧЕСТВО]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"

[[ $# -ge 1 ]] || die "Использование: order.sh ТОВАР [КОЛИЧЕСТВО]" 2

item="$1"
qty="${2:-1}"
if ! [[ "$qty" =~ ^[0-9]+$ ]] || (( qty < 1 )); then
  die "количество должно быть целым числом больше нуля, а не '$qty'" 2
fi

case "$item" in
  latte)      price=180 ;;
  espresso)   price=120 ;;
  cappuccino) price=200 ;;
  americano)  price=140 ;;
  tea)        price=100 ;;
  *)          die "нет такого товара: '$item'" 2 ;;
esac

total=$((qty * price))
if (( qty >= 5 )); then
  total=$((total - total / 10))
  log "скидка 10% за $qty порций"
fi
echo "Заказ: $item x $qty = $total руб."
EOF
cat > bin/backup.sh <<'EOF'
#!/usr/bin/env bash
# Архив заказов в backup/. Использование: backup.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"

mkdir -p "$ROOT/backup"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

log "собираю архив заказов"
tar -czf "$tmp" -C "$ROOT" orders
mv "$tmp" "$ROOT/backup/orders.tgz"
log "готово: $(wc -c < "$ROOT/backup/orders.tgz") байт"
EOF
cat > .shellcheckrc <<'EOF'
# настройки shellcheck для проекта: идти по source и искать файлы рядом со скриптом
external-sources=true
source-path=SCRIPTDIR
EOF
chmod +x bin/order.sh bin/backup.sh bin/stats.sh
./bin/order.sh latte 2
./bin/order.sh pizza
echo "код: $?"
./bin/backup.sh
shellcheck bin/*.sh lib/common.sh seed.sh && echo "shellcheck: замечаний нет"
```

### result
```out auto
```

### why
Скрипты теперь короче и одинаковы по устройству: подключили библиотеку, разобрали опции, проверили вход, сделали работу. Новый скрипт проекта теперь пишется по шаблону за минуты. А `shellcheck` без замечаний — самый короткий способ убедиться, что в них нет типичных ловушек.

### deep Как ещё можно
- Шаблон «каркаса скрипта» можно сохранить как файл `lib/template.sh` и копировать при создании нового.
- `bin/coffeeops.sh` (из сессии 3) тоже можно перевести на эти функции — сделаем в сессии 9.

### deep Если не получилось
- **`shellcheck` ругается на `source` («Not following»)** — проверь, что рядом лежит `.shellcheckrc` и над `source` есть комментарий `# shellcheck source=../lib/common.sh`; либо запускай `shellcheck -x -P SCRIPTDIR файл`.
- **`stats.sh` не находит `lib/common.sh`** — вы запускаете из другой папки, а `ROOT` вычислен неверно; проверь строку `ROOT=…` (шаг 5.2).

### quiz
- Какую пользу даёт общая библиотека по сравнению с копией кода в каждом скрипте?
- Как `stats.sh` понимает, что его запустили с `-v`?
- Зачем нужен файл `.shellcheckrc` и комментарий `# shellcheck source=…` над `source`?

### outro
:::tip Приёмка сессии 5
Ты можешь: писать функции с `local` и различать «код» и «вывод»; подключать библиотеку и находить её по пути скрипта; разбирать опции `getopts` и показывать справку; запускать `shellcheck` и читать SC-коды. Все скрипты проекта проходят `shellcheck` без замечаний.
:::
