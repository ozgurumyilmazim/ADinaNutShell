#!/usr/bin/env bash
set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}   INFRA-IDENTITY-GATEWAY SERVİSLERİ DURDURULUYOR   ${NC}"
echo -e "${BLUE}==============================================${NC}"

# Docker erişim kontrolü
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}[X] Docker servisi çalışmıyor veya geçerli kullanıcı yetkili değil.${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] Servisler güvenli bir şekilde kapatılıyor (Timeout: 20sn)...${NC}"
# Veritabanı WAL checkpoint ve işlem sonlandırmaları için 20 saniye tolerans tanınır
docker compose stop -t 20

echo -e "\n${GREEN}[✓] Tüm servisler durduruldu.${NC}"
echo -e "Durum özeti:\n"
docker compose ps