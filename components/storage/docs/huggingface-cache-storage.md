# Rilocazione e Gestione Storage della Cache Hugging Face

La procedura è comune a CachyOS e Bazzite per la parte `environment.d`. Su
Bazzite usa [`setup-huggingface-cache.sh`](../scripts/bazzite/setup-huggingface-cache.sh);
la variante Fish mantiene anche le variabili universali Fish su CachyOS.

Guida tecnica per la rilocazione persistente della cache dei modelli Hugging Face (`transformers`, `diffusers`, `huggingface_hub`) su storage secondario ad alta capienza, con configurazione globale a livello di sessione utente `systemd` e integrazione universale nella shell Fish.

---

## 1. Motivazione Architetturale

I modelli moderni di Deep Learning, Large Language Models (LLM) e modelli generativi (es. Llama, Mistral, Stable Diffusion, Flux) richiedono da svariati gigabyte fino a decine di gigabyte per singolo checkpoint.

Lasciare la cache nel percorso predefinito (`~/.cache/huggingface/` sulla partizione root o home) porta rapidamente alla saturazione dello spazio disco di sistema. Rilocare questa cache su un disco secondario (es. un NVMe dedicato o un SSD SATA montato su `/mnt/Games/`) consente di preservare la partizione di sistema.

### Perché spostare solo Hugging Face e NON l'intera cartella `~/.cache`?

L'adozione di un symlink globale per l'intera cartella `~/.cache` verso un altro filesystem è fortemente sconsigliata per ragioni di stabilità:

1. **Sandboxing e Permessi Flatpak / Bubblewrap:**  
   I container Flatpak e le sandbox applicative hanno restrizioni di sicurezza stringenti sui percorsi esterni alla home dell'utente (`$HOME`). Se `~/.cache` è un symlink verso `/mnt/...`, le applicazioni containerizzate non possono seguire il symlink o accedere ai file, causando crash immediati o malfunzionamenti di browser, client di gioco e strumenti isolati.
2. **Socket Unix IPC e Lock di Sessione:**  
   Molti sottosistemi grafici e audio (KWin Wayland, bus D-Bus di sessione, PipeWire, PulseAudio) creano socket Unix di comunicazione inter-processo e lock-file con semantiche POSIX rigide (es. `O_TMPFILE`, `flock`) all'interno di percorsi cache o runtime. Spostare questi file su filesystem montati con opzioni diverse o dischi secondari può introdurre latenze impreviste o deadlock.
3. **Pattern di I/O Differenziato:**  
   `~/.cache` gestisce continuamente centinaia di migliaia di micro-file temporanei (cache dei browser, miniature di Dolphin/KDE, font cache) con accessi randomici 4K. La cache di Hugging Face, al contrario, gestisce file sequenziali di grandi dimensioni (da centinaia di megabyte a svariati gigabyte). La rilocazione selettiva è l'approccio ingegneristicamente corretto.

### Impatto Prestazionale su Storage Secondario (SATA vs NVMe)

L'impiego di un SSD secondario (anche SATA III ~500 MB/s sequenziali anziché NVMe Gen4 ~5000+ MB/s) per la cache dei modelli è una soluzione ideale:
- **Caricamento a freddo (Cold Load):** La velocità del disco incide unicamente sulla fase di lettura iniziale durante il caricamento dei pesi in RAM o VRAM (GPU). Per un modello da 10 GB, la lettura richiede circa 18-20 secondi su SATA contro 2-3 secondi su NVMe.
- **Inferenza e Addestramento:** Una volta caricati i pesi nella memoria della GPU o nella RAM di sistema tramite PyTorch e tensori memory-mapped (`safetensors`), l'unità di archiviazione non viene più interpellata. L'esecuzione avviene alla larghezza di banda della memoria video (VRAM, centinaia di GB/s), con zero penalità prestazionale dovuta allo storage.

---

## 2. Architettura Interna della Cache di Hugging Face

La libreria moderna `huggingface_hub` organizza la directory `hub/` secondo un modello **CAS (*Content-Addressable Storage*)**:

```text
/mnt/Games/.cache/huggingface/
└── hub/
    ├── models--meta-llama--Llama-3-8B/
    │   ├── blobs/
    │   │   ├── 0a1b2c3d4e5f... (peso binario o safetensors indicizzato per SHA-256)
    │   │   └── 6f7e8d9c0b1a... (config.json indicizzato per SHA-256)
    │   ├── refs/
    │   │   └── main (contiene l'hash dell'ultimo commit: e.g. "a1b2c3d...")
    │   └── snapshots/
    │       └── a1b2c3d.../
    │           ├── config.json -> ../../blobs/6f7e8d9c0b1a...
    │           └── model.safetensors -> ../../blobs/0a1b2c3d4e5f...
    └── version.txt
```

- **`blobs/`:** Contiene i dati effettivi (pesi del modello, configurazioni, tokenizer). Ogni file è nominato con l'hash crittografico SHA-256 del suo contenuto grezzo. Questo previene qualsiasi duplicazione di dati nel caso in cui modelli o branch differenti condividano gli stessi tensori o configurazioni.
- **`snapshots/`:** Contiene la struttura logica del repository per ciascuna revisione/commit. I file presenti sono esclusivamente **symlink relativi** che puntano ai rispettivi hash all'interno della cartella `blobs/`.
- **`refs/`:** Mantiene i puntatori ai rami git (es. `main`) e ai tag della revisione upstream.

---

## 3. Gestione dell'Ambiente Globale

Per rendere effettivo il nuovo percorso per qualsiasi applicazione (script lanciati da terminale, IDE come VS Code/Cursor, processi lanciati da KRunner o menu delle applicazioni, e servizi di background), non è sufficiente modificare i file di configurazione della shell come `~/.bashrc` o `~/.config/fish/config.fish`.

