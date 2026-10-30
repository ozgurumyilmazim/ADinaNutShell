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
echo -e "\n${YELLOW}[ADIM 1/3] Ortam değişkenleri ve yapılandırma dosyaları kontrol ediliyor...${NC}"
chmod +x ./setup-env.sh
./setup-env.sh

# 2. Veritabanını ve Şemaları Ayağa Kaldır
if [ ! -f ./setup-db.sh ]; then
    echo -e "${RED}[X] ./setup-db.sh betiği bulunamadı!${NC}"
    exit 1
fi
echo -e "\n${YELLOW}[ADIM 2/3] Veritabanı hazır hale getiriliyor...${NC}"
chmod +x ./setup-db.sh
./setup-db.sh

# 3. Tüm Yığını Başlat
echo -e "\n${YELLOW}[ADIM 3/3] Servis yığını devreye alınıyor...${NC}"
docker compose up -d

echo -e "\n${GREEN}[✓] Tüm servisler başlatıldı. Servis durumları:${NC}\n"
docker compose ps

echo -e "\n${BLUE}==============================================${NC}"
echo -e "${BLUE}  Sistem aktif! Traefik logları izleniyor...  ${NC}"
echo -e "${BLUE}  (Çıkmak için Ctrl+C tuşlayabilirsiniz)      ${NC}"
echo -e "${BLUE}==============================================${NC}"
docker compose logs -f --tail=30 traefik