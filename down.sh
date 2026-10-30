#!/usr/bin/env bash
set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}     INFRA-IDENTITY-GATEWAY YIĞINI İNDİRİLİYOR    ${NC}"
echo -e "${BLUE}==============================================${NC}"

WIPE_VOLUMES=false

# Parametre kontrolü (-v veya --volumes)
for arg in "$@"; do
    case $arg in
        -v|--volumes)
            WIPE_VOLUMES=true
            shift
            ;;
    esac
done

if [ "$WIPE_VOLUMES" = true ]; then
    echo -e "${RED}${BOLD}[DİKKAT] -v parametresi algılandı!${NC}"
    echo -e "${RED}Bu işlem veritabanları (PostgreSQL, Vaultwarden, CrowdSec) dahil TÜM VERİLERİ KALICI OLARAK SİLECEKTİR!${NC}"
    read -p "Tüm hacimleri kalıcı olarak silmek istediğinizden emin misiniz? (evet/HAYIR): " confirm
    
    if [ "$confirm" != "evet" ]; then
        echo -e "${YELLOW}[!] İşlem iptal edildi. Hacimler korunarak normal kapatma yapılıyor...${NC}"
        WIPE_VOLUMES=false
    fi
fi

if [ "$WIPE_VOLUMES" = true ]; then
    echo -e "\n${RED}[*] Konteynerler, ağlar ve VERİ HACİMLERİ siliniyor...${NC}"
    docker compose down -v --remove-orphans
    echo -e "${GREEN}[✓] Yığın ve tüm veriler tamamen sıfırlandı.${NC}"
else
    echo -e "\n${YELLOW}[*] Konteynerler ve ağlar kaldırılıyor (Veri hacimleri KORUNDU)...${NC}"
    docker compose down --remove-orphans
    echo -e "${GREEN}[✓] Konteynerler kaldırıldı. Veritabanı ve sertifika verileri güvende.${NC}"
fi