#!/usr/bin/env fish

# ==============================================================================
# Script di Diagnostica e Verifica: Configurazione Hugging Face Cache
# ==============================================================================
# Verifica che:
# 1. Le variabili siano definite correttamente a livello systemd e Fish
# 2. Il file environment.d esista e corrisponda
# 3. La directory di destinazione esista, sia montata e scrivibile
# 4. Le librerie Python (huggingface_hub/transformers) risolvano il percorso corretto
# ==============================================================================

set -l env_file "$HOME/.config/environment.d/10-huggingface.conf"

echo "================================================================="
echo "       Diagnostica Configurazione Cache Hugging Face             "
echo "================================================================="
echo ""

# 1. Verifica file environment.d
echo (set_color --bold)"--- 1. File di configurazione sessione (~/.config/environment.d) ---"(set_color normal)
if test -f "$env_file"
    echo (set_color green)"[OK] File presente: $env_file"(set_color normal)
    cat "$env_file" | while read -l line
        test -n "$line"; and not string match -q "#*" "$line"; and echo "     $line"
    end
else
    echo (set_color red)"[FAIL] File non trovato: $env_file"(set_color normal)
end

echo ""
# 2. Verifica ambiente systemd utente
echo (set_color --bold)"--- 2. Ambiente Systemd User Session (systemctl --user) ---"(set_color normal)
set -l sys_hf_home (systemctl --user show-environment 2>/dev/null | string match -r '^HF_HOME=(.*)' | tail -n 1)
set -l sys_hf_hub (systemctl --user show-environment 2>/dev/null | string match -r '^HF_HUB_CACHE=(.*)' | tail -n 1)
set -l sys_trans (systemctl --user show-environment 2>/dev/null | string match -r '^TRANSFORMERS_CACHE=(.*)' | tail -n 1)

if test -n "$sys_hf_home"
    echo (set_color green)"[OK] HF_HOME esportata in systemd: "(set_color cyan)"$sys_hf_home"(set_color normal)
else
    echo (set_color red)"[FAIL] HF_HOME non definita in systemd --user"(set_color normal)
end

if test -n "$sys_hf_hub"
    echo (set_color green)"[OK] HF_HUB_CACHE esportata in systemd: "(set_color cyan)"$sys_hf_hub"(set_color normal)
else
    echo (set_color yellow)"[-] HF_HUB_CACHE non trovata in systemd --user"(set_color normal)
end

if test -n "$sys_trans"
    echo (set_color green)"[OK] TRANSFORMERS_CACHE esportata in systemd: "(set_color cyan)"$sys_trans"(set_color normal)
else
    echo (set_color yellow)"[-] TRANSFORMERS_CACHE non trovata in systemd --user"(set_color normal)
end

echo ""
# 3. Verifica ambiente Fish
echo (set_color --bold)"--- 3. Ambiente Shell Fish (Variabili Universali) ---"(set_color normal)
if test -n "$HF_HOME"
    echo (set_color green)"[OK] \$HF_HOME attivo: "(set_color cyan)"$HF_HOME"(set_color normal)
else
    echo (set_color red)"[FAIL] \$HF_HOME non valorizzato in Fish"(set_color normal)
end

if test -n "$HF_HUB_CACHE"
    echo (set_color green)"[OK] \$HF_HUB_CACHE attivo: "(set_color cyan)"$HF_HUB_CACHE"(set_color normal)
else
    echo (set_color yellow)"[-] \$HF_HUB_CACHE non valorizzato in Fish"(set_color normal)
end

if test -n "$TRANSFORMERS_CACHE"
    echo (set_color green)"[OK] \$TRANSFORMERS_CACHE attivo: "(set_color cyan)"$TRANSFORMERS_CACHE"(set_color normal)
else
    echo (set_color yellow)"[-] \$TRANSFORMERS_CACHE non valorizzato in Fish"(set_color normal)
end

echo ""
# 4. Verifica filesystem e mount point
echo (set_color --bold)"--- 4. Verifica Directory e Filesystem ---"(set_color normal)
set -l target_check "$HF_HOME"
if test -z "$target_check"
    set target_check "/mnt/Games/.cache/huggingface"
end

if test -d "$target_check"
    echo (set_color green)"[OK] Directory target esistente: $target_check"(set_color normal)
    if test -w "$target_check"
        echo (set_color green)"[OK] Permessi di scrittura verificati"(set_color normal)
    else
        echo (set_color red)"[FAIL] Nessun permesso di scrittura su $target_check"(set_color normal)
    end
    
    # Controllo spazio su disco
    set -l disk_info (df -h "$target_check" 2>/dev/null | tail -n 1)
    echo "     Filesystem: $disk_info"
else
    echo (set_color red)"[FAIL] Directory target inesistente: $target_check"(set_color normal)
end

echo ""
# 5. Test di risoluzione runtime (se Python / uv disponibile)
echo (set_color --bold)"--- 5. Test Risoluzione Runtime Python ---"(set_color normal)
set -l test_code 'import os; hf_home = os.getenv("HF_HOME"); hf_hub = os.getenv("HF_HUB_CACHE"); print(f"Runtime os.environ -> HF_HOME={hf_home} | HF_HUB_CACHE={hf_hub}")'
set -l res ""

if command -q uv
    set res (uv run python -c "$test_code" 2>/dev/null)
else if command -q python3
    set res (python3 -c "$test_code" 2>/dev/null)
else if command -q python
    set res (python -c "$test_code" 2>/dev/null)
end

if test -n "$res"
    echo (set_color green)"[OK] $res"(set_color normal)
else
    echo (set_color yellow)"[-] Nessun interprete Python rilevato o errore nell'esecuzione"(set_color normal)
end

echo ""
echo "================================================================="
