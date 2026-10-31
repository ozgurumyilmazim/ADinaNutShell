#!/usr/bin/env bash
set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}        INFRA-IDENTITY-GATEWAY BAŞLATICI      ${NC}"
echo -e "${BLUE}==============================================${NC}"

# 1. Ortam ve Gizli Değişkenleri Hazırla
if [ ! -f ./setup-env.sh ]; then
    echo -e "${RED}[X] ./setup-env.sh betiği bulunamadı!${NC}"
    exit 1
fi
echo -e "\n${YELLOW}[ADIM 1/4] Ortam değişkenleri ve yapılandırma dosyaları kontrol ediliyor...${NC}"
chmod +x ./setup-env.sh
./setup-env.sh

# .env değişkenlerini yükle ve dashboard.yml dosyasını üret
set -a
source .env
set +a

# 2. Veritabanını ve Şemaları Ayağa Kaldır
if [ ! -f ./setup-db.sh ]; then
    echo -e "${RED}[X] ./setup-db.sh betiği bulunamadı!${NC}"
    exit 1
fi
echo -e "\n${YELLOW}[ADIM 2/4] Merkezi veritabanı ve servis kullanıcıları hazırlanıyor...${NC}"
chmod +x ./setup-db.sh
./setup-db.sh

# 3. Tüm Yığını Başlat
echo -e "\n${YELLOW}[ADIM 3/4] Servis yığını devreye alınıyor...${NC}"
docker compose up -d

# 4. Zitadel Harici Alan Adı Senkronizasyonu
echo -e "\n${YELLOW}[ADIM 4/4] Zitadel alan adı entegrasyonu tamamlanıyor...${NC}"
chmod +x ./setup-zitadel.sh
./setup-zitadel.sh

DYNAMIC_DIR="./traefik/dynamic"
TEMPLAT_DIR="./traefik/templates"

if [ -f "$TEMPLAT_DIR/dashboard.yml.tmpl" ]; then
    envsubst '${DOMAIN_EXT} ${DOMAIN_INT}' < "$TEMPLAT_DIR/dashboard.yml.tmpl" > "$DYNAMIC_DIR/dashboard.yml"
fi


echo -e "\n${GREEN}[✓] Tüm servisler ve alan adları başarıyla devreye alındı.${NC}\n"
docker compose ps


echo -e "\n${BLUE}==============================================${NC}"
echo -e "${BLUE}  Sistem aktif! Traefik logları izleniyor...  ${NC}"
echo -e "${BLUE}  (Çıkmak için Ctrl+C tuşlayabilirsiniz)      ${NC}"
echo -e "${BLUE}==============================================${NC}"
docker compose logs -f --tail=30 traefik