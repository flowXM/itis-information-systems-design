#!/usr/bin/env bash

usage() {
    echo "Использование: $0 [--path каталог] [--mask маска] [--number число] команда" >&2
    exit 1
}

directory=.
mask='*'
number=$(nproc)

while (($# > 0)); do
    case "$1" in
        --path|--mask|--number)
            (($# >= 2)) || usage
            case "$1" in
                --path) directory=$2 ;;
                --mask) mask=$2 ;;
                --number) number=$2 ;;
            esac
            shift 2
            ;;
        --) shift; break ;;
        --*) usage ;;
        *) break ;;
    esac
done
(($# == 1)) || usage
command=$1

if [[ ! -d "$directory" || -z "$mask" ]]; then
    echo "Ошибка: нужен существующий каталог и непустая маска." >&2
    exit 1
fi
if [[ ! "$number" =~ ^[0-9]+$ ]]; then
    echo "Ошибка: число процессов должно быть целым и больше нуля." >&2
    exit 1
fi
# Убираем ведущие нули без арифметики, затем проверяем диапазон Bash.
while [[ ${#number} -gt 1 && "$number" == 0* ]]; do number=${number:1}; done
if [[ "$number" == 0 || ${#number} -gt 18 ]]; then
    echo "Ошибка: число процессов должно быть от 1 до 999999999999999999." >&2
    exit 1
fi

# Команду можно передать путём или обычным именем из PATH, например gzip.
if [[ "$command" != */* ]]; then
    command=$(type -P -- "$command") || {
        echo "Ошибка: команда не найдена." >&2
        exit 1
    }
fi
if [[ ! -f "$command" || ! -x "$command" ]]; then
    echo "Ошибка: команда должна быть исполняемым файлом." >&2
    exit 1
fi
directory=$(realpath -- "$directory") || exit 1

shopt -s nullglob dotglob
pids=()
for file in "$directory"/*; do
    [[ -f "$file" && ! -L "$file" ]] || continue
    filename=${file##*/}
    [[ "$filename" == $mask ]] || continue

    # Пока все места заняты, ждём завершения любого процесса.
    while (($(jobs -pr | wc -l) >= number)); do
        wait -n || :
    done

    "$command" "$file" &
    pids+=("$!")
done

# Дожидаемся всех запущенных процессов и собираем их статусы.
result=0
for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
        result=1
    fi
done
exit "$result"
