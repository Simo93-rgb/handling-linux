# Profilo Bazzite / Fedora Atomic

Bazzite è un sistema Fedora Atomic: l'host non va trattato come una Fedora
tradizionale. Le applicazioni desktop restano preferibilmente Flatpak, mentre
build e tool di sviluppo usano Toolbox/Distrobox. `rpm-ostree` va usato
sull'host solo quando una dipendenza di sistema non può essere gestita
diversamente.

## Varianti disponibili

Le varianti Bash portabili sono nelle directory dei rispettivi componenti:

- [`cpu-gaming/scripts/bazzite/`](../cpu-gaming/scripts/bazzite/): hook GameMode
  e installazione parametrizzata;
- [`storage/scripts/bazzite/`](../storage/scripts/bazzite/): cache Hugging Face;
- [`openrgb/scripts/bazzite/`](../openrgb/scripts/bazzite/): OpenRGB;
- [`pia-vpn/systemd/bazzite/`](../pia-vpn/systemd/bazzite/): unità PIA.

Gli script CPU principali sono `game-start.sh` e `game-end.sh`; `install-gamemode.sh`
genera la configurazione GameMode e installa gli hook.

Gli script ricevono impostazioni tramite variabili d'ambiente, ad esempio
`CCD0`, `CCD1`, `ALL_CORES`, `USER_UID` e `HF_HOME`, invece di assumere
username o directory della macchina originale.

## Limiti espliciti

- La build Linux-TKG non può usare `makepkg` o installare pacchetti Arch
  direttamente sull'host Bazzite. Per una build sperimentale usare un
  ambiente Arch isolato e installare il kernel solo dopo aver verificato il
  metodo di boot supportato dalla macchina.
- La build Proton-TKG va eseguita in Toolbox/Distrobox con una procedura Fedora
  dedicata; la guida Arch non va applicata direttamente.
- La guida GRUB non è automaticamente valida: prima verificare il bootloader e
  la gestione kernel effettiva con `bootctl status`, `rpm-ostree status` e la
  documentazione Bazzite.
- Le unità systemd root (PIA incluso) devono essere installate in percorsi
  persistenti e verificate con SELinux; non assumere che `/opt` o una home
  privata siano percorsi adatti all'unità.

## Modello ibrido consigliato

1. Installare app e integrazioni desktop con Flatpak quando possibile.
2. Usare Toolbox/Distrobox per compilatori, SDK, Proton-TKG e tool non
   necessari al boot.
3. Usare `/etc`, `systemd` e `rpm-ostree` solo per componenti host realmente
   necessari, documentando il rollback dell'immagine ostree.
