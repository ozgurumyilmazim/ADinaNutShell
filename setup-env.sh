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
printf "%-25s : %s | %s\n" "PGADMIN FQDN" "$(get_env_val "PGADMIN_INT_FQDN")" "$(get_env_val "PGADMIN_EXT_FQDN")"
printf "%-25s : %s\n" "TRUSTED SUBNET (CIDR)" "$(get_env_val "TRUSTED_SUBNET") (127.0.0.1/32 ile)"

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

# -------------------------------------------------------------
# AĞ YAPILANDIRMASI KONTROLÜ
# -------------------------------------------------------------
current_subnet=$(get_env_val "TRUSTED_SUBNET")
if [ -z "$current_subnet" ]; then
    echo -e "${YELLOW}[!] TRUSTED_SUBNET tanımlı değil, varsayılan (172.16.1.0/24) atanıyor...${NC}"
    set_env_val "TRUSTED_SUBNET" "172.16.1.0/24"
fi

# -------------------------------------------------------------
# CROWDSEC TRAEFIK LOCAL PLUGIN KONTROLÜ VE İNDİRİLMESİ
# -------------------------------------------------------------
PLUGIN_DIR="traefik/plugins-local/src/github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin"

if [ ! -f "${PLUGIN_DIR}/.traefik.yml" ]; then
    echo -e "${YELLOW}[!] CrowdSec Traefik Bouncer eklentisi eksik, indiriliyor...${NC}"
    mkdir -p "${PLUGIN_DIR}"
    
    if curl -fsSL https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/archive/refs/tags/v1.4.1.tar.gz | \
       tar -xz --strip-components=1 -C "${PLUGIN_DIR}"; then
        chmod -R 755 traefik/plugins-local
        echo -e "${GREEN}[✓] CrowdSec Traefik eklentisi başarıyla kuruldu.${NC}"
    else
        echo -e "${RED}[X] Eklenti indirilemedi! İnternet bağlantınızı kontrol edin.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}[✓] CrowdSec Traefik eklentisi mevcut.${NC}"
fi

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

manage_secret "PGADMIN_DEFAULT_PASSWORD" "pgAdmin 4 Giriş Parolası" 24 \
    "pgAdmin yönetici parolası yenilenir."

manage_secret "CROWDSEC_DB_PASSWORD" "CrowdSec PostgreSQL Şifresi" 24 \
    "CrowdSec veritabanı parolası değişirse CrowdSec LAPI PostgreSQL'e erişemez!"


# -------------------------------------------------------------
# VAULTWARDEN ARGON2 ADMIN TOKEN ÜRETİMİ (TTY BAĞIMSIZ)
# -------------------------------------------------------------
current_vw_token=$(get_env_val "VAULTWARDEN_ADMIN_TOKEN")

if [ -z "$current_vw_token" ] || [[ "$current_vw_token" != *"argon2"* ]]; then
    echo -e "${YELLOW}[!] Vaultwarden Admin Token için Argon2 PHC hash üretiliyor...${NC}"
    
    # 24 karakterlik rastgele şifre ve 16 karakterlik rastgele salt
    RAW_VW_PASS=$(gen_random_secret 24)
    SALT=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)

    # Alpine argon2 aracı TTY aramaz; stdin üzerinden temiz hash üretir
    HASHED_TOKEN=$(docker run --rm -i alpine:latest sh -c \
        "apk add --no-cache -q argon2 >/dev/null && echo -n '$RAW_VW_PASS' | argon2 '$SALT' -id -e -t 3 -m 16 -p 4 -l 32" | tr -d '\r\n')

    if [[ "$HASHED_TOKEN" == *"\$argon2id\$"* ]]; then
        # Docker Compose için $ -> $$ kaçışı yapılır
        ESCAPED_TOKEN="${HASHED_TOKEN//\$/\$\$}"
        set_env_val "VAULTWARDEN_ADMIN_TOKEN" "'$ESCAPED_TOKEN'"
        echo -e "${GREEN}[✓] Vaultwarden Argon2 Admin Token başarıyla oluşturuldu.${NC}"
        echo -e "${YELLOW}    -> /admin Giriş Parolanız: ${BOLD}${RAW_VW_PASS}${NC}"
    else
        echo -e "${RED}[X] Hash üretilemedi! Lütfen manuel olarak tanımlayın.${NC}"
    fi
fi

# -------------------------------------------------------------
# PGADMIN OTOMATIK SUNUCU TANIMLARI (servers.json)
# -------------------------------------------------------------
mkdir -p crowdsec pgadmin

# Değişkenleri oku
PG_USER=$(get_env_val "POSTGRES_USER")
PG_PASS=$(get_env_val "POSTGRES_PASSWORD")
PG_DB=$(get_env_val "POSTGRES_DB")

