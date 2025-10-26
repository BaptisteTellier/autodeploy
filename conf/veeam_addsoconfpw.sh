#!/bin/bash

#==============================================================================
# Script d'automatisation Veeam VSA - Configuration Password
# Auto-destruction après exécution
#==============================================================================

# Configuration
VSA_USER="veeamso"
VSA_PASSWORD="$3"
TOTP_SECRET="$2"
CONFIG_PASSWORD="$1"
VSA_PORT="10443"

# Fichiers temporaires
COOKIE_JAR="/tmp/veeam_session_$$_$(date +%s)"
LOG_FILE="/var/log/veeam_addsoconfpw.log"
SCRIPT_PATH="$0"

#==============================================================================
# Fonction de logging sécurisé
#==============================================================================
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"

    case "$level" in
        INFO)
            echo -e "[INFO]${NC} ${message}"
            ;;
        WARN)
            echo -e "[WARN]${NC} ${message}"
            ;;
        ERROR)
            echo -e "[ERROR]${NC} ${message}"
            ;;
        *)
            echo "[${level}] ${message}"
            ;;
    esac
}

#==============================================================================
# Fonction de nettoyage sécurisé
#==============================================================================
cleanup() {
    log "INFO" "Nettoyage des fichiers temporaires"

    if [ -f "$COOKIE_JAR" ]; then
        shred -u -n 3 "$COOKIE_JAR" 2>/dev/null || rm -f "$COOKIE_JAR"
        log "INFO" "Cookie jar supprimé"
    fi

    unset VSA_PASSWORD TOTP_SECRET TOTP_CODE CSRF_TOKEN CONFIG_PASSWORD

    log "INFO" "Auto-destruction du script dans 2 secondes"
    sleep 2

    if command -v shred &> /dev/null; then
        shred -u -n 3 "$SCRIPT_PATH" 2>/dev/null
        log "INFO" "Script supprimé avec shred"
    else
        rm -f "$SCRIPT_PATH"
        log "WARN" "Script supprimé sans shred"
    fi
}

#trap cleanup EXIT

#==============================================================================
# Vérifications préalables
#==============================================================================
log "INFO" "Démarrage automatisation Veeam VSA"

if [ -z "$CONFIG_PASSWORD" ]; then
    log "ERROR" "Usage: $0 <password_config> <totp_secret> <vsa_password>"
    exit 1
fi

if ! command -v oathtool &> /dev/null; then
    log "ERROR" "oathtool non trouvé - Installation: dnf install oathtool"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    log "ERROR" "curl non trouvé"
    exit 1
fi

#==============================================================================
# Récupération IP locale
#==============================================================================
log "INFO" "Récupération adresse IP locale"

VSA_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if [ -z "$VSA_IP" ] || [ "$VSA_IP" = "127.0.0.1" ]; then
    VSA_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+')
fi
if [ -z "$VSA_IP" ] || [ "$VSA_IP" = "127.0.0.1" ]; then
    VSA_IP=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -n1)
fi
if [ -z "$VSA_IP" ] || [ "$VSA_IP" = "127.0.0.1" ]; then
    log "ERROR" "Impossible de récupérer IP locale"
    exit 1
fi

VSA_URL="https://${VSA_IP}:${VSA_PORT}"
log "INFO" "URL VSA: ${VSA_URL}"

#==============================================================================
# Génération TOTP
#==============================================================================
log "INFO" "Génération code TOTP"

TOTP_CODE=$(oathtool --totp -b "$TOTP_SECRET" 2>/dev/null)
if [ -z "$TOTP_CODE" ]; then
    log "ERROR" "Échec génération TOTP"
    exit 1
fi
log "INFO" "Code TOTP généré"

TIMESTAMP=$(date +%s)

#==============================================================================
# Étape 1: Authentification
#==============================================================================
log "INFO" "Étape 1/4: Authentification"

RESPONSE=$(curl -k -s -i -c "$COOKIE_JAR" -b "$COOKIE_JAR" -X POST "${VSA_URL}/api/auth/login" \
  -H "Content-Type: application/json;charset=UTF-8" \
  -H "x-otp-token: ${TOTP_CODE}" \
  -H "otp-client-unixtime: ${TIMESTAMP}" \
  -H "Accept: */*" \
  -H "Connection: keep-alive" \
  -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36" \
  -d "{\"user\":\"${VSA_USER}\",\"password\":\"${VSA_PASSWORD}\"}" 2>&1)

CSRF_TOKEN=$(echo "$RESPONSE" | grep -i "X-CSRF-TOKEN:" | awk '{print $2}' | tr -d '\r')
if [ -z "$CSRF_TOKEN" ]; then
    log "ERROR" "Échec authentification"
    exit 1
fi
log "INFO" "Authentification réussie"
sleep 1

#==============================================================================
# Étape 2: Vérification configuration
#==============================================================================
log "INFO" "Étape 2/4: Vérification configuration"

STATUS=$(curl -k -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" -w "%{http_code}" -o /dev/null \
  -X GET "${VSA_URL}/api/v1/bco/imported?" \
  -H "Accept: application/json" \
  -H "x-csrf-token: ${CSRF_TOKEN}" \
  -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36")

if [ "$STATUS" != "200" ]; then
    log "WARN" "Vérification: HTTP ${STATUS}"
else
    log "INFO" "Configuration vérifiée"
fi

#==============================================================================
# Étape 3: Ajout mot de passe
#==============================================================================
log "INFO" "Étape 3/4: Ajout mot de passe"

RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -X POST "${VSA_URL}/api/v1/bco/imported?" \
  -H "Content-Type: application/json;charset=UTF-8" \
  -H "Accept: application/json" \
  -H "x-csrf-token: ${CSRF_TOKEN}" \
  -H "Origin: ${VSA_URL}" \
  -H "Referer: ${VSA_URL}/configuration" \
  -H "Connection: keep-alive" \
  -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36" \
  -d "{\"hint\":\"\",\"passphrase\":\"${CONFIG_PASSWORD}\"}")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
if [ "$HTTP_CODE" = "200" ]; then
    log "INFO" "Mot de passe ajouté avec succès"
else
    log "ERROR" "Échec ajout (HTTP ${HTTP_CODE})"
    exit 1
fi

#==============================================================================
# Étape 4: Vérification finale
#==============================================================================
log "INFO" "Étape 4/4: Vérification finale"

FINAL_STATUS=$(curl -k -s -b "$COOKIE_JAR" -w "%{http_code}" -o /dev/null \
  -X GET "${VSA_URL}/api/v1/bco/imported?" \
  -H "Accept: application/json" \
  -H "x-csrf-token: ${CSRF_TOKEN}" \
  -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36")

if [ "$FINAL_STATUS" = "200" ]; then
    log "INFO" "Vérification finale réussie"
else
    log "WARN" "Vérification finale: HTTP ${FINAL_STATUS}"
fi

#==============================================================================
# Étape 5: Création mot de passe configuration courante
#==============================================================================
log "INFO" "Étape 5/5: Création mot de passe configuration courante"

RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -X POST "${VSA_URL}/api/v1/bco/current?" \
  -H "Content-Type: application/json;charset=UTF-8" \
  -H "Accept: application/json" \
  -H "x-csrf-token: ${CSRF_TOKEN}" \
  -H "Origin: ${VSA_URL}" \
  -H "Referer: ${VSA_URL}/configuration" \
  -H "Connection: keep-alive" \
  -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36" \
  -d "{\"hint\":\"\",\"passphrase\":\"${CONFIG_PASSWORD}\"}")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:.*//')

if [ "$HTTP_CODE" = "200" ]; then
    log "INFO" "Mot de passe configuration courante créé avec succès"
else
    log "ERROR" "Échec création mot de passe configuration courante (HTTP ${HTTP_CODE})"
    exit 1
fi

log "INFO" "Processus terminé avec succès"
#log "INFO" "Nettoyage en cours"
exit 0
