English | [简体中文](README.zh-CN.md)

## 🌟 Project Introduction

A one-click Trojan node setup script based on sing-box, integrating camouflage sites (anti-active detection pages), Let's Encrypt with Cloudflare DNS for one-click free certificate application and automatic renewal, supporting real-time modification of sing-box and Nginx configurations with quick restart activation. Containerized through Docker, minimizing environment dependencies and simplifying deployment and maintenance.

Core concept:
- Use sing-box to provide Trojan TLS inbound on port `443`, enabling ALPN and multiplexing, falling back to Nginx-provided camouflage sites (HTTP port 80).
- Nginx additionally provides HTTPS camouflage sites on port `8443` for self-checking/demonstration purposes.
- Certificates are automatically issued and renewed by `acme.sh` through Cloudflare DNS verification, with automatic container restart after renewal for immediate certificate activation.

Related implementations can be found in the following files:
- Script: `vps-service.sh`
- Docker image: `Dockerfile`
- Orchestration: `docker-compose.yml`
- sing-box template: `templates/sing-box-config.json`
- Nginx template: `templates/default-site.conf`
- Camouflage site example: `templates/static/index.html`

## 🚀 VPS Recommendations

Looking for a reliable VPS to deploy this project? We recommend [Vultr](https://www.vultr.com/?ref=9794143) - a leading cloud infrastructure provider with global data centers and exceptional performance.

[![Vultr Logo](https://www.vultr.com/media/logo_onwhite.svg?_gl=1*6ifeeo*_gcl_au*MTcwMDQ1NjIwNS4xNzU1MDY4NDc1LjEyMTA4MjA3MTUuMTc1NTM3NTU2MS4xNzU1Mzc1NTYw*_ga*MTg5MDk1NTExNC4xNzU1MDY4NDc1*_ga_K6536FHN4D*czE3NTUzNzU0ODkkbzckZzEkdDE3NTUzNzYyNDAkajI1JGwwJGgw)](https://www.vultr.com/?ref=9794143)

**Why choose Vultr?**
- 🌍 **32 Global Data Centers** - Deploy closer to users for better performance
- 💰 **Affordable Pricing** - Cloud Compute instances starting at just $2.50/month
- 🔄 **Instant IP Rotation** - Destroy and redeploy anytime to get new IP addresses, preventing IP blocking
- 💳 **Pay-as-you-go** - No charges when instances aren't running, only pay for actual usage

**Perfect for this project:**
- Supports Ubuntu/Debian Cloud Compute instances
- Global deployment for optimal latency
- Reliable uptime and network performance
- Competitive pricing for development and production
- **Start at just $2.50/month**
- **Zero fees when stopped** - Perfect for testing and development

[Start using Vultr now →](https://www.vultr.com/?ref=9794143)

## ✨ Features

- One-click initialization of directories and default configurations, auto-generating self-signed certificates (for placeholder/debugging)
- One-click application and installation of Let's Encrypt certificates (Cloudflare DNS verification), automatic renewal and hot reload
- Trojan over TLS (sing-box) + Nginx camouflage site fallback (ports 80/8443)
- All configurations mounted as local directories, editable anytime, `restart` to take effect
- Unified script management: `init | dns-ssl | install-cert | start | stop | restart | logs`

## 📁 Directory Structure

After cloning and initialization, the following default structure will be created (customizable via environment variables):

```
config/
  nginx/
    config/             # Place Nginx site configurations (initially copied from templates/default-site.conf)
    static/             # Camouflage site static files (initially copied from templates/static/*)
    logs/               # Nginx logs (default template disables logging, can be enabled as needed)
  sing-box/
    config.json         # sing-box configuration (initially copied from templates/sing-box-config.json)
    logs/               # sing-box runtime logs (container mapping)
ssl_certs/
  cert.pem              # Certificate
  key.pem               # Private key
```

Client example configurations can be found in: `client-config-example/`.

## 🔧 Prerequisites

- **Docker and Docker Compose v2** (command is `docker compose`)
- **acme.sh** (for certificate application and automatic renewal)
- **Domain and Cloudflare DNS**: Domain must be hosted on Cloudflare, with API Token/Account/Zone information prepared
- **Port Access**: `80`, `443`, `8443`

Installation recommendations:

```bash
# Docker (varies by distribution, please refer to official documentation)
# macOS recommends Docker Desktop, Linux please refer to docs.docker.com

# acme.sh (global installation, not in container)
curl https://get.acme.sh | sh -s email=my@example.com
~/.acme.sh/acme.sh --upgrade --auto-upgrade
```

Cloudflare preparation:
- Create API Token in Cloudflare with at least DNS:Edit permissions limited to the corresponding Zone
- Obtain the following information and export as environment variables when using: `CF_Token`, `CF_Account_ID`, `CF_Zone_ID`
- Resolve the domain used for Trojan to the server's public IP, ensure the cloud icon is set to "DNS only", don't use proxy (Trojan is not HTTP protocol, CF proxy cannot transmit)

## 🚀 Quick Start

1) Clone and initialize

```bash
git clone https://github.com/yourname/singbox-vps.git
cd singbox-vps

# Optional: Customize configuration and certificate directories (default under project)
export VPS_CONFIG_DIR=$(pwd)/config
export VPS_SSL_CERTS_DIR=$(pwd)/ssl_certs

./vps-service.sh init
```

2) Apply for certificates through Cloudflare DNS

```bash
# Export Cloudflare environment variables
export CF_Token=xxxxxxxxxxxxxxxxxxxxxxxx
export CF_Account_ID=xxxxxxxxxxxxxxxxxxxxxxxx
export CF_Zone_ID=xxxxxxxxxxxxxxxxxxxxxxxx

# Apply for main domain and optional wildcard (email required for ACME account registration)
./vps-service.sh dns-ssl -d example.com -d *.example.com -e admin@example.com
```

3) Install certificates (write to ssl_certs/ and configure auto-reload)

```bash
./vps-service.sh install-cert -d example.com
```

4) Start services

