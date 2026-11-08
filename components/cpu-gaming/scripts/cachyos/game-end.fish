#!/usr/bin/fish

# ==============================================================================
# GameMode End Hook: Ripristino Topologia Globale (AMD Ryzen 9 5900X)
# ==============================================================================
# Ripristina tutti i processi utente, KWin e lo stack audio sulla maschera 0-23
# garantendo la piena potenza di calcolo (24 thread) per compilazioni e calcolo.
# ==============================================================================

set -l ALL_CORES "0-23"
set -l my_uid (id -u)

# 1. Ripristino KWin Wayland ed EasyEffects/Stack Audio su tutti i 24 thread
set -l audio_compositor_pids (pgrep -u $my_uid -x "kwin_wayland|pipewire|pipewire-pulse|wireplumber|easyeffects")
for p in $audio_compositor_pids
    /usr/bin/taskset -a -cp $ALL_CORES $p >/dev/null 2>&1
end

# 2. Ripristino di tutti i processi utente sulla topologia standard 0-23
set -l all_user_pids (pgrep -u $my_uid)
for p in $all_user_pids
    if test "$p" != "$fish_pid"
        /usr/bin/taskset -a -cp $ALL_CORES $p >/dev/null 2>&1
    end
end


