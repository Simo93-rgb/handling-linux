#!/usr/bin/fish

set EXPECTED_CCD0 "0-5,12-17"
set EXPECTED_SYSTEM "0-23"
set -l wine_pids (pidof wine64-preloader)
set -l expected_latency $EXPECTED_SYSTEM

if test -n "$wine_pids"
    set expected_latency $EXPECTED_CCD0
end

function print_status -a label pid expected
    if test -z "$pid"
        echo (set_color yellow)"[-] $label: Processo non trovato (non in esecuzione)"(set_color normal)
        return
    end

    for p in (string split " " $pid)
        set -l current_mask (taskset -cp $p 2>/dev/null | string split ":" | tail -n 1 | string trim)

        if test "$current_mask" = "$expected"
            echo (set_color green)"[OK] $label (PID: $p)"(set_color normal)" -> Maschera: "(set_color cyan)"$current_mask"(set_color normal)" (Atteso: $expected)"
        else
            echo (set_color red)"[FAIL] $label (PID: $p)"(set_color normal)" -> Maschera: "(set_color red)"$current_mask"(set_color normal)" (Atteso: $expected)"
        end
    end
end

echo "========================================================="
echo "   Verifica Topologia e Segregazione CCD (Ryzen 9 5900X)   "
echo "========================================================="
echo ""

echo (set_color --bold)"--- 1. Target KWin/Audio (atteso -> $expected_latency) ---"(set_color normal)
# KWin Wayland
set -l kwin_pids (pidof kwin_wayland)
print_status "KWin Wayland Compositor" "$kwin_pids" "$expected_latency"

# PipeWire & WirePlumber
set -l pipewire_pids (pidof pipewire)
set -l pipewire_pulse_pids (pidof pipewire-pulse)
set -l wireplumber_pids (pidof wireplumber)
print_status "PipeWire Core Server   " "$pipewire_pids" "$expected_latency"
print_status "PipeWire Pulse Daemon  " "$pipewire_pulse_pids" "$expected_latency"
print_status "WirePlumber Session Mgr" "$wireplumber_pids" "$expected_latency"

# Wine / Proton
if test -n "$wine_pids"
    print_status "Wine Game Process      " "$wine_pids" "$EXPECTED_CCD0"
else
    echo (set_color yellow)"[-] Wine Game Process      : Nessun gioco Proton/Wine attivo al momento"(set_color normal)
end

echo ""
echo (set_color --bold)"--- 2. User-Space libero (tutti i thread -> $EXPECTED_SYSTEM) ---"(set_color normal)
set -l kate_pids (pidof kate)
set -l dolphin_pids (pidof dolphin)
set -l network_manager_pids (pidof NetworkManager)
print_status "Kate Text Editor       " "$kate_pids" "$EXPECTED_SYSTEM"
print_status "Dolphin File Manager   " "$dolphin_pids" "$EXPECTED_SYSTEM"
print_status "NetworkManager (system)" "$network_manager_pids" "$EXPECTED_SYSTEM"

echo ""
echo "========================================================="