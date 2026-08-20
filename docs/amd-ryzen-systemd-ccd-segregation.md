# AMD Ryzen Dual-CCD: Segregazione dinamica con GameMode

Guida per mantenere disponibili tutti i 24 thread durante desktop, compilazioni, shader e calcolo, applicando il pinning sul **Golden CCD 0** solo mentre e attivo un gioco tramite `GameMode` su CachyOS / KDE Plasma 6.

---

## 1. Modello operativo

Il precedente confinamento permanente di `system.slice`, `user.slice` e `app.slice` non e ottimale: limita inutilmente compilazioni, pre-compilazione degli shader Vulkan e processi Python/PyTorch. Il sistema deve quindi restare libero su tutti i thread `0-23`.

Durante una sessione avviata con `gamemoderun`:

- `game-start.fish` sposta KWin, PipeWire e WirePlumber sul CCD 0 (`0-5,12-17`);
- GameMode applica lo stesso pinning al gioco e ai processi Wine/Proton tramite `pin_cores`;
- `game-end.fish` restituisce KWin e lo stack audio a tutti i thread (`0-23`).

```text
+-------------------------------+-------------------------------+
| CCD 0: gioco e pipeline       | CCD 1: sistema disponibile    |
| 0-5,12-17                     | 6-11,18-23                   |
| KWin, PipeWire, WirePlumber   | carichi non vincolati         |
| gioco Wine/Proton             | durante il gioco              |
+-------------------------------+-------------------------------+
| Fuori dal gioco: tutti i processi possono usare 0-23         |
+---------------------------------------------------------------+
```

Per un Ryzen 9 5900X, il Golden CCD 0 comprende i thread `0-5,12-17`, mentre il CCD 1 comprende `6-11,18-23`.

---

## 2. Rimozione dei vincoli statici

Esegui lo script versionato per rimuovere i cpuset permanenti e mantenere solo la priorita real-time di KWin e dell'audio:

```fish
fish scripts/system/restore-standard-topology.fish
```

Lo script:

1. rimuove gli override `AllowedCPUs` da `system.slice`, `user.slice` e `app.slice`;
2. ricrea gli override di KWin, PipeWire, PipeWire Pulse e WirePlumber con `CPUSchedulingPolicy=rr` e priorita `50`, senza `AllowedCPUs`;
3. ricarica systemd e riavvia lo stack audio;
4. riporta immediatamente KWin alla maschera `0-23`.

Dopo l'esecuzione, il sistema e nello stato standard: compilazioni `make -j24`, shader Vulkan e workload Python possono utilizzare l'intera CPU.

---

## 3. Installazione degli hook GameMode

Copia gli script nella directory utente prevista dalla configurazione:

```fish
mkdir -p ~/.local/bin
cp scripts/system/game-start.fish scripts/system/game-end.fish ~/.local/bin/
chmod +x ~/.local/bin/game-start.fish ~/.local/bin/game-end.fish
```

### Configurazione `/etc/gamemode.ini`

Installa la configurazione versionata:

```fish
sudo cp config/gamemode.ini /etc/gamemode.ini
systemctl --user restart gamemoded
```

La sezione rilevante e:

```ini
[general]
reaper_freq=5
desiredgov=performance
igpu_power_threshold=-1

[cpu]
pin_cores=0-5,12-17
park_cores=no

[custom]
start=/home/simone/.local/bin/game-start.fish
end=/home/simone/.local/bin/game-end.fish
```

Gli hook vengono eseguiti solo quando il gioco e lanciato con `gamemoderun`, ad esempio nelle opzioni di avvio Steam:

```text
PROTON_ENABLE_NVAPI=1 DXVK_ENABLE_NVAPI=1 PROTON_ENABLE_NGX_UPDATER=1 PROTON_USE_EAC_LINUX=1 gamemoderun %command%
```

---

## 4. Verifica

Lo script di controllo e installato come `~/.local/bin/check-topology.fish` e si esegue con:

```fish
~/.local/bin/check-topology.fish
```

Durante il gioco, KWin, PipeWire, WirePlumber e `wine64-preloader` devono riportare `0-5,12-17`. Kate, Dolphin e gli altri processi non gestiti dall'hook devono restare liberi: una maschera `0-23` e corretta.

Fuori dal gioco, esegui di nuovo lo script per verificare che KWin e lo stack audio siano tornati a `0-23`; il gioco deve risultare assente.

Per il test diagnostico di GameMode:

```fish
gamemoded -t
```

Tutti i check critici devono restituire `Passed`.
