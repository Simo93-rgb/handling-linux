# Configurazione GRUB: autosave e menu diretto

Per fare in modo che GRUB mantenga sempre selezionato il kernel BORE e elimini la necessità di navigare nel sottomenu *Advanced Options*, il file `/etc/default/grub` richiede le seguenti impostazioni.

## 1. File `/etc/default/grub`

```text
# Imposta la voce di default sulla memoria dell'ultimo avvio effettuato
GRUB_DEFAULT=saved

# Abilita il salvataggio automatico dell'ultima selezione nel file grubenv
GRUB_SAVEDEFAULT=true

# Disabilita il sottomenu 'Advanced Options', portando tutti i kernel nel menu principale
GRUB_DISABLE_SUBMENU='true'
```

## 2. Rigenerazione della configurazione

Dopo aver salvato la modifica, applica i cambiamenti aggiornando il menu di avvio:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

## 3. Obiettivo della configurazione

Questa impostazione garantisce che:

- il kernel preferito venga mantenuto automaticamente
- il menu GRUB mostri direttamente i kernel disponibili
- l'utente possa scegliere il kernel senza dover entrare nel sottomenu di avanzate opzioni

## 4. Quando usarla

Questo setup è utile soprattutto dopo la [compilazione di un nuovo kernel personalizzato](kernel-build.md), quando si vuole evitare il passaggio manuale attraverso il menu avanzato e migliorare la fluidità del workflow di boot.
