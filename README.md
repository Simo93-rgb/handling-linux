# handling-linux
Mantenimento e configurazioni personalizzate per la distribuzione Linux in uso (CachyOS).

---

## 🚀 Compilazione Kernel Linux-TKG (BORE)

Procedura per la compilazione locale e personalizzata del kernel **Linux-TKG** ottimizzato per l'architettura **AMD Ryzen 9 5900X**, la riduzione della latenza di rendering e la stabilità dei frame time ($1\%$ Lows) nei giochi.

### Tabella dei Comandi

| Fase | Comando | Descrizione |
| :--- | :--- | :--- |
| **1. Prep RAM (tmpfs)** | `mkdir -p ~/kernel-build && sudo mount -t tmpfs -o size=35G tmpfs ~/kernel-build` | Crea un mount point temporaneo in memoria RAM di 35 GB per azzerare i tempi d'I/O e l'usura dell'SSD. |
| **2. Download Sorgenti** | `cd ~/kernel-build && git clone https://github.com/Frogging-Family/linux-tkg.git` | Clona il repository del framework di compilazione `linux-tkg`. |
| **3. Compilazione** | `cd linux-tkg && env MAKEFLAGS="-j24" makepkg -s` | Avvia la compilazione usando tutti i 24 thread del Ryzen 9 5900X e applica le impostazioni custom (BORE, `-march=native`, ecc.). |
| **4. Installazione** | `sudo pacman -U *.pkg.tar.zst` | Installa i pacchetti `.pkg.tar.zst` generati; attiva in automatico DKMS per i driver Nvidia e aggiorna `initramfs`. |
| **5. Verifica Status** | `sudo dkms status && uname -r` | Verifica che i driver della RTX 4090 siano stati compilati per il nuovo kernel e (dopo il reboot) conferma la versione del kernel in uso. |

---

### 🎯 Scelte Tecniche di Compilazione

| Parametro / Scelta | Valore Impostato | Motivazione Tecnica |
| :--- | :--- | :--- |
| **CPU Architecture (`march`)** | `native` (`znver3`) | Sfrutta le istruzioni specifiche dell'architettura Zen 3 (AVX2, FMA, BMI2), superando le istruzioni generiche `x86-64-v3`. |
| **CPU Scheduler** | **BORE** (*Burst-Oriented Response Enhancer*) | Estensione dello schedulatore EEVDF ottimizzata per carichi "bursty" (gaming FPS, input del mouse). Riduce il micro-stuttering e appiattisce i frame time. |
| **Timer Frequency** | `1000 Hz` | Offre la massima risoluzione per il tick rate di sistema (1 interrupt/ms), fondamentale per la reattività degli input. |
| **Tickless Mode** | `CONFIG_NO_HZ_IDLE` (*Tickless Idle*) | Disattiva i tick del timer sui core inattivi facilitando l'ingresso nei *C-states*, concentrando le frequenze e il boost PBO sui soli core attivi. |
| **Compilatore** | **GCC** | Garantisce la massima stabilità e prevenzione di errori durante l'innesco automatico dei moduli DKMS dei driver Nvidia. |
| **Build Storage** | **RAM Disk (`tmpfs` 35GB)** | Compilazione eseguita interamente in RAM per eliminare colli di bottiglia d'I/O, azzerare l'usura dell'NVMe e chiudere la build con 24 thread in ~2-3 minuti. |
| **Debug Info** | `CONFIG_DEBUG_INFO=n` | Disabilitato per prevenire l'esaurimento dello spazio di archiviazione in RAM durante la fase di linking del binario `vmlinux`. |

---
### Flowchart Compilazione Kernel

Il flusso completo del processo è disponibile nel file [flowchart.mmd](flowchart.mmd).

---

### 🛠️ Configurazione GRUB: Autosave e Menu Diretto

Per fare in modo che GRUB mantenga sempre selezionato il kernel **BORE** ed elimini la necessità di navigare nel sottomenu *Advanced Options*, il file `/etc/default/grub` richiede le seguenti impostazioni:

#### 1. File `/etc/default/grub`

```text
# Imposta la voce di default sulla memoria dell'ultimo avvio effettuato
GRUB_DEFAULT=saved

# Abilita il salvataggio automatico dell'ultima selezione nel file grubenv
GRUB_SAVEDEFAULT=true

# Disabilita il sottomenu 'Advanced Options', portando tutti i kernel nel menu principale
GRUB_DISABLE_SUBMENU='true'
```

#### 2. Rigenerazione della configurazione
Dopo aver salvato la modifica nel file /etc/default/grub, applica i cambiamenti aggiornando il menu di avvio:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

