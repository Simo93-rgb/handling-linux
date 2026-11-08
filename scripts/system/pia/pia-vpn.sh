#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# PIA WireGuard VPN Daemon with Port Forwarding & Watchdog
# ==============================================================================
# Questo script gestisce l'intero ciclo di vita della connessione WireGuard PIA:
# 1. Carica le credenziali da /etc/pia/credentials
# 2. Verifica la presenza di un token valido (e lo rinnova all'occorrenza)
# 3. Risolve il server ottimale (IT Milano o ping minimo con supporto PF)
# 4. Registra le chiavi WireGuard effimere con le API REST di PIA
# 5. Genera la configurazione ed attiva il tunnel con DNS anti-leak (10.0.0.242)
# 6. Negozia il Port Forwarding persistendo la firma (stessa porta fino a 2 mesi)
# 7. Mantiene attivo il keepalive (bindPort ogni 15 min) e vigila sulla linea
# ==============================================================================

# Caricamento credenziali di sistema (parsing sicuro per evitare espansione di caratteri speciali come '$' nella password)
CREDENTIALS_FILE="/etc/pia/credentials"
if [[ -f "$CREDENTIALS_FILE" ]]; then
    while IFS='=' read -r key val || [[ -n "$key" ]]; do
        key=$(echo "$key" | tr -d ' \t\r\n')
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        # Rimuove apici singoli o doppi di delimitazione
        val=$(echo "$val" | sed -e 's/^[ \t]*["'\''"]//' -e 's/["'\''"][ \t\r\n]*$//')
        # Esporta solo se non già valorizzato dall'EnvironmentFile di systemd
        if [[ -z "${!key:-}" ]]; then
            export "$key"="$val"
        fi
    done < "$CREDENTIALS_FILE"
fi

PIA_REPO="${PIA_REPO:-/home/simone/GitHub/manual-connections}"
PREFERRED_REGION="${PREFERRED_REGION:-italy}"
PIA_PF="${PIA_PF:-true}"
PIA_DNS="${PIA_DNS:-true}"

TOKEN_FILE="/opt/piavpn-manual/token"
PF_CACHE_FILE="/opt/piavpn-manual/pf_payload.json"
ACTIVE_PORT_FILE="/opt/piavpn-manual/active_port"
RUNTIME_PORT_FILE="/run/pia_port"

CACERT="$PIA_REPO/ca.rsa.4096.crt"

echo "=== Avvio demone PIA WireGuard VPN ==="

# Verifica dipendenze
for cmd in curl jq wg wg-quick ping; do
    if ! command -v "$cmd" >/dev/null; then
        echo "ERRORE: Comando richiesto '$cmd' non trovato nel sistema." >&2
        exit 1
    fi
done

if [[ ! -f "$CACERT" ]]; then
    echo "ERRORE: Certificato CA non trovato in $CACERT" >&2
    exit 1
fi

# 1. Verifica e rinnovo automatico del token se assente o non valido
if [[ ! -s "$TOKEN_FILE" ]]; then
    echo "Token PIA non presente. Eseguo rinnovo iniziale..."
    bash /home/simone/GitHub/handling-linux/scripts/system/pia/renew-token.sh
fi

PIA_TOKEN=$(head -n 1 "$TOKEN_FILE" | tr -d '\r\n')
if [[ -z "$PIA_TOKEN" || "$PIA_TOKEN" == "null" ]]; then
    echo "ERRORE: Token PIA non valido in $TOKEN_FILE. Uscita." >&2
    exit 1
fi

# 2. Selezione Regione e Server WireGuard
echo "Recupero elenco server PIA..."
SERVERLIST_JSON=$(curl -s --max-time 10 "https://serverlist.piaservers.net/vpninfo/servers/v4" | head -n 1)

if [[ -z "$SERVERLIST_JSON" ]]; then
    echo "ERRORE: Impossibile scaricare la lista server PIA." >&2
    exit 1
fi

selected_region=""
if [[ "$PREFERRED_REGION" != "auto" ]]; then
    # Cerca la regione preferita (es. italy)
    has_region=$(echo "$SERVERLIST_JSON" | jq -r --arg r "$PREFERRED_REGION" '.regions[] | select(.id==$r) | .id')
    if [[ -n "$has_region" ]]; then
        selected_region="$has_region"
    else
        echo "AVVISO: Regione '$PREFERRED_REGION' non trovata. Fallback su selezione automatica." >&2
    fi
fi

if [[ -z "$selected_region" ]]; then
    echo "Selezione automatica regione a latenza minima con supporto Port Forwarding..."
    # Filtra le regioni che supportano il Port Forwarding
    pf_regions=$(echo "$SERVERLIST_JSON" | jq -r '.regions[] | select(.port_forward==true) | .servers.wg[0].ip + " " + .id')

    # Ping di test rapido su ogni server candidato
    fastest_r=""
    fastest_time=999999
    while read -r ip reg_id; do
        [[ -z "$ip" ]] && continue
        # Ping singolo con timeout di 1s
        rtt=$(ping -c 1 -W 1 "$ip" 2>/dev/null | grep -o 'time=[0-9.]*' | cut -d'=' -f2 || echo "")
        if [[ -n "$rtt" ]]; then
            # Confronto latenza floating point
            is_faster=$(awk -v r="$rtt" -v f="$fastest_time" 'BEGIN {print (r < f) ? 1 : 0}')
            if [[ "$is_faster" -eq 1 ]]; then
                fastest_time="$rtt"
                fastest_r="$reg_id"
            fi
        fi
    done <<< "$pf_regions"

    selected_region="${fastest_r:-italy}"
fi

region_data=$(echo "$SERVERLIST_JSON" | jq -r --arg r "$selected_region" '.regions[] | select(.id==$r)')
region_name=$(echo "$region_data" | jq -r '.name')
WG_SERVER_IP=$(echo "$region_data" | jq -r '.servers.wg[0].ip')
WG_HOSTNAME=$(echo "$region_data" | jq -r '.servers.wg[0].cn')

echo "Regione selezionata: $region_name ($selected_region)"
echo "Server WireGuard:    $WG_SERVER_IP ($WG_HOSTNAME)"

# 3. Generazione chiavi effimere ed handshake WireGuard REST API
priv_key=$(wg genkey)
pub_key=$(echo "$priv_key" | wg pubkey)

echo "Autenticazione handshake WireGuard su ${WG_HOSTNAME}:1337..."
wireguard_json=$(curl -s -G \
    --connect-to "${WG_HOSTNAME}::${WG_SERVER_IP}:" \
    --cacert "$CACERT" \
    --data-urlencode "pt=${PIA_TOKEN}" \
    --data-urlencode "pubkey=${pub_key}" \
    "https://${WG_HOSTNAME}:1337/addKey")

if [[ $(echo "$wireguard_json" | jq -r '.status') != "OK" ]]; then
    echo "ERRORE: API WireGuard ha rifiutato la richiesta. Risposta:" >&2
    echo "$wireguard_json" >&2
    exit 1
fi

peer_ip=$(echo "$wireguard_json" | jq -r '.peer_ip')
server_key=$(echo "$wireguard_json" | jq -r '.server_key')
server_port=$(echo "$wireguard_json" | jq -r '.server_port')
dns_server=$(echo "$wireguard_json" | jq -r '.dns_servers[0] // "10.0.0.242"')

# 4. Creazione configurazione WireGuard
mkdir -p /etc/wireguard
cat <<EOF > /etc/wireguard/pia.conf
[Interface]
Address = $peer_ip
PrivateKey = $priv_key
DNS = $dns_server

[Peer]
PersistentKeepalive = 25
PublicKey = $server_key
AllowedIPs = 0.0.0.0/0
Endpoint = ${WG_SERVER_IP}:${server_port}
EOF
chmod 600 /etc/wireguard/pia.conf

# Funzione di pulizia su arresto (SIGTERM/SIGINT)
cleanup() {
    echo "=== Disattivazione tunnel WireGuard ==="
    rm -f "$RUNTIME_PORT_FILE" "$ACTIVE_PORT_FILE"
    wg-quick down pia 2>/dev/null || true
    echo "Demone terminato regolarmente."
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# 5. Attivazione interfaccia WireGuard
echo "Attivazione interfaccia pia tramite wg-quick..."
wg-quick down pia 2>/dev/null || true
wg-quick up pia

echo "Tunnel WireGuard attivo! Indirizzo assegnato: $peer_ip"

# 6. Negoziazione Port Forwarding (con persistenza payload e firma)
pf_payload=""
pf_signature=""
active_port=""

if [[ "$PIA_PF" == "true" ]]; then
    echo "=== Configurazione Port Forwarding ==="
    reused_signature=false

    # Controllo se esiste già una firma in cache non scaduta
    if [[ -f "$PF_CACHE_FILE" ]]; then
        cached_payload=$(jq -r '.payload // empty' "$PF_CACHE_FILE" 2>/dev/null || echo "")
        cached_signature=$(jq -r '.signature // empty' "$PF_CACHE_FILE" 2>/dev/null || echo "")

        if [[ -n "$cached_payload" && -n "$cached_signature" ]]; then
            expires_at=$(echo "$cached_payload" | base64 -d 2>/dev/null | jq -r '.expires_at // empty')
            if [[ -n "$expires_at" ]]; then
                expires_epoch=$(date -d "$expires_at" +%s 2>/dev/null || echo 0)
                now_epoch=$(date +%s)
                # Se mancano più di 24 ore alla scadenza, riutilizziamo la stessa porta
                if (( expires_epoch > now_epoch + 86400 )); then
                    pf_payload="$cached_payload"
                    pf_signature="$cached_signature"
                    reused_signature=true
                    echo "Port Forwarding: riutilizzo firma memorizzata (scadenza: $expires_at)"
                fi
            fi
        fi
    fi

    if [[ "$reused_signature" != "true" ]]; then
        echo "Port Forwarding: richiesta nuova firma/porta a PIA..."
        pf_response=$(curl -s -m 7 \
            --connect-to "${WG_HOSTNAME}::${WG_SERVER_IP}:" \
            --cacert "$CACERT" \
            -G --data-urlencode "token=${PIA_TOKEN}" \
            "https://${WG_HOSTNAME}:19999/getSignature" || echo "{}")

        if [[ $(echo "$pf_response" | jq -r '.status') == "OK" ]]; then
            echo "$pf_response" > "$PF_CACHE_FILE"
            chmod 600 "$PF_CACHE_FILE"
            pf_payload=$(echo "$pf_response" | jq -r '.payload')
            pf_signature=$(echo "$pf_response" | jq -r '.signature')
        else
            echo "AVVISO: Impossibile ottenere firma Port Forwarding da PIA. Risposta:" >&2
            echo "$pf_response" >&2
        fi
    fi

    if [[ -n "$pf_payload" && -n "$pf_signature" ]]; then
        active_port=$(echo "$pf_payload" | base64 -d 2>/dev/null | jq -r '.port // empty')
        if [[ -n "$active_port" ]]; then
            echo "$active_port" > "$ACTIVE_PORT_FILE"
            chmod 644 "$ACTIVE_PORT_FILE"
            echo "$active_port" > "$RUNTIME_PORT_FILE"
            chmod 644 "$RUNTIME_PORT_FILE"

            echo ">>> PORTA FORWARDATA ATTIVA: $active_port <<<"

            # Primo bindPort immediato
            bind_res=$(curl -Gs -m 7 \
                --connect-to "${WG_HOSTNAME}::${WG_SERVER_IP}:" \
                --cacert "$CACERT" \
                --data-urlencode "payload=${pf_payload}" \
                --data-urlencode "signature=${pf_signature}" \
                "https://${WG_HOSTNAME}:19999/bindPort" || echo "{}")
            echo "Risultato bindPort: $(echo "$bind_res" | jq -r '.status // "errore"')"
        fi
    fi
fi

# 7. Watchdog Loop & Port Forwarding Keepalive
echo "=== Demone operativo: avvio Watchdog (controllo ogni 30s) ==="
consecutive_fails=0
last_pf_refresh=$(date +%s)

while true; do
    sleep 30

    # Verifica interfaccia
    if ! ip link show dev pia &>/dev/null; then
        echo "Watchdog: interfaccia 'pia' non presente! Uscita per riavvio." >&2
        exit 1
    fi

    # Ping di controllo verso il gateway VPN/DNS (10.0.0.242)
    if ! ping -c 1 -W 3 10.0.0.242 &>/dev/null; then
        ((consecutive_fails++))
        echo "Watchdog: ping verso il gateway VPN fallito ($consecutive_fails/3)" >&2
        if [[ $consecutive_fails -ge 3 ]]; then
            echo "Watchdog: connessione VPN interrotta. Riavvio demone per riconnessione." >&2
            exit 1
        fi
    else
        consecutive_fails=0
    fi

    # Refresh bindPort ogni 15 minuti (900 secondi) se il Port Forwarding è attivo
    current_epoch=$(date +%s)
    if [[ -n "$pf_payload" && -n "$pf_signature" ]]; then
        if (( current_epoch - last_pf_refresh >= 900 )); then
            echo "Refresh periodico Port Forwarding (bindPort)..."
            bind_refresh=$(curl -Gs -m 7 \
                --connect-to "${WG_HOSTNAME}::${WG_SERVER_IP}:" \
                --cacert "$CACERT" \
                --data-urlencode "payload=${pf_payload}" \
                --data-urlencode "signature=${pf_signature}" \
                "https://${WG_HOSTNAME}:19999/bindPort" || echo "{}")

            if [[ $(echo "$bind_refresh" | jq -r '.status') == "OK" ]]; then
                echo "Refresh bindPort completato con successo (porta $active_port mantenuta)."
                last_pf_refresh=$current_epoch
            else
                echo "AVVISO: Refresh bindPort fallito. Ritenterò al prossimo ciclo." >&2
            fi
        fi
    fi
done
