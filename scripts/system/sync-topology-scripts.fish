#!/usr/bin/fish

# ==============================================================================
# Sync Topology Scripts (AMD Ryzen 9 5900X / CachyOS)
# ==============================================================================
# Confronta gli script presenti nella repository git con i percorsi di sistema
# (~/.local/bin/ e /etc/gamemode.ini) e permette di sincronizzarli su conferma.
#
# Uso:
#   fish scripts/system/sync-topology-scripts.fish          (modalità interattiva)
#   fish scripts/system/sync-topology-scripts.fish --check  (solo verifica silenziosa, exit 0/1)
# ==============================================================================

set -l repo_dir (git -C (status dirname) rev-parse --show-toplevel 2>/dev/null; or echo "$HOME/GitHub/handling-linux")

set -l files_user \
    "scripts/system/game-start.fish:$HOME/.local/bin/game-start.fish" \
    "scripts/system/game-end.fish:$HOME/.local/bin/game-end.fish" \
    "scripts/system/sync-topology-scripts.fish:$HOME/.local/bin/sync-topology-scripts.fish" \
    "scripts/tests/check_ccd_topology.fish:$HOME/.local/bin/check-topology.fish"

set -l files_system \
    "config/gamemode.ini:/etc/gamemode.ini"

set -l mode "interactive"
if test "$argv[1]" = "--check"
    set mode "check"
end

set -l diff_found 0
set -l diff_user
set -l diff_sys

# Controllo file utente (~/.local/bin)
for pair in $files_user
    set -l parts (string split ":" $pair)
    set -l src "$repo_dir/$parts[1]"
    set -l dst "$parts[2]"

    if not test -f "$dst"; or not cmp -s "$src" "$dst"
        set diff_found 1
        set -a diff_user $pair
    end
end

# Controllo file di sistema (/etc/)
for pair in $files_system
    set -l parts (string split ":" $pair)
    set -l src "$repo_dir/$parts[1]"
    set -l dst "$parts[2]"

    if not test -f "$dst"; or not cmp -s "$src" "$dst"
        set diff_found 1
        set -a diff_sys $pair
    end
end

if test "$mode" = "check"
    test $diff_found -eq 0; and exit 0; or exit 1
end

# Modalità interattiva
echo "================================================================="
echo "   Sincronizzazione Script di Topologia CCD con il Sistema       "
echo "================================================================="
echo ""

if test $diff_found -eq 0
    set_color green
    echo "[OK] Tutti gli script di sistema sono perfettamente allineati alla repository."
    set_color normal
    echo ""
    
    # Controllo rapido capability taskset per KWin
    set -l taskset_caps (getcap /usr/bin/taskset 2>/dev/null)
    if not string match -q "*cap_sys_nice*" "$taskset_caps"
        set_color yellow
        echo "[SUGGERIMENTO] Per consentire a taskset di modificare l'affinità di KWin Wayland (CAP_SYS_NICE)"
        echo "               senza richiedere permessi di root, esegui una tantum:"
        echo "               sudo setcap cap_sys_nice+ep /usr/bin/taskset"
        set_color normal
        echo ""
    end
    exit 0
end

set_color yellow
echo "[!] Rilevate differenze tra la repository e i file di sistema:"
set_color normal
echo ""

for pair in $diff_user
    set -l parts (string split ":" $pair)
    echo " - [User Script] $parts[1] -> $parts[2]"
end

for pair in $diff_sys
    set -l parts (string split ":" $pair)
    echo " - [System Config] $parts[1] -> $parts[2] (richiede sudo)"
end

echo ""
read -l -P "Vuoi procedere con la sincronizzazione dei file? [S/n]: " answer

if test -z "$answer"; or string match -ri "^(s|si|y|yes)\$" "$answer"
    echo ""
    echo "-> Sincronizzazione script utente in ~/.local/bin/..."
    mkdir -p ~/.local/bin
    for pair in $diff_user
        set -l parts (string split ":" $pair)
        set -l src "$repo_dir/$parts[1]"
        set -l dst "$parts[2]"
        cp -f "$src" "$dst"
        chmod +x "$dst"
        echo "   [OK] Aggiornato $dst"
    end

    if test (count $diff_sys) -gt 0
        echo ""
        echo "-> Sincronizzazione configurazione di sistema (/etc/gamemode.ini)..."
        for pair in $diff_sys
            set -l parts (string split ":" $pair)
            set -l src "$repo_dir/$parts[1]"
            set -l dst "$parts[2]"
            sudo cp -f "$src" "$dst"
            echo "   [OK] Aggiornato $dst"
        end
        echo "-> Riavvio del demone gamemoded..."
        systemctl --user restart gamemoded
    end

    # Controllo e suggerimento capability taskset
    set -l taskset_caps (getcap /usr/bin/taskset 2>/dev/null)
    if not string match -q "*cap_sys_nice*" "$taskset_caps"
        echo ""
        set_color yellow
        echo "[ATTENZIONE] KWin Wayland utilizza CAP_SYS_NICE per il rendering a bassa latenza."
        echo "             Affinché game-start/game-end possano spostare KWin tra i CCD senza sudo,"
        echo "             assegna la capability a taskset con il seguente comando:"
        echo ""
        set_color cyan
        echo "             sudo setcap cap_sys_nice+ep /usr/bin/taskset"
        set_color normal
    end

    echo ""
    set_color green
    echo "[COMPLETATO] Tutti i file sono stati sincronizzati con successo!"
    set_color normal
    echo ""
else
    echo ""
    echo "Operazione annullata dall'utente."
    echo ""
end
