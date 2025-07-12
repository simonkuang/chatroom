#!/bin/bash

# WebSocket 连接故障排除脚本
# 用于诊断 OpenResty/Nginx WebSocket 转发问题

set -e

# 配置变量
DOMAIN="chat.tianwen.tech"
BACKEND_HOST="127.0.0.1"
BACKEND_PORT="8080"
WS_PATH="/ws"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 检查基础连接
check_basic_connectivity() {
    log_info "检查基础连接..."
    
    # 检查域名解析
    if nslookup "$DOMAIN" > /dev/null 2>&1; then
        log_info "✓ 域名解析正常: $DOMAIN"
    else
        log_error "✗ 域名解析失败: $DOMAIN"
        return 1
    fi
    
    # 检查 HTTPS 连接
    if curl -s -I "https://$DOMAIN" > /dev/null 2>&1; then
        log_info "✓ HTTPS 连接正常"
    else
        log_error "✗ HTTPS 连接失败"
        return 1
    fi
    
    # 检查后端服务
    if curl -s -I "http://$BACKEND_HOST:$BACKEND_PORT" > /dev/null 2>&1; then
        log_info "✓ 后端服务正常"
    else
        log_error "✗ 后端服务连接失败"
        return 1
    fi
}

# 检查 WebSocket 握手
check_websocket_handshake() {
    log_info "检查 WebSocket 握手..."
    
    # 使用 curl 测试 WebSocket 升级
    local response=$(curl -s -I \
        -H "Connection: Upgrade" \
        -H "Upgrade: websocket" \
        -H "Sec-WebSocket-Version: 13" \
        -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
        "https://$DOMAIN$WS_PATH" 2>&1)
    
    if echo "$response" | grep -q "101 Switching Protocols"; then
        log_info "✓ WebSocket 握手成功"
        return 0
    else
        log_error "✗ WebSocket 握手失败"
        log_debug "响应内容:"
        echo "$response"
        return 1
    fi
}

# 检查 Nginx/OpenResty 配置
check_nginx_config() {
    log_info "检查 Nginx/OpenResty 配置..."
    
    # 检查配置语法
    if command -v nginx > /dev/null 2>&1; then
        if nginx -t > /dev/null 2>&1; then
            log_info "✓ Nginx 配置语法正确"
        else
            log_error "✗ Nginx 配置语法错误"
            nginx -t
            return 1
        fi
    elif command -v openresty > /dev/null 2>&1; then
        if openresty -t > /dev/null 2>&1; then
            log_info "✓ OpenResty 配置语法正确"
        else
            log_error "✗ OpenResty 配置语法错误"
            openresty -t
            return 1
        fi
    else
        log_warn "未找到 Nginx 或 OpenResty 命令"
    fi
    
    # 检查关键配置项
    local config_files=(
        "/etc/nginx/nginx.conf"
        "/etc/nginx/sites-enabled/*"
        "/usr/local/openresty/nginx/conf/nginx.conf"
        "/etc/openresty/nginx.conf"
    )
    
    for config_file in "${config_files[@]}"; do
        if ls $config_file > /dev/null 2>&1; then
            log_debug "检查配置文件: $config_file"
            
            # 检查 WebSocket 相关配置
            if grep -r "proxy_set_header.*Upgrade" $config_file > /dev/null 2>&1; then
                log_info "✓ 找到 WebSocket Upgrade 配置"
            else
                log_warn "⚠ 未找到 WebSocket Upgrade 配置"
            fi
            
            if grep -r "proxy_set_header.*Connection.*upgrade" $config_file > /dev/null 2>&1; then
                log_info "✓ 找到 WebSocket Connection 配置"
            else
                log_warn "⚠ 未找到 WebSocket Connection 配置"
            fi
        fi
    done
}

# 检查端口和进程
check_ports_and_processes() {
    log_info "检查端口和进程..."
    
    # 检查 443 端口
    if netstat -tuln | grep -q ":443 "; then
        log_info "✓ 端口 443 正在监听"
    else
        log_error "✗ 端口 443 未监听"
    fi
    
    # 检查后端端口
    if netstat -tuln | grep -q ":$BACKEND_PORT "; then
        log_info "✓ 后端端口 $BACKEND_PORT 正在监听"
    else
        log_error "✗ 后端端口 $BACKEND_PORT 未监听"
    fi
    
    # 检查 Nginx/OpenResty 进程
    if pgrep -f "nginx\|openresty" > /dev/null; then
        log_info "✓ Nginx/OpenResty 进程运行中"
        ps aux | grep -E "nginx|openresty" | grep -v grep
    else
        log_error "✗ Nginx/OpenResty 进程未运行"
    fi
    
    # 检查聊天室应用进程
    if pgrep -f "chatroom-app" > /dev/null; then
        log_info "✓ 聊天室应用进程运行中"
    else
        log_error "✗ 聊天室应用进程未运行"
    fi
}