GUAC_USER=$(get_env_val "GUACAMOLE_DB_USER")
GUAC_PASS=$(get_env_val "GUACAMOLE_DB_PASSWORD")
GUAC_DB=$(get_env_val "GUACAMOLE_DB_NAME")

VAULT_USER=$(get_env_val "VAULTWARDEN_DB_USER")
VAULT_PASS=$(get_env_val "VAULTWARDEN_DB_PASSWORD")
VAULT_DB=$(get_env_val "VAULTWARDEN_DB_NAME")

CROWDSEC_USER=$(get_env_val "CROWDSEC_DB_USER")
CROWDSEC_USER=${CROWDSEC_USER:-crowdsec}
CROWDSEC_PASS=$(get_env_val "CROWDSEC_DB_PASSWORD")
CROWDSEC_DB=$(get_env_val "CROWDSEC_DB_NAME")
CROWDSEC_DB=${CROWDSEC_DB:-crowdsec_db}

# pgAdmin servers.json dosyası
cat <<EOF > pgadmin/servers.json
{
  "Servers": {
    "1": {
      "Name": "PostgreSQL (Merkezi Kümeler - Tum DB'ler)",
      "Group": "Sirket Altyapi",
      "Port": 5432,
      "Username": "${PG_USER}",
      "Host": "db",
      "SSLMode": "prefer",
      "MaintenanceDB": "${PG_DB}",
      "PassFile": "/pgadmin4/pgpass"
    },
    "2": {
      "Name": "Guacamole Veritabani",
      "Group": "Servis Veritabanlari",
      "Port": 5432,
      "Username": "${GUAC_USER}",
      "Host": "db",
      "SSLMode": "prefer",
      "MaintenanceDB": "${GUAC_DB}",
      "PassFile": "/pgadmin4/pgpass"
    },
    "3": {
      "Name": "Vaultwarden Veritabani",
      "Group": "Servis Veritabanlari",
      "Port": 5432,
      "Username": "${VAULT_USER}",
      "Host": "db",
      "SSLMode": "prefer",
      "MaintenanceDB": "${VAULT_DB}",
      "PassFile": "/pgadmin4/pgpass"
    },
    "4": {
      "Name": "CrowdSec Veritabani",
      "Group": "Servis Veritabanlari",
      "Port": 5432,
      "Username": "${CROWDSEC_USER}",
      "Host": "db",
      "SSLMode": "prefer",
      "MaintenanceDB": "${CROWDSEC_DB}",
      "PassFile": "/pgadmin4/pgpass"
    }
  }
}
EOF

chmod 644 pgadmin/servers.json
echo -e "${GREEN}[✓] pgAdmin sunucu listesi 4 veritabanıyla güncellendi (pgadmin/servers.json).${NC}"


# pgpass dosyasını oluştur (hostname:port:database:username:password)
PGPASS_FILE="pgadmin/pgpass"
rm -f "$PGPASS_FILE" 2>/dev/null || sudo rm -f "$PGPASS_FILE" 2>/dev/null || true
cat <<EOF > "$PGPASS_FILE"
db:5432:*:${PG_USER}:${PG_PASS}
db:5432:*:${GUAC_USER}:${GUAC_PASS}
db:5432:*:${VAULT_USER}:${VAULT_PASS}
db:5432:*:${CROWDSEC_USER}:${CROWDSEC_PASS}
EOF

# libpq zorunlu izinleri (0600 ve UID 5050)
chmod 600 "$PGPASS_FILE"
chown 5050:5050 "$PGPASS_FILE" 2>/dev/null || \
sudo chown 5050:5050 "$PGPASS_FILE" 2>/dev/null || \
docker run --rm -v "$(pwd)/pgadmin:/target" alpine chown 5050:5050 /target/pgpass 2>/dev/null || true
chmod 644 pgadmin/servers.json

echo -e "${GREEN}[✓] pgAdmin pgpass ve CrowdSec PostgreSQL ayarları hazırlandı.${NC}"

# -------------------------------------------------------------
# PGADMIN CONFIG_LOCAL (DESKTOP MODE)
# -------------------------------------------------------------
# 5050 sahipliği gerektirmez; 644 izni pgAdmin'in okuması için yeterlidir
rm -f pgadmin/config_local.py
# pgAdmin Desktop Mode ve Master Password Kapatma Yapılandırması
cat <<'EOF' > pgadmin/config_local.py
SERVER_MODE = False
MASTER_PASSWORD_REQUIRED = False
EOF

chmod 644 pgadmin/config_local.py
chown 5050:5050 pgadmin/config_local.py 2>/dev/null || true

# CrowdSec config.yaml.local oluşturma
cat <<'EOF' > crowdsec/config.yaml.local
db_config:
  log_level: info
  type: postgresql
  user: ${CROWDSEC_DB_USER}
  password: ${CROWDSEC_DB_PASSWORD}
  db_name: ${CROWDSEC_DB_NAME}
  host: db
  port: 5432
  sslmode: disable
EOF




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
