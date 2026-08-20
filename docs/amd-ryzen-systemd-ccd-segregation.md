# AMD Ryzen Dual-CCD Systemd & PipeWire/KWin Topology Segregation Guide

Guida tecnica per la segregazione deterministica dei carichi a bassa latenza (Compositor KWin, PipeWire Audio, Gaming) sul **Golden CCD 0** e l'isolamento dei servizi di sistema e dello user-space generico sul **CCD 1** tramite `systemd cgroups v2` e `Feral GameMode` su CachyOS / KDE Plasma 6.

---

## 1. Motivazione Architetturale e Mappa dei Thread

Nei processori AMD Ryzen Dual-CCD (es. Ryzen 9 5900X / 5950X), lo spostamento incontrollato dei thread tra domini di cache L3 distinti introduce penalità di latenza (~70–80 ns sull'Infinity Fabric rispetto ai ~15 ns intra-CCD), causando invalidazioni di cache e micro-stuttering grafico e audio.

```text
+-------------------------------------------------------------------------------+
|                            AMD RYZEN (12C / 24T)                              |
+---------------------------------------+---------------------------------------+
|                 CCD 0                 |                 CCD 1                 |
|       Core 0-5 (SMT: 12-17)           |       Core 6-11 (SMT: 18-23)          |
|          Cache L3: 32 MB              |          Cache L3: 32 MB              |
+---------------------------------------+---------------------------------------+
|  - KWin Wayland Compositor            |  - system.slice (Demoni di sistema)  |
|  - PipeWire Audio Server (Realtime)   |  - app.slice (Browser, IDE, Chat UI)  |
|  - Wine/Proton Games (via GameMode)   |  - Task di I/O, download, background  |
+---------------------------------------+---------------------------------------+

```

### Topologia Hardware di Riferimento (Ryzen 9 5900X)

* **Golden CCD 0 (Core 0-5 + SMT):** CPU logiche `0, 1, 2, 3, 4, 5` e `12, 13, 14, 15, 16, 17`

* **CCD 1 (Core 6-11 + SMT):** CPU logiche `6, 7, 8, 9, 10, 11` e `18, 19, 20, 21, 22, 23`


---

## 2. Regole di Gerarchia cgroups v2 e Sintassi Systemd

In cgroups v2, un nodo figlio **non può eccedere la maschera `AllowedCPUs` concessa dal cgroup genitore**.

* **Errore comune:** Confinare `user.slice` su `6-11 18-23` impedisce a qualsiasi servizio utente (`plasma-kwin_wayland`, `pipewire`, `steam`) di accedere al CCD 0.
* **Sintassi Systemd:** Nei file unit di systemd, le liste di CPU devono essere separate da **spazi** (es. `AllowedCPUs=0-5 12-17`) e non da virgole.

---

## 3. Configurazione dei Servizi di Sistema e App Generiche (CCD 1)

### Step 1: Confinamento dei demoni di sistema (`system.slice`)

Isola tutti i demoni eseguiti come root (aggiornamenti, logging, rete, container) sui thread del CCD 1.

Crea la directory e il file di override:

```fish
sudo mkdir -p /etc/systemd/system/system.slice.d
sudo nano /etc/systemd/system/system.slice.d/cpuset.conf

```

Contenuto:

```ini
[Slice]
AllowedCPUs=6-11 18-23

```

---

### Step 2: Confinamento delle normali applicazioni desktop (`app.slice`)

In KDE Plasma 6 sotto systemd, le normali applicazioni desktop (Firefox, Discord, Kate, Dolphin, client vari) vengono avviate dentro `app.slice`.

Crea la directory e il file di override a livello utente:

```fish
mkdir -p ~/.config/systemd/user/app.slice.d
nano ~/.config/systemd/user/app.slice.d/cpuset.conf

```

Contenuto:

```ini
[Slice]
AllowedCPUs=6-11 18-23

```

---

## 4. Configurazione Task Latency-Critical (Golden CCD 0)

### Step 1: KDE Wayland Compositor (`plasma-kwin_wayland.service`)

Assegna KWin, i thread DRM pageflip e l'architettura Wayland a CCD 0 con priorità Real-Time.

Crea la directory e il file di override:

```fish
mkdir -p ~/.config/systemd/user/plasma-kwin_wayland.service.d
nano ~/.config/systemd/user/plasma-kwin_wayland.service.d/override.conf

```

Contenuto:

```ini
[Service]
AllowedCPUs=0-5 12-17
CPUSchedulingPolicy=rr
CPUSchedulingPriority=50

```

---

### Step 2: PipeWire Audio Server (`pipewire.service`)

Garantisce l'elaborazione del buffer audio a bassissima latenza senza drop o xrun.

Crea la directory e il file di override:

```fish
mkdir -p ~/.config/systemd/user/pipewire.service.d
nano ~/.config/systemd/user/pipewire.service.d/override.conf

```

Contenuto:

```ini
[Service]
AllowedCPUs=0-5 12-17
CPUSchedulingPolicy=rr
CPUSchedulingPriority=50

```

---

### Step 3: Feral GameMode (`/etc/gamemode.ini`)

Poiché Wine e Proton reimpostano l'affinità della CPU durante il fork dei container Pressure-Vessel, GameMode effettua il ri-aggancio forzato sul CCD 0.

Per identificare il Golden CCD e verificare l'integrazione con Steam/Proton, consulta la [guida alla mappatura CCD e al pinning con GameMode](amd-ryzen-ccd-pinning.md).

Modifica `/etc/gamemode.ini`:

```ini
[general]
reaper_freq=5
desiredgov=performance
igpu_power_threshold=-1

[cpu]
pin_cores=0-5,12-17
park_cores=no

```

---

## 5. Applicazione dei Cambiamenti e Ricaricamento Demoni

Esegui in sequenza da terminale:

```fish
# Ricarica dei demoni di sistema e utente
sudo systemctl daemon-reload
systemctl --user daemon-reload

# Riavvio del sottosistema audio
systemctl --user restart pipewire.service

```

*(Nota: Per KWin, le modifiche diventano attive al riavvio della sessione grafica o al reboot del sistema).*

---

## 6. Validazione e Verifica

A sessione avviata, esegui i seguenti controlli diagnostici per validare la segregazione:

### 1. Verifica affinità KWin Wayland

```fish
taskset -cp (pidof kwin_wayland)

```

*Output atteso:*

```text
pid XXXXX's current affinity list: 0-5,12-17

```

### 2. Verifica affinità PipeWire

```fish
taskset -cp (pidof pipewire)

```

*Output atteso:*

```text
pid XXXXX's current affinity list: 0-5,12-17

```

### 3. Verifica affinità Browser / App standard (es. Firefox o Kate)

```fish
taskset -cp (pidof kate)

```

*Output atteso:*

```text
pid XXXXX's current affinity list: 6-11,18-23

```

### 4. Verifica processo di gioco avviato con `gamemoderun`

```fish
for pid in (string split " " (pidof wine64-preloader))
    taskset -cp $pid
end

```

Output atteso:

```text
pid XXXXX's current affinity list: 0-5,12-17[cite: 4]

```