# 检查 SSL 证书
check_ssl_certificate() {
    log_info "检查 SSL 证书..."
    
    local cert_info=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        log_info "✓ SSL 证书有效"
        echo "$cert_info"
    else
        log_error "✗ SSL 证书检查失败"
        return 1
    fi
}

# 检查日志文件
check_logs() {
    log_info "检查相关日志..."
    
    local log_files=(
        "/var/log/nginx/error.log"
        "/var/log/nginx/chatroom_error.log"
        "/var/log/openresty/error.log"
        "/var/log/openresty/chatroom_error.log"
        "/var/log/syslog"
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            log_debug "检查日志文件: $log_file"
            local recent_errors=$(tail -n 20 "$log_file" | grep -i "error\|websocket\|upgrade" | tail -n 5)
            if [ -n "$recent_errors" ]; then
                log_warn "发现相关错误日志:"
                echo "$recent_errors"
            fi
        fi
    done
    
    # 检查聊天室应用日志
    if command -v journalctl > /dev/null 2>&1; then
        log_debug "检查聊天室应用日志"
        local app_errors=$(journalctl -u chatroom-app --since "10 minutes ago" | grep -i "error\|websocket" | tail -n 5)
        if [ -n "$app_errors" ]; then
            log_warn "聊天室应用错误日志:"
            echo "$app_errors"
        fi
    fi
}

# 实时 WebSocket 连接测试
test_websocket_connection() {
    log_info "实时 WebSocket 连接测试..."
    
    # 检查是否安装了 websocat
    if ! command -v websocat > /dev/null 2>&1; then
        log_warn "websocat 未安装，跳过实时连接测试"
        log_info "安装 websocat: cargo install websocat"
        return 0
    fi
    
    log_info "尝试连接到 wss://$DOMAIN$WS_PATH"
    
    # 使用 timeout 限制连接时间
    timeout 10s websocat "wss://$DOMAIN$WS_PATH" <<< '{"type":"ping"}' > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_info "✓ WebSocket 连接测试成功"
    else
        log_error "✗ WebSocket 连接测试失败"
        return 1
    fi
}

# 生成修复建议
generate_fix_suggestions() {
    log_info "生成修复建议..."
    
    echo
    echo "=== 常见 WebSocket 问题修复建议 ==="
    echo
    echo "1. 检查 Nginx/OpenResty 配置:"
    echo "   - 确保包含 'proxy_set_header Upgrade \$http_upgrade;'"
    echo "   - 确保包含 'proxy_set_header Connection \"upgrade\";'"
    echo "   - 设置适当的超时: 'proxy_read_timeout 3600s;'"
    echo "   - 禁用缓冲: 'proxy_buffering off;'"
    echo
    echo "2. 检查防火墙设置:"
    echo "   - 确保端口 443 和 $BACKEND_PORT 开放"
    echo "   - 检查 iptables 或 ufw 规则"
    echo
    echo "3. 检查 SSL 配置:"
    echo "   - 验证证书路径正确"
    echo "   - 确保证书未过期"
    echo "   - 检查证书链完整性"
    echo
    echo "4. 检查后端服务:"
    echo "   - 确保聊天室应用正在运行"
    echo "   - 检查应用日志是否有错误"
    echo "   - 验证应用监听正确的端口"
    echo
    echo "5. 重启服务:"
    echo "   sudo systemctl restart nginx"
    echo "   sudo systemctl restart openresty"
    echo "   sudo systemctl restart chatroom-app"
    echo
}

# 主函数
main() {
    echo "=== WebSocket 连接故障排除 ==="
    echo "域名: $DOMAIN"
    echo "后端: $BACKEND_HOST:$BACKEND_PORT"
    echo "WebSocket 路径: $WS_PATH"
    echo
    
    local failed_checks=0
    
    check_basic_connectivity || ((failed_checks++))
    echo
    
    check_websocket_handshake || ((failed_checks++))
    echo
    
    check_nginx_config || ((failed_checks++))
    echo
    
    check_ports_and_processes || ((failed_checks++))
    echo
    
    check_ssl_certificate || ((failed_checks++))
    echo
    
    check_logs
    echo
    
    test_websocket_connection || ((failed_checks++))
    echo
    
    if [ $failed_checks -eq 0 ]; then
        log_info "🎉 所有检查都通过了！WebSocket 连接应该正常工作。"
    else
        log_error "❌ 发现 $failed_checks 个问题，请查看上面的错误信息。"
        generate_fix_suggestions
    fi
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi