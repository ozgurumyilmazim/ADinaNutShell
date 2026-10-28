#!/usr/bin/env bash
set -e

ENV_FILE=".env"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}[X] Hata: '${ENV_FILE}' dosyası bulunamadı!${NC}"
    echo -e "${YELLOW}Lütfen önce 'cp env.ornek .env' komutu ile dosyanızı oluşturup bu betiği çalıştırın.${NC}"
    exit 1
fi

get_env_val() {
    local key="$1"
    grep -E "^${key}=" "$ENV_FILE" | cut -d '=' -f2- | tr -d '\r"' || true
}

set_env_val() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$ENV_FILE"; then
        awk -v k="$key" -v v="$value" 'BEGIN{FS=OFS="="} $1==k {$0=k"="v} {print}' "$ENV_FILE" > "${ENV_FILE}.tmp" && mv "${ENV_FILE}.tmp" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

gen_random_secret() {
    local length="${1:-24}"
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

echo -e "\n${BLUE}==============================================${NC}"
echo -e "${BLUE}        MEVCUT .env YAPILANDIRMA ÖZETİ        ${NC}"
echo -e "${BLUE}==============================================${NC}"

printf "%-25s : %s | %s\n" "ZITADEL FQDN" "$(get_env_val "ZITADEL_INT_FQDN")" "$(get_env_val "ZITADEL_EXT_FQDN")"
printf "%-25s : %s | %s\n" "PORTAINER FQDN" "$(get_env_val "PORTAINER_INT_FQDN")" "$(get_env_val "PORTAINER_EXT_FQDN")"
printf "%-25s : %s | %s\n" "GUACAMOLE FQDN" "$(get_env_val "GUACAMOLE_INT_FQDN")" "$(get_env_val "GUACAMOLE_EXT_FQDN")"
printf "%-25s : %s | %s\n" "VAULTWARDEN FQDN" "$(get_env_val "VAULTWARDEN_INT_FQDN")" "$(get_env_val "VAULTWARDEN_EXT_FQDN")"
printf "%-25s : %s | %s\n" "WHOAMI FQDN" "$(get_env_val "WHOAMI_INT_FQDN")" "$(get_env_val "WHOAMI_EXT_FQDN")"
printf "%-25s : %s:%s\n" "OPNSENSE_TARGET" "$(get_env_val "OPNSENSE_INTERNAL_IP")" "$(get_env_val "OPNSENSE_INTERNAL_PORT")"
printf "%-25s : %s (%s)\n" "UCS_AD_TARGET" "$(get_env_val "UCS_HOST")" "$(get_env_val "UCS_IP")"

echo -e "\n${BLUE}----------------------------------------------${NC}"
echo -e "${BLUE}           GİZLİ BİLGİ VE ŞİFRE DENETİMİ      ${NC}"
echo -e "${BLUE}----------------------------------------------${NC}"

manage_secret() {
    local key="$1"
    local desc="$2"
    local length="$3"
    local data_loss_warning="$4"
    local current_val
    current_val=$(get_env_val "$key")

    if [ -z "$current_val" ]; then
        echo -e "${YELLOW}[!] ${desc} (${key}) boş.${NC}"
        local new_val
        new_val=$(gen_random_secret "$length")
        set_env_val "$key" "$new_val"
        echo -e "${GREEN}    -> Yeni rastgele değer atandı.${NC}"
    else
        echo -e "${GREEN}[OK] ${desc} (${key}) tanımlı.${NC}"
        read -r -p "    -> Bu şifreyi YENİDEN üretmek ister misiniz? (e/H): " choice
        case "$choice" in
            [eE][vV][eE][tT]|[eE])
                echo -e "\n${RED}${BOLD}    [!] DİKKAT / VERİ KAYBI UYARISI:${NC}"
                echo -e "${RED}    ${data_loss_warning}${NC}"
                read -r -p "    -> Riski onaylayıp devam etmek istiyor musunuz? (evet/HAYIR): " confirm
                if [ "$confirm" = "evet" ]; then
                    local new_val
                    new_val=$(gen_random_secret "$length")
                    set_env_val "$key" "$new_val"
                    echo -e "${GREEN}    -> Değer başarıyla güncellendi.${NC}\n"
                else
                    echo -e "${YELLOW}    -> İşlem iptal edildi. Mevcut değer korundu.${NC}\n"
                fi
                ;;
            *)
                echo -e "    -> Mevcut değer korundu."
                ;;
        esac
    fi
}

