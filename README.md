# handling-linux

Configurazioni, automazioni e guide per una workstation Linux CachyOS/Arch o
Bazzite/Fedora Atomic.

## Navigazione rapida

La repository è organizzata per **componente**, non per tipo di file. Per ogni
funzione si entra in una sola directory e da lì si trovano guida, configurazioni,
script, test e differenze tra piattaforme.

| Componente | Contenuto | Ingresso |
| --- | --- | --- |
| CPU e gaming | CCD, GameMode, hook e diagnostica | [components/cpu-gaming/](components/cpu-gaming/) |
| Audio | Profili EasyEffects | [components/audio/](components/audio/) |
| Kernel | Linux-TKG, GRUB e build | [components/kernel/](components/kernel/) |
| Proton | Proton-TKG e configurazione | [components/proton/](components/proton/) |
| Storage | Cache Hugging Face e environment.d | [components/storage/](components/storage/) |
| OpenRGB | Flatpak, udev e i2c-dev | [components/openrgb/](components/openrgb/) |
| PIA VPN | WireGuard, port forwarding e systemd | [components/pia-vpn/](components/pia-vpn/) |

Ogni componente contiene un proprio `README.md` con prerequisiti, installazione
e percorsi degli artefatti. Per capire la struttura complessiva consulta
[il diagramma della repository](diagrams/repository-structure.mmd).

## Piattaforme

- [Profilo CachyOS/Arch](components/platforms/cachyos.md): Fish e tool Arch.
- [Profilo Bazzite/Fedora Atomic](components/platforms/bazzite.md): Bash,
  Flatpak, Toolbox/Distrobox e integrazioni host minime.

Le varianti sono esplicite: non eseguire uno script di una piattaforma
all'interno dell'altra senza leggere il README del componente.

## Struttura

```text
components/
├── audio/
├── cpu-gaming/
├── kernel/
├── openrgb/
├── pia-vpn/
├── proton/
├── storage/
└── platforms/          Profili CachyOS e Bazzite
diagrams/               Diagrammi trasversali
scripts/checks/         Controlli globali della repository
.github/                Workflow e istruzioni di collaborazione
```

## Verifica

```bash
bash scripts/checks/check_repository.sh
```

Il controllo verifica albero, link locali e sintassi Bash/Fish. I test dentro i
componenti sono invece diagnostiche specifiche e vanno eseguiti solo nel
contesto descritto dal rispettivo README.

## Collaborazione

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) prima di
aggiungere o spostare un artefatto. La repository non ha ancora una licenza
esplicita.
