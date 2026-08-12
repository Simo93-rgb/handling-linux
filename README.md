# handling-linux
Mantenimento e configurazioni personalizzate per la distribuzione Linux in uso (CachyOS).

Questo repository raccoglie script, note e riferimenti utili per la gestione del sistema operativo. È pensato per crescere nel tempo, mantenendo separata la presentazione generale della repo dalla documentazione tecnica specifica.

## 📁 Struttura della repository

```text
handling-linux/
├── README.md
├── docs/
│   ├── kernel-build.md
│   └── grub-config.md
├── scripts/
│   └── system/
│       └── update_kernel.sh
├── diagrams/
│   └── flowchart.mmd
└── .vscode/
    └── settings.json
```

## 🧭 Come usare la repo

- Il file [README.md](README.md) è la presentazione iniziale della repository e il punto di ingresso principale.
- La directory [docs/](docs/) contiene i documenti dettagliati dedicati alle procedure e alle configurazioni.
- La directory [scripts/system/](scripts/system/) contiene gli script di automazione e gestione del sistema.
- La directory [diagrams/](diagrams/) raccoglie i diagrammi e le mappe di flusso.

## 📚 Documentazione disponibile

- [Compilazione kernel Linux-TKG](docs/kernel-build.md)
- [Configurazione GRUB](docs/grub-config.md)
- [Script di aggiornamento kernel](scripts/system/update_kernel.sh)
- [Flowchart del processo](diagrams/flowchart.mmd)

## 🎯 Obiettivo

Mantenere una repository ordinata, leggibile e facilmente scalabile, con una chiara separazione tra:

- presentazione generale
- documentazione tecnica
- script operativi
- diagrammi e riferimento visivo

