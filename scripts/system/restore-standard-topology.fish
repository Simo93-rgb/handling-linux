#!/usr/bin/fish

echo "1. Rimozione vincoli statici su cgroups e user slices..."
sudo rm -f /etc/systemd/system/system.slice.d/cpuset.conf
sudo rm -f /etc/systemd/system/user.slice.d/cpuset.conf
rm -f ~/.config/systemd/user/app.slice.d/cpuset.conf

echo "2. Riconfigurazione di KWin e PipeWire senza blocco CPU..."
mkdir -p ~/.config/systemd/user/plasma-kwin_wayland.service.d
mkdir -p ~/.config/systemd/user/pipewire.service.d
mkdir -p ~/.config/systemd/user/pipewire-pulse.service.d
mkdir -p ~/.config/systemd/user/wireplumber.service.d

printf "[Service]\\nCPUSchedulingPolicy=rr\\nCPUSchedulingPriority=50\\n" > ~/.config/systemd/user/plasma-kwin_wayland.service.d/override.conf
printf "[Service]\\nCPUSchedulingPolicy=rr\\nCPUSchedulingPriority=50\\n" > ~/.config/systemd/user/pipewire.service.d/override.conf
printf "[Service]\\nCPUSchedulingPolicy=rr\\nCPUSchedulingPriority=50\\n" > ~/.config/systemd/user/pipewire-pulse.service.d/override.conf
printf "[Service]\\nCPUSchedulingPolicy=rr\\nCPUSchedulingPriority=50\\n" > ~/.config/systemd/user/wireplumber.service.d/override.conf

echo "3. Ricaricamento dei demoni..."
sudo systemctl daemon-reload
systemctl --user daemon-reload
systemctl --user restart pipewire pipewire-pulse wireplumber

echo "4. Ripristino immediato dell'affinita di KWin su tutti i thread..."
set -l kwin_pid (pidof kwin_wayland)
test -n "$kwin_pid"; and taskset -a -cp 0-23 $kwin_pid >/dev/null 2>&1

echo "Ripristino completato: 24 thread disponibili per lo user-space."
