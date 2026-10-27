# Infrastructure Identity & Secure Edge Gateway

Merkezi kimlik yönetimi (Univention Corporate Server Samba 4 Active Directory & Zitadel OIDC/SAML), ters vekil (Traefik v3), uzak masaüstü ağ geçidi (Apache Guacamole), parola kasası (Vaultwarden) ve çok katmanlı güvenlik tünellerini (Tailscale, Cloudflare, CrowdSec) bir araya getiren hepsi-bir-arada konteyner mimarisi.

## Mimarideki Modüller

* **Traefik v3:** Tüm HTTP/HTTPS ve gRPC (h2c) trafiğini yöneten ters vekil.
* **Zitadel:** OpenID Connect ve SAML 2.0 sağlayıcısı (UCS Samba 4 ile federated çalışır).
* **PostgreSQL 16:** Zitadel, Guacamole ve Vaultwarden için merkezi veritabanı.
* **Portainer CE:** Konteyner yönetim arayüzü.
* **CrowdSec:** Traefik erişim loglarını izleyen saldırı tespit ve engelleme sistemi.
* **Apache Guacamole & Guacd:** Web tabanlı RDP/VNC/SSH istemcisi.
* **Vaultwarden:** Bitwarden uyumlu kurumsal parola yöneticisi.
* **Tailscale & Cloudflare Tunnel:** Güvenli uzaktan erişim ve sıfır-port dış tünelleme.
* **OPNsense:** Harici firewall WebGUI yönlendirmesi.

---

## Kurulum Adımları (Linux)

### 1. Depoyu Klonlayın
```bash
git clone [https://github.com/](https://github.com/)<kullanici-adiniz>/infra-identity-gateway.git
cd infra-identity-gateway
