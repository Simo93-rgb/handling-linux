#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

required_paths=(
    README.md
    components
    components/platforms
    diagrams
    scripts/checks
)

failures=0

for path in "${required_paths[@]}"; do
    if [[ ! -e "$path" ]]; then
        printf 'ERRORE: percorso richiesto assente: %s\n' "$path" >&2
        failures=$((failures + 1))
    fi
done

while IFS= read -r source; do
    while IFS= read -r match; do
        target="${match#*\(}"
        target="${target%\)}"
        target="${target%%#*}"
        target="${target%%\?*}"

        [[ -z "$target" || "$target" == /* ]] && continue
        [[ "$target" == *://* || "$target" == mailto:* ]] && continue

        source_dir="$(dirname "$source")"
        if [[ ! -e "$source_dir/$target" ]]; then
            printf 'ERRORE: link locale non risolto: %s -> %s\n' "$source" "$target" >&2
            failures=$((failures + 1))
        fi
    done < <(grep -oE '\]\([^)]*\)' "$source" || true)
done < <(find README.md components diagrams -type f \( -name '*.md' -o -name '*.mmd' \) -print | sort)

while IFS= read -r script; do
    first_line="$(head -n 1 "$script")"
    case "$first_line" in
        '#!'*'/bash'*)
            if ! bash -n "$script"; then
                printf 'ERRORE: sintassi Bash non valida: %s\n' "$script" >&2
                failures=$((failures + 1))
            fi
            ;;
        '#!'*'/fish'*)
            if command -v fish >/dev/null 2>&1 && ! fish --no-config -n "$script"; then
                printf 'ERRORE: sintassi Fish non valida: %s\n' "$script" >&2
                failures=$((failures + 1))
            fi
            ;;
    esac
done < <(find components scripts -type f \( -name '*.sh' -o -name '*.fish' \) -print | sort)

if (( failures > 0 )); then
    printf 'Controllo repository fallito: %d problema/i.\n' "$failures" >&2
    exit 1
fi

printf 'Controllo repository superato.\n'
