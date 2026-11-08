#!/usr/bin/fish

# ==============================================================================
# GameMode Start Hook: Segregazione Dinamica Dual-CCD (AMD Ryzen 9 5900X)
# ==============================================================================
# CCD0 (Golden CCD / 0-5,12-17): KWin Wayland, Stack Audio, Wine/Proton/Game
# CCD1 (Secondary CCD / 6-11,18-23): Tutti gli altri processi utente & background
# ==============================================================================

set -l CCD0 "0-5,12-17"
set -l CCD1 "6-11,18-23"
set -l my_uid (id -u)

# 1. Whitelist pattern per identificare i processi prioritari da mantenere su CCD0
set -l ccd0_patterns "kwin_wayland|pipewire|pipewire-pulse|wireplumber|easyeffects|gamemoded|steam|steamwebhelper|wine|wine64|wineserver|pressure-vessel|gamescope|\.exe"

# 2. Sposta esplicitamente KWin Wayland, Stack Audio ed eventuali processi Wine/Game su CCD0
set -l audio_compositor_pids (pgrep -u $my_uid -x "kwin_wayland|pipewire|pipewire-pulse|wireplumber|easyeffects")
for p in $audio_compositor_pids
    /usr/bin/taskset -a -cp $CCD0 $p >/dev/null 2>&1
end

set -l game_pids (pgrep -u $my_uid -f "wine|wine64|wineserver|pressure-vessel|gamescope|\.exe")
for p in $game_pids
    /usr/bin/taskset -a -cp $CCD0 $p >/dev/null 2>&1
end

# 3. Segrega tutti gli altri processi utente attivi su CCD1
# I nuovi thread e processi generati da queste app erediteranno automaticamente CCD1
set -l all_user_pids (pgrep -u $my_uid)
set -l ccd0_pids (pgrep -u $my_uid -f "$ccd0_patterns")

for p in $all_user_pids
    if test "$p" != "$fish_pid"; and not contains -- $p $ccd0_pids
        /usr/bin/taskset -a -cp $CCD1 $p >/dev/null 2>&1
    end
end


