#!/bin/bash
# Author : Hugopvigo - https://hugopvigo.es/
# Script para reportar IPs a AbuseIPDB desde iptables/fail2ban

API_KEY="TU_CLAVE_API"  # Reemplaza con tu clave de AbuseIPDB
REPORTED_LOG="/var/log/ipabuse_reported.log"
WHITELIST_FILE="/etc/ipabuse_whitelist.txt" #por si tienes ips para añadir en la lista blanca

# Crear archivos si no existen
touch "$REPORTED_LOG" "$WHITELIST_FILE"

# Función para obtener categorías de AbuseIPDB según el jail
get_categories_by_jail() {
  local jail="$1"
  case "$jail" in
    "sshd") echo "22" ;;
    "apache-auth") echo "21" ;;
    "apache-env-access") echo "21,27" ;;
    "modsecurity") echo "21,27,28" ;;
    *) echo "18" ;;
  esac
}

# Función para obtener el comentario según el jail
get_comment_by_jail() {
  local jail="$1"
  case "$jail" in
    "sshd") echo "Intentos fallidos de inicio de sesión SSH." ;;
    "apache-auth") echo "Intentos fallidos de autenticación HTTP." ;;
    "apache-env-access") echo "Actividad sospechosa en entorno web." ;;
    "modsecurity") echo "Posible ataque detectado por ModSecurity." ;;
    *) echo "IP bloqueada por Fail2Ban [$jail]." ;;
  esac
}

# Obtener lista de IPs baneadas con su jail
BANNED_LIST=$(sudo fail2ban-client banned 2>/dev/null)

if [ -z "$BANNED_LIST" ]; then
    echo "No se encontraron IPs baneadas en Fail2Ban."
    exit 1
fi

echo "$BANNED_LIST" | while read -r line; do
    JAIL=$(echo "$line" | grep -oP "^\{'?\K[^']+" | tr -d ":")  # Extrae el jail
    IP_LIST=$(echo "$line" | grep -oP "'\K\d+\.\d+\.\d+\.\d+(?=')")  # Extrae las IPs

    for IP in $IP_LIST; do
        # Verificar formato IP
        if ! [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Error: IP inválida detectada ($IP), ignorando..."
            continue
        fi

        # Omitir si está en la lista blanca
        if grep -Fxq "$IP" "$WHITELIST_FILE"; then
            echo "IP en lista blanca, omitiendo: $IP"
            continue
        fi

        # Omitir si ya ha sido reportada
        if grep -Fxq "$IP" "$REPORTED_LOG"; then
            echo "IP ya reportada previamente, omitiendo: $IP"
            continue
        fi

        CATEGORIES=$(get_categories_by_jail "$JAIL")
        COMMENT=$(get_comment_by_jail "$JAIL")
        TIMESTAMP=$(date --utc +%Y-%m-%dT%H:%M:%SZ)

        echo "Reportando IP: $IP desde Jail: $JAIL"

        RESPONSE=$(curl -s -X POST "https://api.abuseipdb.com/api/v2/report" \
          --data-urlencode "ip=$IP" \
          -d "categories=$CATEGORIES" \
          --data-urlencode "comment=$COMMENT" \
          --data-urlencode "timestamp=$TIMESTAMP" \
          -H "Key: $API_KEY" \
          -H "Accept: application/json")

        echo "Respuesta de AbuseIPDB: $RESPONSE"

        # Si el reporte fue exitoso, añadir IP al log de reportados
        if echo "$RESPONSE" | grep -q '"success":true'; then
            echo "$IP" >> "$REPORTED_LOG"
        fi
    done
done

echo "Proceso de reporte completado."
