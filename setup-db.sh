#!/usr/bin/env bash
set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}      POSTGRESQL BAŞLATMA VE VERİTABANI SAĞLAMA${NC}"
echo -e "${BLUE}==============================================${NC}"

# .env kontrolü
if [ ! -f .env ]; then
    echo -e "${RED}[X] .env dosyası bulunamadı! Önce ./setup-env.sh betiğini çalıştırın.${NC}"
    exit 1
fi

get_env_val() {
    grep -E "^${1}=" .env | cut -d '=' -f2- | tr -d '\r"' | sed "s/^'\(.*\)'\$/\1/"
}

PG_USER=$(get_env_val "POSTGRES_USER")
PG_PASS=$(get_env_val "POSTGRES_PASSWORD")
PG_DB=$(get_env_val "POSTGRES_DB")

GUAC_USER=$(get_env_val "GUACAMOLE_DB_USER")
GUAC_PASS=$(get_env_val "GUACAMOLE_DB_PASSWORD")
GUAC_DB=$(get_env_val "GUACAMOLE_DB_NAME")

VAULT_USER=$(get_env_val "VAULTWARDEN_DB_USER")
VAULT_PASS=$(get_env_val "VAULTWARDEN_DB_PASSWORD")
VAULT_DB=$(get_env_val "VAULTWARDEN_DB_NAME")

CROWD_USER=$(get_env_val "CROWDSEC_DB_USER")
CROWD_USER=${CROWD_USER:-crowdsec}
CROWD_PASS=$(get_env_val "CROWDSEC_DB_PASSWORD")
CROWD_DB=$(get_env_val "CROWDSEC_DB_NAME")
CROWD_DB=${CROWD_DB:-crowdsec_db}

# 1. Yalnızca Veritabanı Servisini Başlat
echo -e "${YELLOW}[1/4] Merkezi veritabanı konteyneri (db) başlatılıyor...${NC}"
docker compose up -d db

# 2. PostgreSQL Hazır Olana Kadar Bekle (pg_isready loop)
echo -e "${YELLOW}[2/4] Veritabanı motorunun tamamen hazır olması bekleniyor...${NC}"
RETRIES=30
until docker exec db pg_isready -U "${PG_USER}" -d "${PG_DB}" -q >/dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
    echo -e "    -> Veritabanı soketi bekleniyor (${RETRIES} deneme kaldı)..."
    sleep 2
    RETRIES=$((RETRIES-1))
done

if [ $RETRIES -eq 0 ]; then
    echo -e "${RED}[X] PostgreSQL zaman aşımına uğradı ve başlatılamadı! Logları inceleyin:${NC}"
    docker compose logs db --tail 50
    exit 1
fi

echo -e "${GREEN}[✓] PostgreSQL soketi ve ana veritabanı aktif.${NC}"

# 3. Kullanıcıları, Veritabanlarını ve Yetkileri Senkronize Et
echo -e "${YELLOW}[3/4] Servis veritabanları ve kullanıcı yetkileri doğrulanıyor...${NC}"
docker exec -i db psql -U "${PG_USER}" -d "${PG_DB}" <<EOSQL
-- Guacamole
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${GUAC_USER}') THEN
    CREATE USER ${GUAC_USER} WITH PASSWORD '${GUAC_PASS}';
  ELSE
    ALTER USER ${GUAC_USER} WITH PASSWORD '${GUAC_PASS}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${GUAC_DB} OWNER ${GUAC_USER}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${GUAC_DB}')\gexec
GRANT ALL PRIVILEGES ON DATABASE ${GUAC_DB} TO ${GUAC_USER};
ALTER DATABASE ${GUAC_DB} OWNER TO ${GUAC_USER};

-- Vaultwarden
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${VAULT_USER}') THEN
    CREATE USER ${VAULT_USER} WITH PASSWORD '${VAULT_PASS}';
  ELSE
    ALTER USER ${VAULT_USER} WITH PASSWORD '${VAULT_PASS}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${VAULT_DB} OWNER ${VAULT_USER}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${VAULT_DB}')\gexec
GRANT ALL PRIVILEGES ON DATABASE ${VAULT_DB} TO ${VAULT_USER};
ALTER DATABASE ${VAULT_DB} OWNER TO ${VAULT_USER};

-- CrowdSec
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${CROWD_USER}') THEN
    CREATE USER ${CROWD_USER} WITH PASSWORD '${CROWD_PASS}';
  ELSE
    ALTER USER ${CROWD_USER} WITH PASSWORD '${CROWD_PASS}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${CROWD_DB} OWNER ${CROWD_USER}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${CROWD_DB}')\gexec
GRANT ALL PRIVILEGES ON DATABASE ${CROWD_DB} TO ${CROWD_USER};
ALTER DATABASE ${CROWD_DB} OWNER TO ${CROWD_USER};
EOSQL

echo -e "${GREEN}[✓] Tüm kullanıcılar ve veritabanları tanımlandı.${NC}"

# 4. Guacamole Şemasını Kontrol Et ve Gerekirse Yükle
echo -e "${YELLOW}[4/4] Guacamole veritabanı şeması kontrol ediliyor...${NC}"
GUAC_TABLES=$(docker exec -i db psql -U "${PG_USER}" -d "${GUAC_DB}" -tAc "SELECT to_regclass('public.guacamole_user');" 2>/dev/null || true)

if [ "$GUAC_TABLES" != "guacamole_user" ]; then
    echo -e "    -> Guacamole şeması bulunamadı. Şema aktarımı başlatılıyor..."
    docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql | \
        docker exec -i db psql -U "${GUAC_USER}" -d "${GUAC_DB}" >/dev/null 2>&1
    echo -e "${GREEN}[✓] Guacamole tabloları başarıyla oluşturuldu.${NC}"
else
    echo -e "${GREEN}[✓] Guacamole tabloları zaten mevcut, atlanıyor.${NC}"
fi

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}      VERİTABANI KATMANI KULLANIMA HAZIR     ${NC}"
echo -e "${GREEN}==============================================${NC}"