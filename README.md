# handling-linux
Mantenimento e configurazioni personalizzate per la distribuzione Linux in uso (CachyOS).

Questo repository raccoglie script, note e riferimenti utili per la gestione del sistema operativo. È pensato per crescere nel tempo, mantenendo separata la presentazione generale della repo dalla documentazione tecnica specifica.

## 📁 Struttura della repository

```text
handling-linux/
├── README.md
├── config/
│   ├── EasyEffects/
│   ├── environment.d/
│   │   └── 10-huggingface.conf
│   ├── gamemode.ini
│   └── proton-tkg.cfg
├── diagrams/
│   └── flowchart.mmd
├── docs/
│   ├── amd-ryzen-ccd-pinning.md
│   ├── amd-ryzen-systemd-ccd-segregation.md
│   ├── grub-config.md
│   ├── huggingface-cache-storage.md
│   ├── kernel-build.md
│   ├── openrgb.md
│   └── proton-build.md
└── scripts/
    ├── config/
    │   └── openrgb_setup.sh
    ├── system/
    │   ├── compile-kernel.fish
    │   ├── game-end.fish
    │   ├── game-start.fish
    │   ├── restore-standard-topology.fish
    │   ├── select-default-kernel.fish
    │   ├── setup-huggingface-cache.fish
    │   └── sync-topology-scripts.fish
    └── tests/
        ├── check_ccd_topology.fish
        └── check_huggingface_cache.fish
```

## 🧭 Come usare la repo

- Il file [README.md](README.md) è la presentazione iniziale della repository e il punto di ingresso principale.
- La directory [docs/](docs/) contiene i documenti dettagliati dedicati alle procedure e alle configurazioni.
- La directory [scripts/system/](scripts/system/) contiene gli script di automazione e gestione del sistema.
- La directory [scripts/tests/](scripts/tests/) contiene gli script di test e diagnostica (topologia CCD, cache Hugging Face, verifica stato).
- La directory [scripts/config/](scripts/config/) contiene script di configurazione hardware/periferiche.
- La directory [config/](config/) contiene file di configurazione per demoni, emulatori e sessione utente (GameMode, EasyEffects, Proton-TKG, environment.d).
- La directory [diagrams/](diagrams/) raccoglie i diagrammi e le mappe di flusso.

## 📚 Documentazione e Script disponibili

### ⚙️ Gestione CPU e Topologia Dual-CCD (AMD Ryzen 9 5900X)
- [Segregazione dinamica Dual-CCD](docs/amd-ryzen-systemd-ccd-segregation.md): Architettura, hook GameMode e isolamento L3.
- [Guida al Pinning CCD con GameMode](docs/amd-ryzen-ccd-pinning.md): CPPC mapping, configurazione `/etc/gamemode.ini` e lancio Steam.
- [Sincronizzazione script di sistema](scripts/system/sync-topology-scripts.fish): Tool per sincronizzare i file della repo con `~/.local/bin/` e `/etc/`.
- [Test e diagnostica topologia CCD](scripts/tests/check_ccd_topology.fish): Script di verifica dello stato idle / gaming con controllo disallineamento integrato.
- [Hook avvio gioco (CCD0 + CCD1)](scripts/system/game-start.fish) e [Hook fine gioco (reset 0-23)](scripts/system/game-end.fish).
- [Ripristino standard topologia](scripts/system/restore-standard-topology.fish): Pulizia override statici e reset RT.

### 🐧 Kernel e Bootloader
- [Compilazione kernel Linux-TKG](docs/kernel-build.md)
- [Configurazione GRUB](docs/grub-config.md)
- [Script di compilazione kernel](scripts/system/compile-kernel.fish)
- [Selezione kernel predefinito in GRUB](scripts/system/select-default-kernel.fish)
- [Flowchart del processo di build](diagrams/flowchart.mmd)

### 🎮 Gaming e Periferiche
- [Guida alla compilazione di Proton-TKG](docs/proton-build.md)
- [Configurazione OpenRGB](docs/openrgb.md) e [Script di setup OpenRGB](scripts/config/openrgb_setup.sh)
- [Profili DSP EasyEffects](config/EasyEffects/)

### 📦 Storage, Cache e Machine Learning
- [Rilocazione Cache Hugging Face](docs/huggingface-cache-storage.md): Architettura CAS, isolamento storage SATA/NVMe secondario, systemd `environment.d` e variabili universali Fish.
- [Configurazione ambiente sessione](config/environment.d/10-huggingface.conf): Template dichiarativo per `~/.config/environment.d/10-huggingface.conf`.
- [Script di rilocazione cache](scripts/system/setup-huggingface-cache.fish): Tool per configurare la directory di destinazione e registrare le variabili in systemd e Fish.
- [Diagnostica configurazione cache](scripts/tests/check_huggingface_cache.fish): Test di verifica filesystem, variabili d'ambiente e runtime Python/uv.

## 🎯 Obiettivo

Mantenere una repository ordinata, leggibile e facilmente scalabile, con una chiara separazione tra:

- presentazione generale
- documentazione tecnica
- script operativi
- diagrammi e riferimento visivo
