#!/bin/bash
# Script: ban_abuseipdb.sh — Bloquea IPs maliciosas via ipset + iptables
# Author: Hugopvigo - https://hugopvigo.es/
# Credits: xRuffKez - https://github.com/xRuffKez

API_KEY="your_abuseipdb_api_key"
CONFIDENCE_MIN=90
ENABLE_IPV6=true
FILE="/tmp/abuseipdb_blacklist.json"
LOG_FILE="/var/log/ban_abuseipdb.log"
IPSET_V4="abuseipdb"
IPSET_V6="abuseipdb6"
IPSET_SAVE="/etc/ipset.conf"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_requirements() {
    for cmd in jq curl ipset iptables; do
        command -v "$cmd" >/dev/null 2>&1 || { log "ERROR: $cmd no encontrado."; exit 1; }
    done
    [ "$ENABLE_IPV6" = true ] && ! command -v ip6tables >/dev/null 2>&1 && {
        log "AVISO: ip6tables no encontrado, desactivando IPv6."
        ENABLE_IPV6=false
    }
}

ensure_sets_and_rules() {
    # Crear sets si no existen (se pierden al reiniciar; el @reboot del cron los restaura)
    ipset list "$IPSET_V4" >/dev/null 2>&1 || \
        ipset create "$IPSET_V4" hash:ip hashsize 65536 maxelem 500000 family inet

    if [ "$ENABLE_IPV6" = true ]; then
        ipset list "$IPSET_V6" >/dev/null 2>&1 || \
            ipset create "$IPSET_V6" hash:ip hashsize 65536 maxelem 500000 family inet6
    fi

    # Añadir reglas iptables solo si no existen (idempotente)
    iptables  -C INPUT   -m set --match-set "$IPSET_V4" src -j DROP 2>/dev/null || \
        iptables  -I INPUT   -m set --match-set "$IPSET_V4" src -j DROP
    iptables  -C FORWARD -m set --match-set "$IPSET_V4" src -j DROP 2>/dev/null || \
        iptables  -I FORWARD -m set --match-set "$IPSET_V4" src -j DROP

    if [ "$ENABLE_IPV6" = true ]; then
        ip6tables -C INPUT   -m set --match-set "$IPSET_V6" src -j DROP 2>/dev/null || \
            ip6tables -I INPUT   -m set --match-set "$IPSET_V6" src -j DROP
        ip6tables -C FORWARD -m set --match-set "$IPSET_V6" src -j DROP 2>/dev/null || \
            ip6tables -I FORWARD -m set --match-set "$IPSET_V6" src -j DROP
    fi
}

fetch_blacklist() {
    log "Descargando lista de IPs maliciosas (confianza >= ${CONFIDENCE_MIN}%)..."
    curl -sG https://api.abuseipdb.com/api/v2/blacklist \
        --data-urlencode "confidenceMinimum=$CONFIDENCE_MIN" \
        -H "Key: $API_KEY" \
        -H "Accept: application/json" \
        -o "$FILE"
    [ $? -ne 0 ] && { log "ERROR: Falló la descarga de la lista."; exit 1; }

    jq empty "$FILE" 2>/dev/null || { log "ERROR: JSON descargado inválido."; exit 1; }
}

apply_blacklist() {
    log "Aplicando lista de IPs..."

    local TMP_V4="${IPSET_V4}_tmp"
    local TMP_V6="${IPSET_V6}_tmp"

    # Sets temporales para swap atómico (el set activo nunca queda vacío)
    ipset destroy "$TMP_V4" 2>/dev/null
    ipset create  "$TMP_V4" hash:ip hashsize 65536 maxelem 500000 family inet

    if [ "$ENABLE_IPV6" = true ]; then
        ipset destroy "$TMP_V6" 2>/dev/null
        ipset create  "$TMP_V6" hash:ip hashsize 65536 maxelem 500000 family inet6
    fi

    local count_v4=0 count_v6=0

    while IFS= read -r ip; do
        if [[ "$ip" == *:* ]]; then
            [ "$ENABLE_IPV6" = true ] && ipset add "$TMP_V6" "$ip" 2>/dev/null && ((count_v6++))
        else
            ipset add "$TMP_V4" "$ip" 2>/dev/null && ((count_v4++))
        fi
    done < <(jq -r '.data[].ipAddress' "$FILE")

    log "IPs cargadas: $count_v4 IPv4, $count_v6 IPv6"

    # Swap atómico y limpieza
    ipset swap "$TMP_V4" "$IPSET_V4" && ipset destroy "$TMP_V4"

    if [ "$ENABLE_IPV6" = true ]; then
        ipset swap "$TMP_V6" "$IPSET_V6" && ipset destroy "$TMP_V6"
    fi

    # Guardar para restaurar tras reboot (via @reboot en cron)
    ipset save > "$IPSET_SAVE"
    log "Sets guardados en $IPSET_SAVE"
}

main() {
    log "=== Script iniciado ==="
    check_requirements
    ensure_sets_and_rules
    fetch_blacklist
    apply_blacklist
    local total
    total=$(ipset list "$IPSET_V4" | grep "Number of entries" | awk '{print $NF}')
    log "=== Finalizado. $total IPs IPv4 activas en ipset ==="
}

main
