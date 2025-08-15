#!/bin/bash

set -e

ACME_SH=acme.sh

if ! command -v acme.sh &> /dev/null; then
    ACME_SH=~/.acme.sh/acme.sh
fi

source ~/.bashrc

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# Set default environment variables if not already set
export VPS_CONFIG_DIR="${VPS_CONFIG_DIR:-${SCRIPT_DIR}/config}"
export VPS_SSL_CERTS_DIR="${VPS_SSL_CERTS_DIR:-${SCRIPT_DIR}/ssl_certs}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error_exit() {
    echo -e "${RED}Error:${NC} $1"
    exit 1
}



check_env_vars() {
    for var in "$@"; do
        if [ -z "${!var}" ]; then
            error_exit "Environment variable $var is not set"
        fi
    done
}

# 初始化配置
cmd_init() {
    check_env_vars VPS_CONFIG_DIR VPS_SSL_CERTS_DIR

    echo -e "${GREEN}[1/3] Starting Docker services...${NC}"

    if [ -n "$(docker ps -q -f name=service-sing-box)" ]; then
        docker stop service-sing-box
    fi
    if [ -n "$(docker ps -q -f name=service-nginx)" ]; then
        docker rm service-nginx
    fi

    docker compose -f "$COMPOSE_FILE" build

    echo -e "${GREEN}[2/3] Initializing configuration files...${NC}"
    mkdir -p "${VPS_CONFIG_DIR}/nginx/config" \
             "${VPS_CONFIG_DIR}/nginx/static" \
             "${VPS_CONFIG_DIR}/sing-box" \
             "${VPS_CONFIG_DIR}/sing-box/logs" \
             "${VPS_SSL_CERTS_DIR}"

    # Nginx 默认配置
    if [ ! -f "${VPS_CONFIG_DIR}/nginx/config/default-site.conf" ]; then
        cp "${SCRIPT_DIR}/templates/default-site.conf" "${VPS_CONFIG_DIR}/nginx/config/"
    fi

    # Nginx 默认网页
    if [ ! -f "${VPS_CONFIG_DIR}/nginx/static/index.html" ]; then
        cp -r "${SCRIPT_DIR}/templates/static/"* "${VPS_CONFIG_DIR}/nginx/static/"
    fi

    # sing-box 默认配置
    if [ ! -f "${VPS_CONFIG_DIR}/sing-box/config.json" ]; then
        cp "${SCRIPT_DIR}/templates/sing-box-config.json" "${VPS_CONFIG_DIR}/sing-box/config.json"
    fi

     # 如果不存在证书则生成自签证书
    if [ ! -f "${VPS_SSL_CERTS_DIR}/cert.pem" ] || [ ! -f "${VPS_SSL_CERTS_DIR}/key.pem" ]; then
        echo -e "${GREEN}Generating self-signed SSL certificate...${NC}"
        openssl req -x509 -nodes -days 365 \
            -newkey rsa:2048 \
            -keyout "${VPS_SSL_CERTS_DIR}/key.pem" \
            -out "${VPS_SSL_CERTS_DIR}/cert.pem" \
            -subj "/C=US/ST=California/L=San Francisco/O=MyCompany/OU=IT/CN=example.com"
        echo -e "${GREEN}Self-signed certificate generated${NC}"
    else
        echo -e "${GREEN}Certificate already exists, skipping generation${NC}"
    fi


    echo -e "${GREEN}[3/3] Initialization completed${NC}"
}

