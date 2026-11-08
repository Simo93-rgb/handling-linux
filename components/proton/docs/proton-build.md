# Compilazione Locale e Configurazione di Proton-TKG

La procedura dei comandi `pacman`/AUR è specifica per CachyOS/Arch. Su Bazzite
la build va spostata in Toolbox/Distrobox con dipendenze Fedora equivalenti e
la directory risultante va poi collegata alla libreria Steam dell'utente.

Procedura guidata e note tecniche per la compilazione locale dal sorgente di **Proton-TKG** (versione personalizzata di Proton curata dalla community *Frogging-Family*) su ambiente CachyOS / Arch Linux, con integrazione automatica nella libreria Steam.

---

## 1. Obiettivo e Architettura

L'obiettivo è generare un runtime di compatibilità Proton ottimizzato per l'architettura della CPU locale (`-march=native`), integrando patch aggiornate per driver NVIDIA, media converter e supporto alle estensioni NVAPI, lavorando in sinergia con il kernel custom **Linux-TKG (BORE)**.

---

## 2. Preparazione dell'Ambiente e Dipendenze

Prima di avviare il processo di build, sono state verificate ed installate le dipendenze di sistema a 64 e 32 bit per l'ambiente Arch/CachyOS:

```bash
# Installazione dei tool di sviluppo e build system
sudo pacman -S --needed base-devel git ninja cmake ccache python-pip

# Installazione librerie GStreamer 32-bit (via AUR helper paru)
paru -S --needed lib32-gstreamer lib32-gst-plugins-base
```

**Nota**: Quelle librerie potrebbero cambiare nome o essere dismesse. In linea teorica lo script di installazione di *Proton* controlla le dipendenze prima di lanciare la compilazione.
  
## 3. Clonazione Repository

1. Prima si clona il progetto:

```bash
cd ~
git clone [https://github.com/Frogging-Family/wine-tkg-git.git](https://github.com/Frogging-Family/wine-tkg-git.git)
cd wine-tkg-git/proton-tkg
```
2. Personalizzare il file [`proton-tkg.cfg`](../config/proton-tkg.cfg).
3. Lanciare la compilazione con l'installer `./proton-tkg.sh`
4. Controllare che sia stata genarata la versione di proton al percorso `~/.steam/root/compatibilitytools.d/proton_tkg_<versione>`
5. Per usare il runtime appena compilato insieme al pinning del gioco sul CCD selezionato, consulta la [guida alla mappatura CCD e al pinning con GameMode](../../cpu-gaming/docs/amd-ryzen-ccd-pinning.md).
6. Si consiglia di pulire la cache di Steam
```bash
# Reset completo shader e prefix per uno specifico AppID
rm -rf ~/.steam/root/steamapps/shadercache/<APP_ID>
rm -rf ~/.steam/root/steamapps/compatdata/<APP_ID>
```