#!/usr/bin/fish

 # 1. Rilascia KWin Wayland su tutti i 24 thread (0-23)
 set -l kwin_pids (pgrep -x kwin_wayland)
 for p in $kwin_pids
     /usr/bin/taskset -a -cp 0-23 $p >/dev/null 2>&1
 end

 # 2. Rilascia PipeWire, PipeWire-Pulse e WirePlumber su tutti i 24 thread (0-23)
 set -l audio_pids (pgrep -x "pipewire|pipewire-pulse|wireplumber")
 for p in $audio_pids
     /usr/bin/taskset -a -cp 0-23 $p >/dev/null 2>&1
 end
