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
    echo -e "${YELLOW}Lütfen önce 'cp env.ornek .env' komutu ile dosyanızı oluşturun ve bu betiği çalıştırın.${NC}"
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

printf "%-25s : %s\n" "Dahili Alan Adı" "$(get_env_val "DOMAIN_INT")"
printf "%-25s : %s\n" "Harici Alan Adı" "$(get_env_val "DOMAIN_EXT")"
echo -e "${BLUE}----------------------------------------------${NC}"
printf "%-25s : %-30s | %s\n" "Servis" "Dış FQDN (Let's Encrypt)" "İç FQDN (UCS CA)"
printf "%-25s : %-30s | %s\n" "Zitadel" "$(get_env_val "ZITADEL_FQDN")" "$(get_env_val "ZITADEL_INT_FQDN")"
printf "%-25s : %-30s | %s\n" "OPNsense" "$(get_env_val "OPNSENSE_FQDN")" "$(get_env_val "OPNSENSE_INT_FQDN")"
printf "%-25s : %-30s | %s\n" "Guacamole" "$(get_env_val "GUACAMOLE_FQDN")" "$(get_env_val "GUACAMOLE_INT_FQDN")"
printf "%-25s : %-30s | %s\n" "Vaultwarden" "$(get_env_val "VAULTWARDEN_FQDN")" "$(get_env_val "VAULTWARDEN_INT_FQDN")"
printf "%-25s : %-30s | %s\n" "Portainer" "$(get_env_val "PORTAINER_FQDN")" "$(get_env_val "PORTAINER_INT_FQDN")"
printf "%-25s : %-30s | %s\n" "Whoami" "$(get_env_val "WHOAMI_FQDN")" "$(get_env_val "WHOAMI_INT_FQDN")"
echo -e "${BLUE}----------------------------------------------${NC}"
printf "%-25s : %s:%s\n" "OPNsense IP Hedefi" "$(get_env_val "OPNSENSE_INTERNAL_IP")" "$(get_env_val "OPNSENSE_INTERNAL_PORT")"
printf "%-25s : %s (%s)\n" "UCS Samba 4 Hedefi" "$(get_env_val "UCS_HOST")" "$(get_env_val "UCS_IP")"

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
        echo -e "${YELLOW}[!] ${desc} (${key}) boş veya tanımsız.${NC}"
        local new_val
        new_val=$(gen_random_secret "$length")
        set_env_val "$key" "$new_val"
        echo -e "${GREEN}    -> Yeni güçlü rastgele şifre atandı.${NC}"
    else
        echo -e "${GREEN}[OK]${desc} (${key}) tanımlı.${NC}"
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
    "Mevcut veritabanı volume'ü varken parola değişirse veritabanı erişilemez hale gelir!"

manage_secret "GUACAMOLE_DB_PASSWORD" "Guacamole PostgreSQL Şifresi" 24 \
    "Guacamole veritabanı parolası değiştiğinde Guacamole servisi oturum açamaz!"

manage_secret "VAULTWARDEN_DB_PASSWORD" "Vaultwarden PostgreSQL Şifresi" 24 \
    "Vaultwarden DB parolası değişirse parola kasası veritabanına bağlanamaz!"

manage_secret "ZITADEL_MASTERKEY" "Zitadel Master Key (32 Karakter)" 32 \
    "KRİTİK: Masterkey değiştiğinde Zitadel veritabanındaki kayıtları ÇÖZEMEZ. KALICI VERİ KAYBI OLUŞUR!"

manage_secret "ZITADEL_ADMIN_PASSWORD" "Zitadel İlk Kurulum Admin Şifresi" 24 \
    "Bu şifre yalnızca ilk kurulumda geçerlidir; var olan veritabanı üzerinde etkisi olmaz."

manage_secret "VAULTWARDEN_ADMIN_TOKEN" "Vaultwarden /admin Giriş Tokenı" 32 \
    "Vaultwarden yönetim paneli erişim anahtarı yenilenir."

# Zitadel Masterkey Uzunluk Denetimi
FINAL_MASTERKEY=$(get_env_val "ZITADEL_MASTERKEY")
if [ -n "$FINAL_MASTERKEY" ] && [ "${#FINAL_MASTERKEY}" -ne 32 ]; then
    echo -e "\n${RED}[!] DİKKAT: ZITADEL_MASTERKEY uzunluğu ${#FINAL_MASTERKEY} karakter.${NC}"
    echo -e "${RED}Zitadel için tam 32 karakter (256-bit) zorunludur.${NC}"
    read -r -p "32 karakterlik yeni anahtar atansın mı? (evet/HAYIR): " mk_confirm
    if [ "$mk_confirm" = "evet" ]; then
        CORRECTED_KEY=$(gen_random_secret 32)
        set_env_val "ZITADEL_MASTERKEY" "$CORRECTED_KEY"
        echo -e "${GREEN}[✓] 32 karakterlik yeni ZITADEL_MASTERKEY atandı.${NC}"
    else
        echo -e "${YELLOW}Değişiklik yapılmadı. Dosyayı manuel kontrol ediniz.${NC}"
    fi
fi

# Dosya ve Sertifika İzin Denetimleri
CERTS_DIR="traefik/certs"
ACME_FILE="${CERTS_DIR}/acme.json"
mkdir -p "$CERTS_DIR"

if [ ! -f "$ACME_FILE" ]; then
    touch "$ACME_FILE"
    chmod 600 "$ACME_FILE"
    echo -e "${GREEN}[✓]${ACME_FILE} oluşturuldu ve 'chmod 600' yetkisi verildi.${NC}"
else
    chmod 600 "$ACME_FILE"
fi

CF_TOKEN=$(get_env_val "CF_DNS_API_TOKEN")
if [ -z "$CF_TOKEN" ] \vert{}\vert{} [ "$CF_TOKEN" = "Buraya_Cloudflare_DNS_API_Token_Gelecek" ]; then
    echo -e "\n${YELLOW}[!] UYARI: CF_DNS_API_TOKEN tanımlanmamış. Let's Encrypt DNS Challenge çalışmayabilir.${NC}"
fi

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${GREEN}    TÜM KONTROLLER BAŞARIYLA TAMAMLANDI       ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "Yığını başlatmak için: ${YELLOW}docker compose up -d${NC}\n"