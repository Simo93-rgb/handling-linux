#!/usr/bin/fish

 # 1. Sposta KWin Wayland su CCD0 (Core 0-5 + SMT 12-17)
 set -l kwin_pids (pgrep -x kwin_wayland)
 for p in $kwin_pids
     /usr/bin/taskset -a -cp 0-5,12-17 $p >/dev/null 2>&1
 end

 # 2. Sposta PipeWire, PipeWire-Pulse e WirePlumber su CCD0
 set -l audio_pids (pgrep -x "pipewire|pipewire-pulse|wireplumber")
 for p in $audio_pids
     /usr/bin/taskset -a -cp 0-5,12-17 $p >/dev/null 2>&1
 end
