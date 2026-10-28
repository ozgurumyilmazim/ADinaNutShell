# Infrastructure Identity & Secure Edge Gateway

Merkezi kimlik yönetimi (Univention Corporate Server Samba 4 Active Directory & Zitadel OIDC/SAML), ters vekil (Traefik v3), uzak masaüstü ağ geçidi (Apache Guacamole), parola kasası (Vaultwarden) ve çok katmanlı tünel güvenliğini (Tailscale, Cloudflare, CrowdSec) bir araya getiren kurumsal Docker mimarisi.

## Ağ ve Port Ayrımı

* **Port 80 (`web`):** Dahili HTTP isteklerini doğrudan 443'e (HTTPS) yönlendirir.
* **Port 443 (`websecure`):** Yerel ağ (`.intra`) isteklerini karşılar; UCS Root CA sertifikasını sunar.
* **Port 444 (`webexternal`):** Harici tünel ve VPN (`.com.tr`) isteklerini karşılar; tüm istekler otomatik olarak dahili **CrowdSec LAPI Bouncer Plugin** denetiminden geçer.

---

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



## Kurulum ve Dağıtım

### 1. Depoyu Klonlayın
```bash
git clone [https://github.com/](https://github.com/)<kullanici-adiniz>/infra-identity-gateway.git
cd infra-identity-gateway




