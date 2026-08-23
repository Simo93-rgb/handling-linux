#!/usr/bin/env fish

set -l grub_config /boot/grub/grub.cfg

# Verifica l'esistenza del comando grub-set-default
if not type -q grub-set-default
    echo "Errore: il comando grub-set-default non e' installato."
    exit 1
end

# Estrazione delle voci menuentry tramite sudo cat per aggirare i permessi 0600
set -l kernels (sudo cat $grub_config 2>/dev/null | awk -F "'" '/^[[:space:]]*menuentry / {print $2}')

if test (count $kernels) -eq 0
    echo "Errore: impossibile leggere o nessun kernel trovato in $grub_config."
    exit 1
end

echo "Kernel disponibili:"
for index in (seq (count $kernels))
    echo "$index) $kernels[$index]"
end

while true
    read -P "Inserisci il numero del kernel da preselezionare: " selection

    if string match -rq '^[0-9]+$' -- $selection
        if test $selection -ge 1; and test $selection -le (count $kernels)
            break
        end
    end

    echo "Selezione non valida. Scegli un numero tra 1 e "(count $kernels)"."
end

set -l selected_kernel $kernels[$selection]
echo "Kernel selezionato: $selected_kernel"
read -P "Confermi il salvataggio in GRUB? [s/N] " confirmation

if not string match -rq '^[sS]$' -- $confirmation
    echo "Operazione annullata."
    exit 0
end

if sudo grub-set-default "$selected_kernel"
    echo "Preselezione GRUB aggiornata con successo."
else
    echo "Errore: impossibile aggiornare la preselezione GRUB."
    exit 1
end