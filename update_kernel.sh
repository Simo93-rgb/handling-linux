#!/usr/bin/env fish

# Colori per l'output nel terminale
set -l GREEN (set_color green)
set -l RED (set_color red)
set -l YELLOW (set_color yellow)
set -l BOLD (set_color --bold)
set -l RESET (set_color normal)

function log_info
    echo -e "{$GREEN}[INFO]{$RESET} $argv"
end

function log_warn
    echo -e "{$YELLOW}[WARN]{$RESET} $argv"
end

function log_err
    echo -e "{$RED}[ERROR]{$RESET} $argv"
end

function check_status
    if test $status -ne 0
        log_err "La fase '$argv[1]' è fallita con codice di errore. Interruzione dello script."
        exit 1
    else
        log_info "Fase '$argv[1]' completata con successo."
    end
end

echo -e "{$BOLD}=== Avvio Script di Compilazione e Installazione Linux-TKG ==={$RESET}\n"

# -----------------------------------------------------------------------------
# FASE 1: Preparazione RAM (tmpfs)
# -----------------------------------------------------------------------------
log_info "Fase 1: Creazione e montaggio della RAM disk (35GB)..."

set -l BUILD_DIR "$HOME/kernel-build"

if not test -d $BUILD_DIR
    mkdir -p $BUILD_DIR
    check_status "Creazione directory $BUILD_DIR"
end

# Controlla se la cartella è già montata in tmpfs
if mountpoint -q $BUILD_DIR
    log_warn "La directory $BUILD_DIR è già un mountpoint tmpfs. Eseguo remount..."
    sudo mount -o remount,size=35G tmpfs $BUILD_DIR
    check_status "Remount tmpfs"
else
    sudo mount -t tmpfs -o size=35G tmpfs $BUILD_DIR
    check_status "Montaggio tmpfs"
end

# -----------------------------------------------------------------------------
# FASE 2: Download Sorgenti
# -----------------------------------------------------------------------------
log_info "Fase 2: Gestione e download sorgenti linux-tkg..."

cd $BUILD_DIR
check_status "Cambio directory in $BUILD_DIR"

if test -d "linux-tkg"
    log_warn "Repository linux-tkg già presente. Pulisco e aggiorno..."
    cd linux-tkg
    git fetch origin
    git reset --hard origin/master
    check_status "Aggiornamento git linux-tkg"
else
    git clone https://github.com/Frogging-Family/linux-tkg.git
    check_status "Clonazione repository linux-tkg"
    cd linux-tkg
end

# -----------------------------------------------------------------------------
# FASE 3: Compilazione con tutti i 24 thread del Ryzen 9 5900X
# -----------------------------------------------------------------------------
log_info "Fase 3: Avvio della compilazione con makepkg (MAKEFLAGS=-j24)..."
log_warn "Si aprirà il wizard interattivo di TKG. Seleziona le tue preferenze (BORE, -march=native, ecc.)."

env MAKEFLAGS="-j24" makepkg -s
check_status "Compilazione del kernel (makepkg)"

# -----------------------------------------------------------------------------
# FASE 4: Verifica ed Installazione dei Pacchetti
# -----------------------------------------------------------------------------
log_info "Fase 4: Ricerca ed installazione dei pacchetti .pkg.tar.zst generati..."

set -l PKGS (ls *.pkg.tar.zst 2>/dev/null)

if test (count $PKGS) -eq 0
    log_err "Nessun pacchetto .pkg.tar.zst trovato nella directory corrente!"
    exit 1
end

log_info "Trovati i seguenti pacchetti:"
for pkg in $PKGS
    echo "  - $pkg"
end

sudo pacman -U $PKGS
check_status "Installazione pacchetti tramite pacman"

# -----------------------------------------------------------------------------
# FASE 5: Verifica dello Stato dei Driver Nvidia / DKMS
# -----------------------------------------------------------------------------
log_info "Fase 5: Verifica dello stato dei moduli DKMS per Nvidia..."

echo -e "\n{$BOLD}--- Output di 'sudo dkms status' ---{$RESET}"
sudo dkms status

echo -e "\n{$BOLD}--- Versione Kernel Attualmente in uso ---{$RESET}"
uname -r

echo -e "\n{$GREEN}{$BOLD}=== Procedura completata con successo! ==={$RESET}"
log_info "Puoi riavviare il sistema per attivare il nuovo kernel BORE."
