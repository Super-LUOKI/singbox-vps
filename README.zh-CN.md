简体中文 | [English](README.md)


## 🌟 项目简介

基于 sing-box 的一键 Trojan 节点搭建脚本，集成伪装站点（反主动探测页面）、Let's Encrypt 与 Cloudflare DNS 一键申请免费证书并自动续期，支持随时修改 sing-box 与 Nginx 配置并快速重启生效。通过 Docker 容器化，最小化环境依赖，简化部署与维护。

核心思路：
- 使用 sing-box 在 `443` 提供 Trojan TLS 入站，开启 ALPN 与多路复用，回落到 Nginx 提供的伪装站点（HTTP 80）。
- Nginx 额外在 `8443` 提供 HTTPS 伪装站点，方便自检/演示。
- 证书由 `acme.sh` 通过 Cloudflare DNS 验证自动签发与续期，续期后自动重启容器使证书即时生效。

相关实现可在以下文件中查看：
- 脚本：`vps-service.sh`
- Docker 镜像：`Dockerfile`
- 编排：`docker-compose.yml`
- sing-box 模板：`templates/sing-box-config.json`
- Nginx 模板：`templates/default-site.conf`
- 伪装站点示例：`templates/static/index.html`

## 🚀 VPS推荐

正在寻找可靠的VPS来部署这个项目？我们推荐 [Vultr](https://www.vultr.com/?ref=9794143) - 领先的云基础设施提供商，拥有全球数据中心和卓越性能。

[![Vultr Logo](https://www.vultr.com/media/logo_onwhite.svg?_gl=1*6ifeeo*_gcl_au*MTcwMDQ1NjIwNS4xNzU1MDY4NDc1LjEyMTA4MjA3MTUuMTc1NTM3NTU2MS4xNzU1Mzc1NTYw*_ga*MTg5MDk1NTExNC4xNzU1MDY4NDc1*_ga_K6536FHN4D*czE3NTUzNzU0ODkkbzckZzEkdDE3NTUzNzYyNDAkajI1JGwwJGgw)](https://www.vultr.com/?ref=9794143)

**为什么选择Vultr？**
- 🌍 **32个全球数据中心** - 部署更靠近用户，获得更好性能
- 💰 **实惠价格** - Cloud Compute实例最低仅需$2.50/月
- 🔄 **即时IP轮换** - 随时销毁并重新部署以获得新IP地址，防止IP被封
- 💳 **按量付费** - 实例未运行时不会产生费用，只为实际使用付费

**完美适合本项目：**
- 支持Ubuntu/Debian的Cloud Compute实例
- 全球部署，获得最佳延迟
- 可靠的正常运行时间和网络性能
- 开发和生产的竞争性定价
- **最低$2.50/月**即可开始
- **停止时零费用** - 完美适合测试和开发

[立即开始使用Vultr →](https://www.vultr.com/?ref=9794143)

## ✨ 功能特性

- 一键初始化目录与默认配置，自动生成自签证书（用于占位/调试）
- 一键申请与安装 Let's Encrypt 证书（Cloudflare DNS 验证），自动续期并热重载
- Trojan over TLS（sing-box）+ Nginx 伪装站点回落（80/8443）
- 所有配置均挂载为本地目录，随时编辑，`restart` 即可生效
- 统一脚本管理：`init | dns-ssl | install-cert | start | stop | restart | logs`

## 📁 目录结构

克隆后初始化会创建如下默认结构（可通过环境变量自定义）：

```
config/
  nginx/
    config/             # 放置 Nginx 站点配置（初始复制自 templates/default-site.conf）
    static/             # 伪装站点静态文件（初始复制自 templates/static/*）
    logs/               # Nginx 日志（默认模板关闭日志，可按需开启）
  sing-box/
    config.json         # sing-box 配置（初始复制自 templates/sing-box-config.json）
    logs/               # sing-box 运行日志（容器内映射）
ssl_certs/
  cert.pem              # 证书
  key.pem               # 私钥
```

客户端示例配置见：`client-config-example/`。

## 🔧 使用的先决条件

- **Docker 与 Docker Compose v2**（命令为 `docker compose`）
- **acme.sh**（用于申请与自动续期证书）
- **域名与 Cloudflare DNS**：需将域名托管到 Cloudflare，并准备 API Token/Account/Zone 信息
- **放行端口**：`80`、`443`、`8443`

安装建议：

```bash
# Docker（不同发行版略有差异，请参考官方文档）
# macOS 建议安装 Docker Desktop，Linux 请参考 docs.docker.com

# acme.sh（全局安装，非容器内）
curl https://get.acme.sh | sh -s email=my@example.com
~/.acme.sh/acme.sh --upgrade --auto-upgrade
```

Cloudflare 准备：
- 在 Cloudflare 创建 API Token，至少授予 DNS:Edit 权限并限定到对应 Zone
- 获取以下信息并在使用时导出为环境变量：`CF_Token`、`CF_Account_ID`、`CF_Zone_ID`
- 将用于 Trojan 的域名解析到服务器公网 IP，务必将小云朵设为「DNS only（仅 DNS）」，不要使用代理（Trojan 非 HTTP 协议，CF 代理无法透传）

## 🚀 Quick Start

1) 克隆与初始化

```bash
git clone https://github.com/yourname/singbox-vps.git
cd singbox-vps

# 可选：自定义配置与证书目录（默认在项目下）
export VPS_CONFIG_DIR=$(pwd)/config
export VPS_SSL_CERTS_DIR=$(pwd)/ssl_certs

./vps-service.sh init
```

2) 通过 Cloudflare DNS 申请证书

```bash
# 导出 Cloudflare 环境变量
export CF_Token=xxxxxxxxxxxxxxxxxxxxxxxx
export CF_Account_ID=xxxxxxxxxxxxxxxxxxxxxxxx
export CF_Zone_ID=xxxxxxxxxxxxxxxxxxxxxxxx

# 申请主域与可选通配符（邮箱必填，用于注册 ACME 账户）
./vps-service.sh dns-ssl -d example.com -d *.example.com -e admin@example.com
```

3) 安装证书（写入到 ssl_certs/ 并配置自动重载）

```bash
./vps-service.sh install-cert -d example.com
```

4) 启动服务