# 申请证书
cmd_dns_ssl() {
    # 初始化变量
    local emails=()
    local domains=()
    local arg

    # 解析命令行参数
    while [[ "$#" -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            -d)
                # 收集域名（支持多个-d参数）
                if [[ -z "$2" ]]; then
                    error_exit "Parameter -d must be followed by a domain name"
                fi
                domains+=("$2")
                shift 2
                ;;
            -e)
                # 收集邮箱（支持多个-e参数，实际取最后一个）
                if [[ -z "$2" ]]; then
                    error_exit "Parameter -e must be followed by an email address"
                fi
                emails+=("$2")
                shift 2
                ;;
            *)
                # 未知参数
                error_exit "Unknown parameter: $arg, supported parameters are -d domain and -e email (required)"
                ;;
        esac
    done

    # 检查必要的环境变量
    check_env_vars CF_Token CF_Account_ID CF_Zone_ID

    # 检查是否提供了至少一个域名
    if [[ ${#domains[@]} -eq 0 ]]; then
        error_exit "Please provide at least one domain name, for example: $0 -d example.com -d *.example.com -e your@email.com"
    fi

    # 检查是否提供了邮箱（设置为必填项）
    if [[ ${#emails[@]} -eq 0 ]]; then
        error_exit "Please provide an email address through the -e parameter (required), for example: $0 -d example.com -e your@email.com"
    fi

    # 确定使用的邮箱（取最后一个-e指定的邮箱）
    local email="${emails[-1]}"

    # 仅当账户未注册时才执行注册（避免重复注册）
    if ! ${ACME_SH} --list-account >/dev/null 2>&1; then
        echo "First run, registering ACME account with email $email..."
        ${ACME_SH} --register-account -m "$email" || error_exit "Account registration failed"
    fi

    # 构建域名参数（将数组转换为 -d domain1 -d domain2 格式）
    local domain_args=()
    for domain in "${domains[@]}"; do
        domain_args+=("-d" "$domain")
    done

    # 申请证书
    echo "Starting certificate application for the following domains: ${domains[*]}"
    ${ACME_SH} --issue --dns dns_cf "${domain_args[@]}" || error_exit "Certificate application failed"

    echo "Certificate application successful!"
}

# 安装证书
cmd_install_cert() {
    check_env_vars VPS_CONFIG_DIR VPS_SSL_CERTS_DIR
    if [ "$#" -lt 1 ]; then
        error_exit "Please provide a domain name, for example: $0 install-cert -d example.com"
    fi
    ${ACME_SH} --install-cert "$@" \
        --key-file "${VPS_SSL_CERTS_DIR}/key.pem" \
        --fullchain-file "${VPS_SSL_CERTS_DIR}/cert.pem" \
        --reloadcmd "docker restart service-nginx && docker restart service-sing-box"
}

cmd_start() {
    local detached=false
    
    # 检查是否有 -d 选项
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--detached)
                detached=true
                shift
                ;;
            --no-detached)
                detached=false
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [ "$detached" = true ]; then
        docker compose -f "$COMPOSE_FILE" up -d
    else
        docker compose -f "$COMPOSE_FILE" up
    fi
}


cmd_stop() {
    docker stop service-sing-box service-nginx
}

cmd_restart() {
    echo -e "${GREEN}Restarting VPS services...${NC}"
    docker restart service-sing-box service-nginx
    echo -e "${GREEN}Services restarted successfully${NC}"
}

cmd_logs() {
    if [ "$#" -lt 1 ]; then
        error_exit "Please specify which service logs to view: sing-box or nginx"
    fi
    
    local service="$1"
    case "$service" in
        sing-box)
            docker logs --tail 100 -f service-sing-box
            ;;
        nginx)
            docker logs --tail 100 -f service-nginx
            ;;
        *)
            error_exit "Unknown service: $service. Supported services: sing-box, nginx"
            ;;
    esac
}

# 显示帮助信息
show_help() {
    cat << EOF
VPS Service Management Script

Usage: $0 <command> [options]

Commands:
    init                   Initialize VPS service with default configuration
    dns-ssl                Apply for SSL certificate using DNS challenge
    install-cert           Install SSL certificate
    start                  Start VPS services (use -d for detached mode, --no-detached for foreground)
    stop                   Stop VPS services
    restart                Restart VPS services
    logs                   View logs for a specific service (sing-box or nginx)
    --help, -h             Show this help message

Examples:
    # Initialize VPS service
    $0 init

    # Apply for SSL certificate
    $0 dns-ssl -d example.com -d *.example.com -e your@email.com

    # Install SSL certificate
    $0 install-cert -d example.com

    # Start services
    $0 start              # Start in detached mode (default)
    $0 start -d           # Start in detached mode
    $0 start --no-detached # Start in foreground mode

    # Stop services
    $0 stop

    # Restart services
    $0 restart

    # View service logs
    $0 logs sing-box
    $0 logs nginx

Environment Variables:
    VPS_CONFIG_DIR         Configuration directory (default: ./config)
    VPS_SSL_CERTS_DIR      SSL certificates directory (default: ./ssl_certs)
    CF_Token               Cloudflare API token (required for dns-ssl)
    CF_Account_ID          Cloudflare account ID (required for dns-ssl)
    CF_Zone_ID             Cloudflare zone ID (required for dns-ssl)

For more information, check the script comments or documentation.
EOF
}

# 主入口

case "$1" in
    init)
        shift
        cmd_init "$@"
        ;;
    dns-ssl)
        shift
        cmd_dns_ssl "$@"
        ;;
    install-cert)
        shift
        cmd_install_cert "$@"
        ;;
    start)
        shift
        cmd_start "$@"
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    logs)
        shift
        cmd_logs "$@"
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 --help' for usage information."
        show_help
        exit 1
        ;;
esac
