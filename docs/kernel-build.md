# Compilazione kernel Linux-TKG (BORE)

Procedura per la compilazione locale e personalizzata del kernel Linux-TKG ottimizzato per l'architettura AMD Ryzen 9 5900X, la riduzione della latenza di rendering e la stabilità dei frame time ($1\%$ Lows) nei giochi.

## 1. Tabella dei comandi

| Fase | Comando | Descrizione |
| :--- | :--- | :--- |
| **1. Prep RAM (tmpfs)** | `mkdir -p ~/kernel-build && sudo mount -t tmpfs -o size=35G tmpfs ~/kernel-build` | Crea un mount point temporaneo in memoria RAM di 35 GB per azzerare i tempi d'I/O e l'usura dell'SSD. |
| **2. Download Sorgenti** | `cd ~/kernel-build && git clone https://github.com/Frogging-Family/linux-tkg.git` | Clona il repository del framework di compilazione `linux-tkg`. |
| **3. Compilazione** | `cd linux-tkg && env MAKEFLAGS="-j24" makepkg -s` | Avvia la compilazione usando tutti i 24 thread del Ryzen 9 5900X e applica le impostazioni custom (BORE, `-march=native`, ecc.). |
| **4. Installazione** | `sudo pacman -U *.pkg.tar.zst` | Installa i pacchetti `.pkg.tar.zst` generati; attiva in automatico DKMS per i driver Nvidia e aggiorna `initramfs`. |
| **5. Verifica Status** | `sudo dkms status && uname -r` | Verifica che i driver della RTX 4090 siano stati compilati per il nuovo kernel e, dopo il reboot, conferma la versione del kernel in uso. |

## 2. Scelte tecniche di compilazione

| Parametro / Scelta | Valore impostato | Motivazione tecnica |
| :--- | :--- | :--- |
| **CPU Architecture (`march`)** | `native` (`znver3`) | Sfrutta le istruzioni specifiche dell'architettura Zen 3 (AVX2, FMA, BMI2), superando le istruzioni generiche `x86-64-v3`. |
| **CPU Scheduler** | **BORE** (*Burst-Oriented Response Enhancer*) | Estensione dello schedulatore EEVDF ottimizzata per carichi "bursty" (gaming FPS, input del mouse). Riduce il micro-stuttering e appiattisce i frame time. |
| **Timer Frequency** | `1000 Hz` | Offre la massima risoluzione per il tick rate di sistema (1 interrupt/ms), fondamentale per la reattività degli input. |
| **Tickless Mode** | `CONFIG_NO_HZ_IDLE` (*Tickless Idle*) | Disattiva i tick del timer sui core inattivi, facilitando l'ingresso nei *C-states* e concentrando frequenze e boost PBO sui core attivi. |
| **Compilatore** | **GCC** | Garantisce stabilità e compatibilità con i moduli DKMS dei driver Nvidia. |
| **Build Storage** | **RAM Disk (`tmpfs` 35GB)** | Compilazione interamente in RAM per eliminare colli di bottiglia d'I/O, azzerare l'usura dell'NVMe e completare la build con 24 thread in pochi minuti. |
| **Debug Info** | `CONFIG_DEBUG_INFO=n` | Disattivato per ridurre il peso del binario e evitare pressure di memoria durante il link del `vmlinux`. |

## 3. Script di riferimento

Lo script automazione associato alla procedura è disponibile in:

- [scripts/system/update_kernel.sh](../scripts/system/update_kernel.sh)

## 4. Diagramma di flusso

Il diagramma Mermaid del processo è disponibile in:

- [diagrams/flowchart.mmd](../diagrams/flowchart.mmd)

## 5. Note finali

La compilazione in RAM riduce i tempi d'I/O e previene usura del disco, mentre le impostazioni BORE e `-march=native` mirano a migliorare la reattività del sistema e la stabilità dei frame nelle sessioni di gioco.