```bash
./vps-service.sh start -d

# 自检：
# - 访问 https://example.com:8443 可看到伪装站点
# - Trojan 客户端连到 example.com:443（见下文客户端配置）
```

## 📝 脚本使用示例讲解

- 初始化与构建镜像

```bash
./vps-service.sh init
```

- 启动/停止/重启

```bash
./vps-service.sh start -d      # 后台运行
./vps-service.sh start --no-detached  # 前台运行便于观察日志
./vps-service.sh stop
./vps-service.sh restart
```

- 查看日志

```bash
./vps-service.sh logs sing-box
./vps-service.sh logs nginx
```

- 申请/安装证书（DNS 验证）

```bash
export CF_Token=...
export CF_Account_ID=...
export CF_Zone_ID=...
./vps-service.sh dns-ssl -d example.com -e admin@example.com
./vps-service.sh install-cert -d example.com
```

说明：`install-cert` 会把证书安装到 `ssl_certs/`，并设置续期后的自动重载命令：

```bash
docker restart service-nginx && docker restart service-sing-box
```

因此 `acme.sh` 自动续期后将自动重启容器使新证书生效。

## 🔄 常用运维场景

- 修改 Trojan 密码或多用户

编辑 `config/sing-box/config.json` 中的 `users`，然后重启：

```bash
./vps-service.sh restart
```

- 修改/自定义伪装站点

编辑 `config/nginx/static/` 下的静态文件或 `config/nginx/config/default-site.conf`，然后：

```bash
./vps-service.sh restart
```

- 升级 sing-box 版本

```bash
docker compose build service-sing-box
./vps-service.sh restart
```

- 备份与迁移

直接备份以下目录，迁移到新机器后 `init`（或直接 `start`）即可：

```
config/
ssl_certs/
```

## 📱 客户端配置示例

参考仓库中的示例：
- `client-config-example/sing-box-tun-client.json`
- `client-config-example/sing-box-tun-android-client.json`

关键字段：
- 服务器：`example.com`
- 端口：`443`
- 协议：`trojan`
- 密码：与服务端 `config/sing-box/config.json` 中用户一致
- TLS/SNI：`example.com`，ALPN 建议包含 `h2` 与 `http/1.1`

一个最小化的 sing-box 客户端出站片段（仅供参考，具体以示例文件为准）：

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

## ⚙️ 环境变量说明

- `VPS_CONFIG_DIR`：配置根目录（默认：`./config`）
- `VPS_SSL_CERTS_DIR`：证书目录（默认：`./ssl_certs`）
- `CF_Token`、`CF_Account_ID`、`CF_Zone_ID`：Cloudflare DNS 申请证书所需

## 🌐 端口与流量走向说明

- `443/tcp`：sing-box Trojan 入站（TLS），证书来自 `ssl_certs/`
- `80/tcp`：Nginx 伪装站点（HTTP），也是 Trojan 回落目标
- `8443/tcp`：Nginx 伪装站点（HTTPS，自检用）

注意：使用 Cloudflare 时必须将托管域名设为「仅 DNS」，不要启用代理（小云朵变灰）。

## ❓ 常见问题（FAQ）

- 证书申请失败？
  - 确认已正确导出 `CF_Token/CF_Account_ID/CF_Zone_ID`
  - 等待 DNS 生效或检查 Token 权限，重试 `dns-ssl`
- 443 端口被占用？
  - 停止占用 443 的服务或更换端口（需同时调整 `docker-compose.yml` 与 `config.json`）
- 访问 8443 无法打开？
  - 确认安全组/防火墙已放行 8443，或按需在 `docker-compose.yml` 移除该映射
- Cloudflare 必须关闭代理吗？
  - 是。Trojan 不属于 CF 的 HTTP/通用四层代理范围，需「仅 DNS」

## 📚 命令参考

```bash
./vps-service.sh init
./vps-service.sh dns-ssl -d example.com -e admin@example.com
./vps-service.sh install-cert -d example.com
./vps-service.sh start [-d|--no-detached]
./vps-service.sh stop
./vps-service.sh restart
./vps-service.sh logs [sing-box|nginx]
```

## ⚠️ 免责声明

本项目仅用于学习与测试，请在遵守当地法律法规与服务条款的前提下使用。由使用本项目造成的一切后果由使用者自行承担。


