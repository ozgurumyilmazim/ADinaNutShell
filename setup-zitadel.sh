#!/usr/bin/env bash
set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}       ZITADEL ALAN ADI İLKLENDİRME BETİĞİ    ${NC}"
echo -e "${BLUE}==============================================${NC}"

if [ ! -f .env ]; then
    echo -e "${RED}[X] .env dosyası bulunamadı!${NC}"
    exit 1
fi

get_env_val() {
    grep -E "^${1}=" .env | cut -d '=' -f2- | tr -d '\r"' | sed "s/^'\(.*\)'\$/\1/"
}

PG_USER=$(get_env_val "POSTGRES_USER")
PG_DB=$(get_env_val "POSTGRES_DB")
DOMAIN_INT=$(get_env_val "DOMAIN_INT")
DOMAIN_EXT=$(get_env_val "DOMAIN_EXT")

# Ham FQDN değerlerini al ve ${DOMAIN_...} değişkenlerini çöz
ZITADEL_INT_RAW=$(get_env_val "ZITADEL_INT_FQDN")
ZITADEL_INT_RAW="${ZITADEL_INT_RAW//\$\{DOMAIN_INT\}/$DOMAIN_INT}"
ZITADEL_INT_FQDN="${ZITADEL_INT_RAW:-auth.${DOMAIN_INT}}"

ZITADEL_EXT_RAW=$(get_env_val "ZITADEL_EXT_FQDN")
ZITADEL_EXT_RAW="${ZITADEL_EXT_RAW//\$\{DOMAIN_EXT\}/$DOMAIN_EXT}"
ZITADEL_EXT_FQDN="${ZITADEL_EXT_RAW:-auth.${DOMAIN_EXT}}"

echo -e "Dahili FQDN : ${BLUE}${ZITADEL_INT_FQDN}${NC}"
echo -e "Harici FQDN : ${BLUE}${ZITADEL_EXT_FQDN}${NC}\n"

if [ "$ZITADEL_INT_FQDN" == "$ZITADEL_EXT_FQDN" ]; then
    echo -e "${GREEN}[✓] Dahili ve harici FQDN aynı (${ZITADEL_INT_FQDN}), ekleme gerekmiyor.${NC}"
    exit 0
fi

# 1. Zitadel Instance kaydının veritabanına oturmasını bekle
echo -e "${YELLOW}[1/3] Zitadel Instance ilklendirmesi bekleniyor...${NC}"
RETRIES=40
INSTANCE_ID=""

until [ -n "$INSTANCE_ID" ] || [ $RETRIES -eq 0 ]; do
    # Alan adına takılmaksızın oluşturulan ilk geçerli instance_id'yi yakalar
    INSTANCE_ID=$(docker exec -i db psql -U "${PG_USER}" -d "${PG_DB}" -tAc \
        "SELECT instance_id FROM projections.instance_domains ORDER BY creation_date ASC LIMIT 1;" 2>/dev/null || true)
    
    if [ -z "$INSTANCE_ID" ]; then
        echo -e "    -> Zitadel şema ve ilk instance bekleniyor (${RETRIES} deneme kaldı)..."
        sleep 3
        RETRIES=$((RETRIES-1))
    fi
done

if [ -z "$INSTANCE_ID" ]; then
    echo -e "${RED}[X] Zitadel instance oluşturulamadı. Logları kontrol edin:${NC}"
    docker compose logs zitadel --tail 50
    exit 1
fi

echo -e "${GREEN}[✓] Zitadel Instance bulundu: ${INSTANCE_ID}${NC}"

# 2. Harici Alan Adını Ekle
echo -e "${YELLOW}[2/3] Harici alan adı (${ZITADEL_EXT_FQDN}) Instance'a bağlanıyor...${NC}"

ALREADY_EXISTS=$(docker exec -i db psql -U "${PG_USER}" -d "${PG_DB}" -tAc \
    "SELECT 1 FROM projections.instance_domains WHERE domain = '${ZITADEL_EXT_FQDN}' AND instance_id = '${INSTANCE_ID}';" 2>/dev/null || true)

# setup-zitadel.sh içerisindeki [2/3] Harici Alan Adını Ekle bloğu:
if [ "$ALREADY_EXISTS" != "1" ]; then
    docker exec -i db psql -U "${PG_USER}" -d "${PG_DB}" -v ON_ERROR_STOP=1 <<EOSQL
    INSERT INTO projections.instance_domains (instance_id, domain, is_generated, is_primary, creation_date, change_date, sequence)
    SELECT instance_id, '${ZITADEL_EXT_FQDN}', false, false, NOW(), NOW(), sequence
    FROM projections.instance_domains
    WHERE instance_id = '${INSTANCE_ID}'
    LIMIT 1
    ON CONFLICT (instance_id, domain) DO NOTHING;
EOSQL
    echo -e "${GREEN}[✓] ${ZITADEL_EXT_FQDN} veritabanına başarıyla eklendi.${NC}"

    # 3. In-memory router önbelleğini yenile
    echo -e "${YELLOW}[3/3] Zitadel yönlendirme tablosu güncelleniyor (restart)...${NC}"
    docker compose restart zitadel >/dev/null 2>&1
    echo -e "${GREEN}[✓] Zitadel yeniden başlatıldı.${NC}"
else
    echo -e "${GREEN}[✓] ${ZITADEL_EXT_FQDN} alan adı zaten kayıtlı, işlem atlandı.${NC}"
fi

echo -e "\n${BLUE}==============================================${NC}"
echo -e "Aktif Zitadel Instance Alan Adları:"
docker exec -i db psql -U "${PG_USER}" -d "${PG_DB}" -c \
    "SELECT instance_id, domain, is_primary FROM projections.instance_domains;"
echo -e "${BLUE}==============================================${NC}"