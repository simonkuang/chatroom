#!/bin/bash

# 聊天室应用管理脚本
# 提供便捷的服务管理命令

APP_NAME="chatroom-app"
SERVICE_NAME="chatroom-app.service"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 显示帮助信息
show_help() {
    echo "聊天室应用管理工具"
    echo
    echo "用法: $0 <命令>"
    echo
    echo "命令:"
    echo "  start       启动服务"
    echo "  stop        停止服务"
    echo "  restart     重启服务"
    echo "  reload      重新加载配置"
    echo "  status      查看服务状态"
    echo "  logs        查看实时日志"
    echo "  logs-tail   查看最近日志"
    echo "  enable      启用开机自启"
    echo "  disable     禁用开机自启"
    echo "  install     安装/重新部署应用"
    echo "  uninstall   卸载应用和服务"
    echo "  health      健康检查"
    echo "  config      查看配置"
    echo "  help        显示此帮助信息"
    echo
}

# 检查服务是否存在
check_service() {
    if ! systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        echo -e "${RED}错误:${NC} 服务 $SERVICE_NAME 未安装"
        echo "请先运行: sudo ./deploy.sh"
        exit 1
    fi
}

# 启动服务
start_service() {
    echo -e "${BLUE}启动服务...${NC}"
    sudo systemctl start "$APP_NAME"
    if systemctl is-active --quiet "$APP_NAME"; then
        echo -e "${GREEN}✓ 服务启动成功${NC}"
    else
        echo -e "${RED}✗ 服务启动失败${NC}"
        exit 1
    fi
}

# 停止服务
stop_service() {
    echo -e "${BLUE}停止服务...${NC}"
    sudo systemctl stop "$APP_NAME"
    if ! systemctl is-active --quiet "$APP_NAME"; then
        echo -e "${GREEN}✓ 服务已停止${NC}"
    else
        echo -e "${RED}✗ 服务停止失败${NC}"
        exit 1
    fi
}

# 重启服务
restart_service() {
    echo -e "${BLUE}重启服务...${NC}"
    sudo systemctl restart "$APP_NAME"
    if systemctl is-active --quiet "$APP_NAME"; then
        echo -e "${GREEN}✓ 服务重启成功${NC}"
    else
        echo -e "${RED}✗ 服务重启失败${NC}"
        exit 1
    fi
}

# 重新加载配置
reload_service() {
    echo -e "${BLUE}重新加载配置...${NC}"
    sudo systemctl reload-or-restart "$APP_NAME"
    echo -e "${GREEN}✓ 配置已重新加载${NC}"
}

# 查看服务状态
show_status() {
    echo -e "${BLUE}服务状态:${NC}"
    sudo systemctl status "$APP_NAME" --no-pager
    echo
    echo -e "${BLUE}服务信息:${NC}"
    if systemctl is-active --quiet "$APP_NAME"; then
        echo -e "状态: ${GREEN}运行中${NC}"
    else
        echo -e "状态: ${RED}已停止${NC}"
    fi
    
    if systemctl is-enabled --quiet "$APP_NAME"; then
        echo -e "开机自启: ${GREEN}已启用${NC}"
    else
        echo -e "开机自启: ${YELLOW}已禁用${NC}"
    fi
}

# 查看实时日志
show_logs() {
    echo -e "${BLUE}实时日志 (按 Ctrl+C 退出):${NC}"
    sudo journalctl -u "$APP_NAME" -f
}

# 查看最近日志
show_logs_tail() {
    echo -e "${BLUE}最近日志:${NC}"
    sudo journalctl -u "$APP_NAME" -n 50 --no-pager
}

# 启用开机自启
enable_service() {
    echo -e "${BLUE}启用开机自启...${NC}"
    sudo systemctl enable "$APP_NAME"
    echo -e "${GREEN}✓ 开机自启已启用${NC}"
}

# 禁用开机自启
disable_service() {
    echo -e "${BLUE}禁用开机自启...${NC}"
    sudo systemctl disable "$APP_NAME"
    echo -e "${GREEN}✓ 开机自启已禁用${NC}"
}

# 安装应用
install_app() {
    echo -e "${BLUE}安装/重新部署应用...${NC}"
    if [[ -f "deploy.sh" ]]; then
        sudo ./deploy.sh
    else
        echo -e "${RED}错误:${NC} 找不到 deploy.sh 脚本"
        exit 1
    fi
}

# 卸载应用
uninstall_app() {
    echo -e "${YELLOW}警告: 这将完全卸载聊天室应用${NC}"
    read -p "确定要继续吗? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}卸载应用...${NC}"
        
        # 停止并禁用服务
        sudo systemctl stop "$APP_NAME" 2>/dev/null || true
        sudo systemctl disable "$APP_NAME" 2>/dev/null || true
        
        # 删除服务文件
        sudo rm -f "/etc/systemd/system/$SERVICE_NAME"
        sudo rm -f "/etc/default/chatroom-app"
        
        # 重新加载 systemd
        sudo systemctl daemon-reload
        
        # 删除应用目录
        sudo rm -rf "/opt/chatroom-app"
        
        # 删除用户和组
        sudo userdel chatroom 2>/dev/null || true
        sudo groupdel chatroom 2>/dev/null || true
        
        echo -e "${GREEN}✓ 应用已完全卸载${NC}"
    else
        echo "取消卸载"
    fi
}

# 健康检查
health_check() {
    echo -e "${BLUE}健康检查:${NC}"
    
    # 检查服务状态
    if systemctl is-active --quiet "$APP_NAME"; then
        echo -e "服务状态: ${GREEN}✓ 运行中${NC}"
    else
        echo -e "服务状态: ${RED}✗ 已停止${NC}"
        return 1
    fi
    
    # 检查端口
    PORT=$(grep -E "^CHATROOM_PORT=" /etc/default/chatroom-app 2>/dev/null | cut -d'=' -f2 || echo "8080")
    if netstat -tuln | grep -q ":$PORT "; then
        echo -e "端口监听: ${GREEN}✓ 端口 $PORT 正在监听${NC}"
    else
        echo -e "端口监听: ${RED}✗ 端口 $PORT 未监听${NC}"
        return 1
    fi
    
    # 检查HTTP响应
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" | grep -q "200"; then
        echo -e "HTTP响应: ${GREEN}✓ 服务正常响应${NC}"
    else
        echo -e "HTTP响应: ${YELLOW}⚠ 服务可能未完全启动${NC}"
    fi
    
    echo -e "${GREEN}✓ 健康检查完成${NC}"
}

# 查看配置
show_config() {
    echo -e "${BLUE}当前配置:${NC}"
    echo
    if [[ -f "/etc/default/chatroom-app" ]]; then
        cat "/etc/default/chatroom-app"
    else
        echo "配置文件不存在: /etc/default/chatroom-app"
    fi
}

# 主函数
main() {
    case "${1:-help}" in
        start)
            check_service
            start_service
            ;;
        stop)
            check_service
            stop_service
            ;;
        restart)
            check_service
            restart_service
            ;;
        reload)
            check_service
            reload_service
            ;;
        status)
            check_service
            show_status
            ;;
        logs)
            check_service
            show_logs
            ;;
        logs-tail)
            check_service
            show_logs_tail
            ;;
        enable)
            check_service
            enable_service
            ;;
        disable)
            check_service
            disable_service
            ;;
        install)
            install_app
            ;;
        uninstall)
            uninstall_app
            ;;
        health)
            check_service
            health_check
            ;;
        config)
            show_config
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}错误:${NC} 未知命令 '$1'"
            echo
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"