#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# PIA Token Renewal Script
# ==============================================================================
# Richiede un nuovo token di autenticazione PIA tramite get_token.sh e lo
# memorizza in /opt/piavpn-manual/token con permessi restrittivi (600).
# Viene eseguito periodicamente da systemd (pia-token-renew.timer).
# ==============================================================================

# 1. Validazione configurazione ed eseguibili
if [[ -z "${PIA_REPO:-}" ]]; then
    echo "ERRORE: PIA_REPO non è configurato in /etc/pia/credentials" >&2
    exit 1
fi

if [[ ! -f "$PIA_REPO/get_token.sh" ]]; then
    echo "ERRORE: get_token.sh non trovato in '$PIA_REPO'" >&2
    exit 1
fi

if [[ -z "${PIA_USER:-}" || -z "${PIA_PASS:-}" ]]; then
    echo "ERRORE: Credenziali PIA mancanti (PIA_USER / PIA_PASS)" >&2
    exit 1
fi

# 2. Protezione directory token e umask restrittiva
install -d -m 700 /opt/piavpn-manual
chmod 700 /opt/piavpn-manual
umask 077

token_file="/opt/piavpn-manual/token"

# 3. Richiesta nuovo token PIA
# Nota: lanciamo esplicitamente 'bash get_token.sh' per garantire la compatibilità
# con i contesti SELinux ed evitare problemi di permessi d'esecuzione.
exit_code=0
output=$(
    cd "$PIA_REPO"
    bash ./get_token.sh 2>&1
) || exit_code=$?

# Maschera il token nei log di systemd per sicurezza
sanitized_output=$(printf '%s\n' "$output" | sed -E 's/PIA_TOKEN=.*/PIA_TOKEN=[REDACTED]/')
printf '%s\n' "$sanitized_output"

# 4. Validazione esito e contenuto del token
# get_token.sh ufficiale ha un bug noto: in alcuni casi d'errore esce con codice 0
# o scrive "null" nel file del token. Effettuiamo una validazione rigorosa.
if [[ $exit_code -ne 0 ]]; then
    echo "ERRORE: Rinnovo token fallito (exit code: $exit_code)" >&2
    exit "$exit_code"
fi

if [[ ! -s "$token_file" ]]; then
    echo "ERRORE: Il file del token ($token_file) non è stato creato o è vuoto" >&2
    exit 1
fi

token_value=$(head -n 1 "$token_file" | tr -d '\r\n')
if [[ -z "$token_value" || "$token_value" == "null" || ${#token_value} -lt 20 ]]; then
    echo "ERRORE: Il token ottenuto non è valido o contiene 'null'. Rimuovo file corrotto." >&2
    rm -f "$token_file"
    exit 1
fi

if echo "$output" | grep -qi "Could not authenticate"; then
    echo "ERRORE: Autenticazione rifiutata da PIA. Credenziali non valide." >&2
    rm -f "$token_file"
    exit 1
fi

chmod 600 "$token_file"
echo "PIA token rinnovato con successo in $token_file"
