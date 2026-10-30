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

# FQDN ve Domain çözümlemesi
DOMAIN_INT=$(get_env_val "DOMAIN_INT")
DOMAIN_EXT=$(get_env_val "DOMAIN_EXT")

ZITADEL_INT_FQDN=$(get_env_val "ZITADEL_INT_FQDN")
ZITADEL_INT_FQDN=${ZITADEL_INT_FQDN:-auth.${DOMAIN_INT}}

ZITADEL_EXT_FQDN=$(get_env_val "ZITADEL_EXT_FQDN")
ZITADEL_EXT_FQDN=${ZITADEL_EXT_FQDN:-auth.${DOMAIN_EXT}}

if [ "$ZITADEL_INT_FQDN" == "$ZITADEL_EXT_FQDN" ]; then
    echo -e "${GREEN}[✓] Dahili ve harici FQDN aynı (${ZITADEL_INT_FQDN}), ek alan adı tanımlamaya gerek yok.${NC}"
    exit 0
fi

# 1. Zitadel DB Tablolarının Hazır Olmasını Bekle
echo -e "${YELLOW}[1/3] Zitadel veritabanı şeması ve Instance kaydı bekleniyor...${NC}"
RETRIES=30
until docker exec db psql -U "${PG_USER}" -d "${PG_DB}" -tAc \
    "SELECT 1 FROM information_schema.tables WHERE table_schema='projections' AND table_name='instance_domains';" 2>/dev/null | grep -q 1 || [ $RETRIES -eq 0 ]; do
    echo -e "    -> Projeksiyon tabloları bekleniyor (${RETRIES} deneme kaldı)..."
    sleep 3
    RETRIES=$((RETRIES-1))
done

if [ $RETRIES -eq 0 ]; then
    echo -e "${RED}[X] Zitadel henüz veritabanı şemasını kuramadı. Zitadel loglarını inceleyin:${NC}"
    docker compose logs zitadel --tail 50
    exit 1
fi

# 2. Harici Alan Adını Projeksiyon Tablosuna Eşle
echo -e "${YELLOW}[2/3] Harici alan adı (${ZITADEL_EXT_FQDN}) Zitadel Instance'ına bağlanıyor...${NC}"

ALREADY_EXISTS=$(docker exec -i db psql -U "${PG_USER}" -d "${PG_DB}" -tAc \
    "SELECT 1 FROM projections.instance_domains WHERE domain = '${ZITADEL_EXT_FQDN}';" 2>/dev/null || true)

if [ "$ALREADY_EXISTS" != "1" ]; then
    docker exec -i db psql -U "${PG_USER}" -d "${PG_DB}" <<EOSQL
    -- Dahili alan adının bağlı olduğu instance_id değerini alarak harici adresi ekle
    INSERT INTO projections.instance_domains (instance_id, domain, is_generated, is_primary, creation_date, change_date)
    SELECT instance_id, '${ZITADEL_EXT_FQDN}', false, false, NOW(), NOW()
    FROM projections.instance_domains
    WHERE domain = '${ZITADEL_INT_FQDN}'
    ON CONFLICT (instance_id, domain) DO NOTHING;
EOSQL
    echo -e "${GREEN}[✓] Harici alan adı veritabanına başarıyla kaydedildi.${NC}"
    
    # 3. Zitadel'in In-Memory Instance Router Önbelleğini Yenile
    echo -e "${YELLOW}[3/3] Zitadel yönlendirme tablosu yenileniyor...${NC}"
    docker compose restart zitadel >/dev/null 2>&1
    echo -e "${GREEN}[✓] Zitadel yeniden başlatıldı. Yeni alan adı artık aktif!${NC}"
else
    echo -e "${GREEN}[✓] ${ZITADEL_EXT_FQDN} alan adı zaten kayıtlı, işlem atlandı.${NC}"
fi

echo -e "\n${BLUE}==============================================${NC}"
echo -e "Aktif Zitadel Instance Alan Adları:"
docker exec -i db psql -U "${PG_USER}" -d "${PG_DB}" -c \
    "SELECT instance_id, domain, is_primary FROM projections.instance_domains;"
echo -e "${BLUE}==============================================${NC}"