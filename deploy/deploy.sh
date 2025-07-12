#!/bin/bash

# 聊天室应用部署脚本
# 用于在生产环境中部署和配置 systemd 服务

set -e

# 配置变量
APP_NAME="chatroom-app"
APP_USER="chatroom"
APP_GROUP="chatroom"
#APP_DIR="/data/workspace/chatroom-app"
APP_DIR=$(cd $(dirname $(dirname $(realpath $0)));pwd)
SERVICE_FILE="deploy/chatroom-app.service"
SYSTEMD_DIR="/etc/systemd/system"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以 root 权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检查必要的文件
check_files() {
    log_info "检查必要文件..."
    
    if [[ ! -f "$APP_DIR/$SERVICE_FILE" ]]; then
        log_error "找不到 systemd 服务文件: $APP_DIR/$SERVICE_FILE"
        exit 1
    fi
    
    if [[ ! -f "target/release/$APP_NAME" ]]; then
        log_error "找不到编译后的二进制文件: target/release/$APP_NAME"
        log_info "请先运行: cargo build --release"
        exit 1
    fi
    
    log_info "文件检查完成"
}

# 创建用户和组
create_user() {
    log_info "创建应用用户和组..."
    
    if ! getent group "$APP_GROUP" > /dev/null 2>&1; then
        groupadd --system "$APP_GROUP"
        log_info "创建组: $APP_GROUP"
    else
        log_warn "组 $APP_GROUP 已存在"
    fi
    
    if ! getent passwd "$APP_USER" > /dev/null 2>&1; then
        useradd --system --gid "$APP_GROUP" --home-dir "$APP_DIR" \
                --no-create-home --shell /bin/false "$APP_USER"
        log_info "创建用户: $APP_USER"
    else
        log_warn "用户 $APP_USER 已存在"
    fi
}

# 创建应用目录
create_directories() {
    log_info "创建应用目录..."
    
    mkdir -p "$APP_DIR"
    mkdir -p "$APP_DIR/logs"
    mkdir -p "$APP_DIR/static"
    mkdir -p "$APP_DIR/target/release"
    
    log_info "目录创建完成"
}

# 复制文件
copy_files() {
    log_info "复制应用文件..."
    
    # 复制二进制文件
    cp "target/release/$APP_NAME" "$APP_DIR/target/release/"
    chmod +x "$APP_DIR/target/release/$APP_NAME"
    
    # 复制静态文件
    cp -r static/* "$APP_DIR/static/"
    
    # 复制配置文件（如果存在）
    if [[ -f "Cargo.toml" ]]; then
        cp "Cargo.toml" "$APP_DIR/"
    fi
    
    log_info "文件复制完成"
}

# 设置权限
set_permissions() {
    log_info "设置文件权限..."
    
    chown -R "$APP_USER:$APP_GROUP" "$APP_DIR"
    chmod -R 755 "$APP_DIR"
    chmod -R 644 "$APP_DIR/static"
    chmod +x "$APP_DIR/target/release/$APP_NAME"
    
    log_info "权限设置完成"
}

# 安装 systemd 服务
install_service() {
    log_info "安装 systemd 服务..."
    
    # 复制服务文件
    cp "$APP_DIR/$SERVICE_FILE" "$SYSTEMD_DIR/"
    chmod 644 "$SYSTEMD_DIR/$SERVICE_FILE"
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable "$APP_NAME"
    
    log_info "systemd 服务安装完成"
}

# 启动服务
start_service() {
    log_info "启动服务..."
    
    systemctl start "$APP_NAME"
    
    # 检查服务状态
    if systemctl is-active --quiet "$APP_NAME"; then
        log_info "服务启动成功"
        systemctl status "$APP_NAME" --no-pager
    else
        log_error "服务启动失败"
        systemctl status "$APP_NAME" --no-pager
        exit 1
    fi
}

# 显示服务信息
show_info() {
    log_info "部署完成！"
    echo
    echo "服务管理命令:"
    echo "  启动服务: sudo systemctl start $APP_NAME"
    echo "  停止服务: sudo systemctl stop $APP_NAME"
    echo "  重启服务: sudo systemctl restart $APP_NAME"
    echo "  查看状态: sudo systemctl status $APP_NAME"
    echo "  查看日志: sudo journalctl -u $APP_NAME -f"
    echo
    echo "应用信息:"
    echo "  应用目录: $APP_DIR"
    echo "  运行用户: $APP_USER"
    echo "  服务文件: $SYSTEMD_DIR/$SERVICE_FILE"
    echo "  访问地址: http://localhost:8080"
    echo
}

# 主函数
main() {
    log_info "开始部署聊天室应用..."
    
    check_root
    check_files
    create_user
    create_directories
    copy_files
    set_permissions
    install_service
    start_service
    show_info
    
    log_info "部署完成！"
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
