#!/usr/bin/fish

set EXPECTED_CCD0 "0-5,12-17"
set EXPECTED_CCD1 "6-11,18-23"
set EXPECTED_ALL  "0-23"

# Rilevamento percorsi e controllo disallineamento script
set -l repo_dir (git -C (status dirname) rev-parse --show-toplevel 2>/dev/null; or echo "$HOME/GitHub/handling-linux")
set -l sync_script "$repo_dir/scripts/system/sync-topology-scripts.fish"
if not test -f "$sync_script"
    set sync_script "$HOME/.local/bin/sync-topology-scripts.fish"
end

if test -f "$sync_script"
    if not fish "$sync_script" --check
        set_color yellow
        echo "================================================================="
        echo " [AVVISO] Rilevate differenze tra la repo e i file di sistema!   "
        echo "================================================================="
        set_color normal
        fish "$sync_script"
        echo ""
    end
end

# Rilevamento processi di gioco Wine / Proton (cercando wineserver o eseguibili .exe attivi)
set -l wine_pids (pgrep -u (id -u) -x "wineserver|wine64-preloader"; or pgrep -u (id -u) -f "\.exe")


function print_status -a label pids expected
    set -l pid_list (string split " " (string join " " $pids))
    set -l valid_pids
    for p in $pid_list
        test -n "$p"; and set -a valid_pids $p
    end

    if test (count $valid_pids) -eq 0
        set_color yellow
        echo "[-] $label: Processo non trovato (non in esecuzione)"
        set_color normal
        return
    end

    for p in $valid_pids
        set -l current_mask (taskset -cp $p 2>/dev/null | string split ":" | tail -n 1 | string trim)
        test -z "$current_mask"; and continue

        if test "$current_mask" = "$expected"
            set_color green
            printf "[OK] "
            set_color normal
            printf "%-25s (PID: %-7s) -> Maschera: " "$label" "$p"
            set_color cyan
            printf "%-12s" "$current_mask"
            set_color normal
            echo " (Atteso: $expected)"
        else
            set_color red
            printf "[FAIL] "
            set_color normal
            printf "%-25s (PID: %-7s) -> Maschera: " "$label" "$p"
            set_color red
            printf "%-12s" "$current_mask"
            set_color normal
            echo " (Atteso: $expected)"
        end
    end
end

echo "================================================================="
echo "      Verifica Topologia e Segregazione CCD (Ryzen 9 5900X)      "
echo "================================================================="
echo ""

if test (count $wine_pids) -gt 0
    set_color --bold
    echo "[STATO ATTIVO: SESSIONE GAMING RILEVATA]"
    set_color cyan
    echo " -> CCD0 ($EXPECTED_CCD0) per Gaming / Audio / Compositor"
    echo " -> CCD1 ($EXPECTED_CCD1) per Background / User-Space"
    set_color normal
    echo ""

    set_color --bold
    echo "--- 1. Target CCD0: Gaming, Compositor & Audio (atteso: $EXPECTED_CCD0) ---"
    set_color normal
    set -l kwin_pids (pidof kwin_wayland)
    set -l pipewire_pids (pidof pipewire)
    set -l pipewire_pulse_pids (pidof pipewire-pulse)
    set -l wireplumber_pids (pidof wireplumber)
    set -l easyeffects_pids (pidof easyeffects)
    set -l game_main_pids (pgrep -u (id -u) -x "wineserver|wine64-preloader"; or pgrep -u (id -u) -f "Shipping\.exe|\.exe")

    print_status "KWin Wayland Compositor" "$kwin_pids" "$EXPECTED_CCD0"
    print_status "PipeWire Core Server   " "$pipewire_pids" "$EXPECTED_CCD0"
    print_status "PipeWire Pulse Daemon  " "$pipewire_pulse_pids" "$EXPECTED_CCD0"
    print_status "WirePlumber Session Mgr" "$wireplumber_pids" "$EXPECTED_CCD0"
    print_status "EasyEffects DSP Daemon " "$easyeffects_pids" "$EXPECTED_CCD0"
    print_status "Wine / Proton Game     " "$game_main_pids" "$EXPECTED_CCD0"

    echo ""
    set_color --bold
    echo "--- 2. Target CCD1: Desktop & Applicazioni (atteso: $EXPECTED_CCD1) ---"
    set_color normal
    set -l plasma_pids (pidof plasmashell)
    set -l kate_pids (pidof kate)
    set -l dolphin_pids (pidof dolphin)
    set -l browser_pids (pidof firefox brave chrome zen-bin)
    set -l chat_pids (pidof discord vesktop telegram-desktop)

    print_status "KDE Plasma Shell       " "$plasma_pids" "$EXPECTED_CCD1"
    print_status "Kate Text Editor       " "$kate_pids" "$EXPECTED_CCD1"
    print_status "Dolphin File Manager   " "$dolphin_pids" "$EXPECTED_CCD1"
    print_status "Web Browser            " "$browser_pids" "$EXPECTED_CCD1"
    print_status "Chat / Instant Mess.   " "$chat_pids" "$EXPECTED_CCD1"
else
    set_color --bold
    echo "[STATO IDLE: NESSUN GIOCO ATTIVO]"
    set_color cyan
    echo " -> Tutti i 24 thread disponibili (Maschera: $EXPECTED_ALL) per ogni processo"
    set_color normal
    echo ""

    set_color --bold
    echo "--- 1. Target KWin & Stack Audio (atteso: $EXPECTED_ALL) ---"
    set_color normal
    set -l kwin_pids (pidof kwin_wayland)
    set -l pipewire_pids (pidof pipewire)
    set -l pipewire_pulse_pids (pidof pipewire-pulse)
    set -l wireplumber_pids (pidof wireplumber)
    set -l easyeffects_pids (pidof easyeffects)

    print_status "KWin Wayland Compositor" "$kwin_pids" "$EXPECTED_ALL"
    print_status "PipeWire Core Server   " "$pipewire_pids" "$EXPECTED_ALL"
    print_status "PipeWire Pulse Daemon  " "$pipewire_pulse_pids" "$EXPECTED_ALL"
    print_status "WirePlumber Session Mgr" "$wireplumber_pids" "$EXPECTED_ALL"
    print_status "EasyEffects DSP Daemon " "$easyeffects_pids" "$EXPECTED_ALL"

    echo ""
    set_color --bold
    echo "--- 2. User-Space generico (atteso: $EXPECTED_ALL) ---"
    set_color normal
    set -l plasma_pids (pidof plasmashell)
    set -l kate_pids (pidof kate)
    set -l dolphin_pids (pidof dolphin)
    set -l browser_pids (pidof firefox brave chrome zen-bin)

    print_status "KDE Plasma Shell       " "$plasma_pids" "$EXPECTED_ALL"
    print_status "Kate Text Editor       " "$kate_pids" "$EXPECTED_ALL"
    print_status "Dolphin File Manager   " "$dolphin_pids" "$EXPECTED_ALL"
    print_status "Web Browser            " "$browser_pids" "$EXPECTED_ALL"
end

echo ""
echo "================================================================="