# AMD Ryzen CCD Mapping & GameMode Pinning Guide

Manuale tecnico per la mitigazione della latenza inter-CCD e l'eliminazione del frametime jitter nei carichi gaming su Linux/Proton tramite Feral GameMode e ACPI CPPC Core Mapping.

---

## 1. Fondamenti Architetturali e Problematiche

### Topologia AMD Ryzen Dual-CCD (es. Ryzen 9 5900X / 5950X)

I processori AMD Ryzen multi-CCD presentano un'architettura a moduli disgiunti:

- CCD (Core Complex Die): ciascun CCD racchiude fino a 8 core con la propria cache L3 unificata.
- Infinity Fabric (IF): il bus di interconnessione che collega i CCD all'I/O Die centrale e tra loro.

```text
+-------------------------------------------------------------------+
|                           I/O DIE                                 |
+---------------------------------+---------------------------------+
								  |
					[ Infinity Fabric: Latenza ~70-80 ns ]
								  |
+-------------------------+-------------------------+
|                                                   |
+-------v-------------------+               +---------------v-------+
|          CCD 0            |               |          CCD 1        |
|  Core 0-5 (SMT: 12-17)    |               |  Core 6-11 (SMT: 18-23)|
|    Cache L3: 32 MB        |               |    Cache L3: 32 MB    |
|   [ Intra-CCX: ~15 ns ]   |               |   [ Intra-CCX: ~15 ns ]|
+---------------------------+               +-----------------------+
```

### Il problema del frame stuttering

Quando lo scheduler del kernel (CFS, EEVDF o BORE) sposta thread ad alta intensita di calcolo o thread con dipendenze di memoria condivisa tra core appartenenti a CCD distinti:

- La comunicazione deve attraversare l'Infinity Fabric, facendo salire la latenza di accesso alla memoria da ~15 ns (intra-CCX) a ~70-80 ns (inter-CCD).
- Questo rimbalzo di thread tra domini di cache L3 distinti provoca invalidazione di cache, cache miss e micro-stuttering marcato nei percentili 1% e 0.1% lows dei frame rate.

---

## 2. Identificazione del Golden CCD (ACPI CPPC)

Le CPU AMD multi-CCD adottano un binning asimmetrico: un CCD e progettato per sostenere boost clock piu elevati e operare a tensioni inferiori rispetto al secondo.

### Script di mappatura CPPC

Esegui questo snippet per interrogare l'interfaccia ACPI del kernel e determinare i punteggi highest_perf di ciascun thread logico.

Fish shell:

```fish
for i in (seq 0 (math (nproc) - 1))
	set -l p (cat /sys/devices/system/cpu/cpu$i/acpi_cppc/highest_perf 2>/dev/null; or echo "N/A")
	echo "CPU $i: $p"
end
```

Bash/POSIX:

```bash
for i in $(seq 0 $(($(nproc) - 1))); do
	p=$(cat /sys/devices/system/cpu/cpu$i/acpi_cppc/highest_perf 2>/dev/null || echo "N/A")
	echo "CPU $i: $p"
done
```

### Mappatura thread per Ryzen 9 5900X (24 thread totali)

- CCD0 (core fisici 0-5): CPU 0, 1, 2, 3, 4, 5 (primari) + 12, 13, 14, 15, 16, 17 (SMT).
- CCD1 (core fisici 6-11): CPU 6, 7, 8, 9, 10, 11 (primari) + 18, 19, 20, 21, 22, 23 (SMT).

Verdetto: se i punteggi piu alti (es. 200-216) risiedono nelle CPU 0-5, il CCD primario e CCD0, quindi la maschera di affinita e 0-5,12-17.

---

## 3. Perche taskset fallisce su Steam/Proton

L'inserimento manuale di taskset -c ... %command% nelle opzioni di avvio di Steam e spesso inefficace:

1. Steam Runtime isola i processi in container tramite Pressure-Vessel.
2. Il wrapper wine64-preloader e le runtime grafiche eseguono chiamate esplicite a sched_setaffinity durante fork/spawn del processo di gioco Windows, ripristinando la maschera di sistema globale (0-23).