Le variabili definite nei file di configurazione delle shell interattive hanno visibilità limitata ai processi figli di quel terminale.

### Il Generatore `environment.d` di Systemd

La soluzione standard su sistemi Linux con systemd è l'uso della specifica `environment.d` (`man 5 environment.d`):

1. Il file di configurazione viene collocato in:
   ```text
   ~/.config/environment.d/10-huggingface.conf
   ```
2. All'avvio della sessione utente, `systemd-environment-d-generator` analizza questi file e inietta le definizioni nell'ambiente del demone `systemd --user`.
3. Tutti i servizi, i desktop manager (KDE Plasma, GNOME) e le applicazioni avviate dalla GUI ereditano automaticamente le variabili d'ambiente.

### Variabili d'Ambiente Supportate

| Variabile | Scopo |
| :--- | :--- |
| `HF_HOME` | Percorso radice moderno per l'intera suite Hugging Face (hub, cache, token). |
| `HF_HUB_CACHE` | Percorso specifico per la cache dei modelli e dataset (`$HF_HOME/hub`). |
| `TRANSFORMERS_CACHE` | Variabile legacy per retrocompatibilità con vecchie release della libreria `transformers`. |

---

## 4. Installazione e Configurazione

È disponibile lo script di automazione per configurare l'ambiente e la directory:

### Esecuzione con il percorso predefinito (`/mnt/Games/.cache/huggingface`)

```fish
fish components/storage/scripts/cachyos/setup-huggingface-cache.fish
```

### Esecuzione con un percorso personalizzato

```fish
fish components/storage/scripts/cachyos/setup-huggingface-cache.fish /nuovo/percorso/cache/huggingface
```

### Operazioni eseguite dallo script

1. Verifica l'esistenza e la scrivibilità della cartella di destinazione (creandola con permessi corretti se assente).
2. Genera il file `~/.config/environment.d/10-huggingface.conf`.
3. Inietta a caldo le variabili nell'istanza utente di systemd attiva senza richiedere il riavvio della sessione:
   ```fish
   systemctl --user import-environment HF_HOME HF_HUB_CACHE TRANSFORMERS_CACHE
   ```
4. Salva le variabili nell'ambiente universale di Fish (`set -Ux`), rendendole immediatamente attive e persistenti in ogni terminale Fish presente e futuro.

---

## 5. Verifica e Diagnostica

Per verificare la corretta esportazione e funzionalità dell'ambiente, è fornito lo script di diagnostica:

```fish
fish components/storage/tests/check_huggingface_cache.fish
```

### Output diagnostico atteso

```text
=================================================================
       Diagnostica Configurazione Cache Hugging Face             
=================================================================

--- 1. File di configurazione sessione (~/.config/environment.d) ---
[OK] File presente: $HOME/.config/environment.d/10-huggingface.conf
     HF_HOME=/mnt/Games/.cache/huggingface
     HF_HUB_CACHE=/mnt/Games/.cache/huggingface/hub
     TRANSFORMERS_CACHE=/mnt/Games/.cache/huggingface/hub

--- 2. Ambiente Systemd User Session (systemctl --user) ---
[OK] HF_HOME esportata in systemd: /mnt/Games/.cache/huggingface/
[OK] HF_HUB_CACHE esportata in systemd: /mnt/Games/.cache/huggingface/hub
[OK] TRANSFORMERS_CACHE esportata in systemd: /mnt/Games/.cache/huggingface/hub

--- 3. Ambiente Shell Fish (Variabili Universali) ---
[OK] $HF_HOME attivo: /mnt/Games/.cache/huggingface/
[OK] $HF_HUB_CACHE attivo: /mnt/Games/.cache/huggingface/hub
[OK] $TRANSFORMERS_CACHE attivo: /mnt/Games/.cache/huggingface/hub

--- 4. Verifica Directory e Filesystem ---
[OK] Directory target esistente: /mnt/Games/.cache/huggingface/
[OK] Permessi di scrittura verificati
     Filesystem: /dev/nvme1n1p1  954G  634G    319G  67% /mnt/Games

--- 5. Test Risoluzione Runtime Python ---
[OK] Runtime os.environ -> HF_HOME=/mnt/Games/.cache/huggingface/ | HF_HUB_CACHE=/mnt/Games/.cache/huggingface/hub

=================================================================
```

### Test manuale rapido via Python / uv

```fish
uv run python -c "from huggingface_hub.constants import HF_HOME, HF_HUB_CACHE; print(f'HF_HOME={HF_HOME}\nHF_HUB_CACHE={HF_HUB_CACHE}')"
```

---

## 6. Manutenzione della Cache e Pulizia dello Spazio

Hugging Face mette a disposizione strumenti integrati per monitorare e ripulire le revisioni e gli snapshot non più utilizzati:

```bash
# Scansione interattiva delle revisioni e dei modelli scaricati
huggingface-cli delete-cache
```

### Note Correlate sulla Gestione Cache di Sistema

- **Pacman / Paru Cache:**  
  AUR helper come `paru` accumulano artefatti di compilazione intermedi in `~/.cache/paru/clone/`. Per evitare usura e spreco di spazio su disco, è consigliabile configurare la compilazione su memoria volatile in `tmpfs` (direttiva `BuildDir = /tmp` in `/etc/paru.conf`) e pianificare pulizie periodiche con `paccache -r`.
- **Integrità `/var/cache/pacman/pkg`:**  
  La cache di sistema di Pacman deve sempre essere preservata come directory valida con permessi `root:root` (non rimuovere mai con `rm -rf`, utilizzare `pacman -Sc` o `paccache`).
