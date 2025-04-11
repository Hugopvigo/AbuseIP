#!/bin/bash
# Author : Hugopvigo - https://hugopvigo.es/
# Credits: xRuffKez - https://github.com/xRuffKez

API_KEY="your_abuseipdb_api_key"
CONFIDENCE_MIN=90
ENABLE_IPV6=true
FILE="/tmp/abuseipdb_blacklist.json"
BLOCKED_IPS_FILE="/tmp/blocked_ips.txt"
LOG_FILE="/var/log/ban_abuseipdb.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_requirements() {
    command -v jq >/dev/null 2>&1 || { log "jq no encontrado. Instálalo antes de ejecutar el script."; exit 1; }
    command -v ip >/dev/null 2>&1 || { log "iproute2 no encontrado."; exit 1; }
}

fetch_blacklist() {
    log "Descargando lista de IPs maliciosas..."
    curl -sG https://api.abuseipdb.com/api/v2/blacklist \
        --data-urlencode "confidenceMinimum=$CONFIDENCE_MIN" \
        -H "Key: $API_KEY" \
        -H "Accept: application/json" \
        -o "$FILE"

    if [ $? -ne 0 ]; then
        log "Error: Falló la descarga de la lista."
        exit 1
    fi
}

validate_json() {
    jq empty "$FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        log "Error: El archivo JSON descargado no es válido."
        exit 1
    fi
}

extract_ips() {
    log "Extrayendo direcciones IP del JSON..."
    jq -r '.data[] | .ipAddress' "$FILE" > "/tmp/new_ips.txt"

    if [ ! -s "/tmp/new_ips.txt" ]; then
        log "No se encontraron nuevas IPs."
        exit 0
    fi

    log "Se extrajeron $(wc -l < /tmp/new_ips.txt) direcciones IP."
}

manage_blocked_ips() {
    log "Gestionando direcciones IP bloqueadas..."
    NEW_BLOCKED_IPS="/tmp/updated_blocked_ips.txt"
    touch "$NEW_BLOCKED_IPS"
    current_time=$(date +%s)
    threshold=$((30 * 24 * 60 * 60))

    # --- Paso 1: Limpiar IPs antiguas ---
    if [ -f "$BLOCKED_IPS_FILE" ]; then
        while IFS= read -r line; do
            ip_antigua=$(echo "$line" | awk '{print $1}')
            timestamp_antiguo=$(echo "$line" | awk '{print $2}')
            age=$(( current_time - timestamp_antiguo ))
            if [ "$age" -lt "$threshold" ]; then
                echo "$line" >> "$NEW_BLOCKED_IPS"
            else
                if [[ "$ip_antigua" == *:* && "$ENABLE_IPV6" = true ]]; then
                    ip -6 route del blackhole "$ip_antigua" 2>/dev/null && log "Desbloqueado IPv6 $ip_antigua"
                else
                    ip route del blackhole "$ip_antigua" 2>/dev/null && log "Desbloqueado IPv4 $ip_antigua"
                fi
            fi
        done < "$BLOCKED_IPS_FILE"
    fi  # <--- Corrección aquí

    # --- Paso 2: Agregar nuevas IPs evitando duplicados ---
    if [ -f "/tmp/new_ips.txt" ]; then
        while IFS= read -r ip_nueva; do
            if ! grep -q "^$ip_nueva " "$NEW_BLOCKED_IPS"; then
                if [[ "$ip_nueva" == *:* ]]; then
                    if [ "$ENABLE_IPV6" = true ]; then
                        ip -6 route add blackhole "$ip_nueva" 2>/dev/null && log "Bloqueado IPv6 $ip_nueva"
                    else
                        log "Saltando IPv6 $ip_nueva (IPv6 deshabilitado)"
                        continue
                    fi
                else
                    ip route add blackhole "$ip_nueva" 2>/dev/null && log "Bloqueado IPv4 $ip_nueva"
                fi
                echo "$ip_nueva $current_time" >> "$NEW_BLOCKED_IPS"
            fi
        done < "/tmp/new_ips.txt"
    fi

    # --- Paso 3: Sustituir archivo de IPs bloqueadas ---
    mv "$NEW_BLOCKED_IPS" "$BLOCKED_IPS_FILE"
    log "Archivo de IPs bloqueadas actualizado."
}

main() {
    log "Script iniciado."
    check_requirements
    fetch_blacklist
    validate_json
    extract_ips
    manage_blocked_ips
    log "Script finalizado correctamente."
}

main