manage_secret "POSTGRES_PASSWORD" "PostgreSQL (Zitadel DB) Şifresi" 24 \
    "Mevcut veritabanı volume'ü varsa PostgreSQL konteyneri şifre uyuşmazlığı nedeniyle başlatılamaz!"

manage_secret "GUACAMOLE_DB_PASSWORD" "Guacamole PostgreSQL Şifresi" 24 \
    "Guacamole veritabanı şifresi değişirse Guacamole servisi oturum açamaz!"

manage_secret "VAULTWARDEN_DB_PASSWORD" "Vaultwarden PostgreSQL Şifresi" 24 \
    "Vaultwarden DB parolası değişirse parola kasası veritabanına bağlanamaz!"

manage_secret "ZITADEL_MASTERKEY" "Zitadel Master Key (32 Karakter)" 32 \
    "KRİTİK: Masterkey değiştiğinde Zitadel veritabanındaki şifreli kayıtları ÇÖZEMEZ. KALICI VERİ KAYBI OLUŞUR!"

manage_secret "ZITADEL_ADMIN_PASSWORD" "Zitadel İlk Kurulum Admin Şifresi" 24 \
    "Yalnızca ilk kurulumda kullanılır; mevcut veritabanını etkilemez."

manage_secret "VAULTWARDEN_ADMIN_TOKEN" "Vaultwarden /admin Giriş Tokenı" 32 \
    "Vaultwarden yönetim paneli erişim anahtarı yenilenir."

manage_secret "CROWDSEC_BOUNCER_API_KEY" "CrowdSec Traefik Plugin API Key" 32 \
    "API Key değişirse Traefik plugin CrowdSec LAPI ile konuşamaz ve harici istekler 403 hatasına düşer!"


# -------------------------------------------------------------
# TRAEFIK DASHBOARD HTPASSWD OLUŞTURMA
# -------------------------------------------------------------
manage_secret "TRAEFIK_DASHBOARD_PASSWORD" "Traefik Dashboard Admin Şifresi" 24 \
    "Traefik dashboard yönetim arayüzü giriş parolası yenilenir."

DASH_USER=$(get_env_val "TRAEFIK_DASHBOARD_USER")
DASH_USER=${DASH_USER:-admin}
DASH_PASS=$(get_env_val "TRAEFIK_DASHBOARD_PASSWORD")
USERS_FILE="traefik/dynamic/usersfile"

if [ -n "$DASH_PASS" ]; then
    # OpenSSL ile MD5/Apache formatında parola hash üretimi (harici paket gerektirmez)
    HASH=$(openssl passwd -apr1 "$DASH_PASS")
    echo "${DASH_USER}:${HASH}" > "$USERS_FILE"
    chmod 600 "$USERS_FILE"
    echo -e "${GREEN}[✓] Traefik dashboard kimlik dosyası güncellendi (${USERS_FILE})${NC}"
fi


FINAL_MASTERKEY=$(get_env_val "ZITADEL_MASTERKEY")
if [ -n "$FINAL_MASTERKEY" ] && [ "${#FINAL_MASTERKEY}" -ne 32 ]; then
    echo -e "\n${RED}[!] DİKKAT: ZITADEL_MASTERKEY tam 32 karakter olmalıdır! (Şu an: ${#FINAL_MASTERKEY})${NC}"
    read -r -p "32 karakterlik yeni anahtar atansın mı? (evet/HAYIR): " mk_confirm
    if [ "$mk_confirm" = "evet" ]; then
        CORRECTED_KEY=$(gen_random_secret 32)
        set_env_val "ZITADEL_MASTERKEY" "$CORRECTED_KEY"
        echo -e "${GREEN}[✓] 32 karakterlik yeni ZITADEL_MASTERKEY atandı.${NC}"
    fi
fi

# ACME ve Dizin İzinleri
CERTS_DIR="traefik/certs"
ACME_FILE="${CERTS_DIR}/acme.json"
mkdir -p "$CERTS_DIR"
if [ ! -f "$ACME_FILE" ]; then
    touch "$ACME_FILE"
fi
chmod 600 "$ACME_FILE"

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${GREEN}    TÜM BİLEŞENLER VE .env HAZIRLANDI         ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "Yığını başlatmak için: ${YELLOW}docker compose up -d${NC}\n"