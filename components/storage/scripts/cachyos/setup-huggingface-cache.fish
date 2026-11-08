#!/usr/bin/env fish

# ==============================================================================
# Script di Configurazione / Rilocazione Cache Hugging Face
# ==============================================================================
# Rilocazione della cache Hugging Face (HF_HOME, HF_HUB_CACHE, TRANSFORMERS_CACHE)
# su storage secondario ad alta capienza, configurando l'ambiente globale systemd
# e l'ambiente universale della shell Fish.
# ==============================================================================

set -l default_target "/mnt/Games/.cache/huggingface"
set -l target_path $default_target

if test (count $argv) -ge 1
    set target_path (string trim -r -c '/' $argv[1])
end

set -l env_dir "$HOME/.config/environment.d"
set -l env_file "$env_dir/10-huggingface.conf"

echo "================================================================="
echo "   Configurazione Cache Hugging Face su Storage Secondario       "
echo "================================================================="
echo "Target path: $target_path"
echo ""

# 1. Verifica e creazione directory di destinazione
if not test -d "$target_path"
    echo (set_color cyan)"[+] Creazione directory target: $target_path"(set_color normal)
    mkdir -p "$target_path"
    if test $status -ne 0
        echo (set_color red)"[!] Errore: Impossibile creare la directory di destinazione. Verificare permessi o mount point."(set_color normal)
        exit 1
    end
else
    echo (set_color green)"[OK] Directory target esistente: $target_path"(set_color normal)
end

# Verifica permessi di scrittura nella cartella
if not test -w "$target_path"
    echo (set_color red)"[!] Errore: La directory $target_path non è scrivibile dall'utente corrente."(set_color normal)
    exit 1
end

# 2. Configura generatore environment.d per la sessione utente di systemd
mkdir -p "$env_dir"

echo "# Configurazione automatica ambiente Hugging Face per sessione utente" > "$env_file"
echo "HF_HOME=$target_path" >> "$env_file"
echo "HF_HUB_CACHE=$target_path/hub" >> "$env_file"
echo "TRANSFORMERS_CACHE=$target_path/hub" >> "$env_file"

echo (set_color green)"[OK] File environment.d generato: $env_file"(set_color normal)

# 3. Propaga immediatamente le variabili nell'istanza systemd utente attiva
systemctl --user import-environment HF_HOME HF_HUB_CACHE TRANSFORMERS_CACHE
if test $status -eq 0
    echo (set_color green)"[OK] Variabili importate nell'ambiente systemd utente attivo"(set_color normal)
else
    echo (set_color yellow)"[-] Avviso: Impossibile importare in systemd utente (demone non attivo?)"(set_color normal)
end

# 4. Aggiorna l'ambiente universale di Fish
set -Ux HF_HOME "$target_path"
set -Ux HF_HUB_CACHE "$target_path/hub"
set -Ux TRANSFORMERS_CACHE "$target_path/hub"

echo (set_color green)"[OK] Variabili universali Fish registrate:"(set_color normal)
echo "     - HF_HOME: $HF_HOME"
echo "     - HF_HUB_CACHE: $HF_HUB_CACHE"
echo "     - TRANSFORMERS_CACHE: $TRANSFORMERS_CACHE"

echo ""
echo (set_color cyan)"Configurazione completata con successo."(set_color normal)
echo "Tutte le applicazioni grafiche, CLI e servizi systemd utilizzeranno il nuovo percorso."
echo "================================================================="