```bash
./vps-service.sh start -d

# Self-check:
# - Visit https://example.com:8443 to see camouflage site
# - Trojan client connects to example.com:443 (see client configuration below)
```

## 📝 Script Usage Examples

- Initialize and build image

```bash
./vps-service.sh init
```

- Start/Stop/Restart

```bash
./vps-service.sh start -d      # Run in background
./vps-service.sh start --no-detached  # Run in foreground for log observation
./vps-service.sh stop
./vps-service.sh restart
```

- View logs

```bash
./vps-service.sh logs sing-box
./vps-service.sh logs nginx
```

- Apply/Install certificates (DNS verification)

```bash
export CF_Token=...
export CF_Account_ID=...
export CF_Zone_ID=...
./vps-service.sh dns-ssl -d example.com -e admin@example.com
./vps-service.sh install-cert -d example.com
```

Note: `install-cert` will install certificates to `ssl_certs/` and set up automatic reload commands after renewal:

```bash
docker restart service-nginx && docker restart service-sing-box
```

Therefore, after `acme.sh` automatic renewal, containers will automatically restart to make new certificates effective.

## 🔄 Common Operations

- Modify Trojan password or multi-user

Edit `users` in `config/sing-box/config.json`, then restart:

```bash
./vps-service.sh restart
```

- Modify/Customize camouflage sites

Edit static files under `config/nginx/static/` or `config/nginx/config/default-site.conf`, then:

```bash
./vps-service.sh restart
```

- Upgrade sing-box version

```bash
docker compose build service-sing-box
./vps-service.sh restart
```

- Backup and migration

Directly backup the following directories, migrate to new machine and `init` (or directly `start`):

```
config/
ssl_certs/
```

## 📱 Client Configuration Examples

Refer to examples in the repository:
- `client-config-example/sing-box-tun-client.json`
- `client-config-example/sing-box-tun-android-client.json`

Key fields:
- Server: `example.com`
- Port: `443`
- Protocol: `trojan`
- Password: Consistent with users in server `config/sing-box/config.json`
- TLS/SNI: `example.com`, ALPN recommended to include `h2` and `http/1.1`

A minimal sing-box client outbound snippet (for reference only, specific details subject to example files):

```json
{
  "outbounds": [
    {
      "type": "trojan",
      "server": "example.com",
      "server_port": 443,
      "password": "your-strong-password",
      "tls": {
        "enabled": true,
        "server_name": "example.com",
        "alpn": ["h2", "http/1.1"]
      }
    }
  ]
}
```

## ⚙️ Environment Variables

- `VPS_CONFIG_DIR`: Configuration root directory (default: `./config`)
- `VPS_SSL_CERTS_DIR`: Certificate directory (default: `./ssl_certs`)
- `CF_Token`, `CF_Account_ID`, `CF_Zone_ID`: Required for Cloudflare DNS certificate application

## 🌐 Ports and Traffic Flow

- `443/tcp`: sing-box Trojan inbound (TLS), certificates from `ssl_certs/`
- `80/tcp`: Nginx camouflage site (HTTP), also Trojan fallback target
- `8443/tcp`: Nginx camouflage site (HTTPS, for self-checking)

Note: When using Cloudflare, the hosted domain must be set to "DNS only", don't enable proxy (cloud icon turns gray).

## ❓ FAQ

- Certificate application failed?
  - Confirm `CF_Token/CF_Account_ID/CF_Zone_ID` are correctly exported
  - Wait for DNS to take effect or check Token permissions, retry `dns-ssl`
- Port 443 occupied?
  - Stop services occupying port 443 or change ports (need to adjust both `docker-compose.yml` and `config.json`)
- Cannot access port 8443?
  - Confirm security group/firewall allows port 8443, or remove mapping in `docker-compose.yml` as needed
- Must Cloudflare proxy be disabled?
  - Yes. Trojan doesn't belong to CF's HTTP/general layer 4 proxy scope, requires "DNS only"

## 📚 Command Reference

```bash
./vps-service.sh init
./vps-service.sh dns-ssl -d example.com -e admin@example.com
./vps-service.sh install-cert -d example.com
./vps-service.sh start [-d|--no-detached]
./vps-service.sh stop
./vps-service.sh restart
./vps-service.sh logs [sing-box|nginx]
```

## ⚠️ Disclaimer

This project is for learning and testing purposes only. Please use it in compliance with local laws, regulations, and service terms. Users bear all consequences resulting from the use of this project.