Soluzione: delegare il pinning a Feral GameMode (gamemoded), che opera come demone IPC D-Bus a livello utente/sistema ed effettua il ri-aggancio forzato dell'affinita post-inizializzazione.

---

## 4. Installazione e Configurazione di GameMode

Il sistema resta libero di usare tutti i 24 thread fuori dal gioco. Durante una sessione avviata con `gamemoderun`, gli hook custom di GameMode spostano KWin, PipeWire, WirePlumber e il gioco sul Golden CCD 0; alla chiusura, l'hook finale restituisce KWin e lo stack audio all'intero pool `0-23`. Per la procedura completa consulta la [guida alla segregazione dinamica dei carichi sui CCD](amd-ryzen-systemd-ccd-segregation.md).

### Step 1: installazione pacchetti

Arch Linux/CachyOS:

```bash
sudo pacman -S gamemode lib32-gamemode
```

Debian/Ubuntu:

```bash
sudo apt install gamemode
```

Fedora:

```bash
sudo dnf install gamemode
```

### Step 2: permessi utente

Aggiungi l'utente al gruppo gamemode per autorizzare il cambio dinamico dei governor della CPU senza escalation manuale di privilegi:

```bash
sudo usermod -aG gamemode $USER
```

### Step 3: configurazione di sistema (/etc/gamemode.ini)

Crea o modifica il file di configurazione globale:

```bash
sudo nano /etc/gamemode.ini
# oppure: sudo micro /etc/gamemode.ini
```

Incolla la seguente configurazione:

```ini
[general]
# Frequenza di polling (secondi) per agganciare nuovi thread/processi figli
reaper_freq=5
# Imposta lo scaling governor a performance all'avvio del gioco
desiredgov=performance
igpu_power_threshold=-1

[cpu]
# Pinning del gioco sul Golden CCD0 (12 thread logici)
pin_cores=0-5,12-17
park_cores=no

[custom]
start=/home/simone/.local/bin/game-start.fish
end=/home/simone/.local/bin/game-end.fish
```

Nota: omettere o non configurare la sezione [gpu] se si utilizzano driver proprietari moderni Nvidia/Wayland su serie RTX 40xx per evitare errori di compatibilita NVML con gpuclockctl.

### Step 4: abilitazione del servizio systemd

Abilita e riavvia il demone utente:

```bash
systemctl --user enable --now gamemoded
systemctl --user restart gamemoded
```

### Step 5: validazione della configurazione

Esegui il test diagnostico integrato:

```bash
gamemoded -t
```

Tutti i check critici (Basic client, Dual client, Reaper thread, CPU governor, Supervisor) devono restituire Passed.

### Step 6: installazione degli hook dinamici

Copia gli script versionati nella directory degli script utente e rendili eseguibili:

```fish
mkdir -p ~/.local/bin
cp scripts/system/game-start.fish scripts/system/game-end.fish ~/.local/bin/
chmod +x ~/.local/bin/game-start.fish ~/.local/bin/game-end.fish
sudo cp config/gamemode.ini /etc/gamemode.ini
systemctl --user restart gamemoded
```

Gli hook vengono eseguiti solo per i giochi lanciati con `gamemoderun`. In uso normale, compilazioni, shader e processi Python conservano l'accesso a tutti i thread.

---

## 5. Integrazione con Steam e script di verifica

### Opzioni di avvio Steam

Nelle proprieta di ciascun gioco, inserisci la seguente stringa di lancio:

```text
PROTON_ENABLE_NVAPI=1 DXVK_ENABLE_NVAPI=1 PROTON_ENABLE_NGX_UPDATER=1 PROTON_USE_EAC_LINUX=1 gamemoderun %command%
```

### Verifica a caldo durante il gioco

A gioco avviato, verifica che tutti i thread generati da Wine siano vincolati alla maschera 0-5,12-17.

Fish shell:

```fish
for pid in (string split " " (pidof wine64-preloader))
	taskset -cp $pid
end
```

Bash:

```bash
for pid in $(pidof wine64-preloader); do
	taskset -cp $pid
done
```

Output atteso:

```text
pid 170700's current affinity list: 0-5,12-17
pid 170669's current affinity list: 0-5,12-17
...
```
