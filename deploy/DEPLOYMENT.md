# 聊天室应用部署指南

本文档介绍如何在生产环境中部署和管理聊天室应用。

## 📋 系统要求

- **操作系统**: Linux (支持 systemd)
- **架构**: x86_64 或 ARM64
- **内存**: 最少 512MB RAM
- **磁盘**: 最少 100MB 可用空间
- **网络**: 开放 8080 端口 (可配置)

## 🚀 快速部署

### 1. 编译应用

```bash
# 编译 release 版本
cargo build --release
```

### 2. 一键部署

```bash
# 运行部署脚本 (需要 root 权限)
sudo ./deploy.sh
```

部署脚本会自动完成以下操作：
- 创建专用用户和组 (`chatroom`)
- 创建应用目录 (`/opt/chatroom-app`)
- 复制应用文件和静态资源
- 安装 systemd 服务
- 启动服务

### 3. 验证部署

```bash
# 检查服务状态
./chatroom-ctl.sh status

# 健康检查
./chatroom-ctl.sh health

# 访问应用
curl http://localhost:8080
```

## 📁 文件结构

部署后的文件结构：

```
/opt/chatroom-app/
├── target/release/
│   └── chatroom-app           # 应用二进制文件
├── static/                    # 静态资源
│   ├── index.html
│   ├── style.css
│   └── app.js
├── logs/                      # 日志目录
└── Cargo.toml                 # 配置文件

/etc/systemd/system/
└── chatroom-app.service       # systemd 服务文件

/etc/default/
└── chatroom-app               # 环境配置文件
```

## ⚙️ 配置管理

### 环境配置

编辑配置文件：
```bash
sudo nano /etc/default/chatroom-app
```

主要配置项：
```bash
# 服务器配置
CHATROOM_HOST=0.0.0.0          # 监听地址
CHATROOM_PORT=8080             # 监听端口

# 日志级别
RUST_LOG=info                  # debug, info, warn, error

# 性能配置
WORKER_THREADS=4               # 工作线程数
MAX_CONNECTIONS=1000           # 最大连接数
```

### 应用配置后重启

```bash
# 重新加载配置并重启
./chatroom-ctl.sh reload
```

## 🛠 服务管理

### 使用管理脚本

```bash
# 查看所有可用命令
./chatroom-ctl.sh help

# 常用命令
./chatroom-ctl.sh start        # 启动服务
./chatroom-ctl.sh stop         # 停止服务
./chatroom-ctl.sh restart      # 重启服务
./chatroom-ctl.sh status       # 查看状态
./chatroom-ctl.sh logs         # 查看实时日志
./chatroom-ctl.sh health       # 健康检查
```

### 使用 systemctl

```bash
# 启动服务
sudo systemctl start chatroom-app

# 停止服务
sudo systemctl stop chatroom-app

# 重启服务
sudo systemctl restart chatroom-app

# 查看状态
sudo systemctl status chatroom-app

# 启用开机自启
sudo systemctl enable chatroom-app

# 禁用开机自启
sudo systemctl disable chatroom-app
```

## 📊 监控和日志

### 查看日志

```bash
# 实时日志
sudo journalctl -u chatroom-app -f

# 最近日志
sudo journalctl -u chatroom-app -n 100

# 按时间过滤
sudo journalctl -u chatroom-app --since "1 hour ago"

# 按级别过滤
sudo journalctl -u chatroom-app -p err
```

### 日志轮转

systemd 会自动管理日志轮转，默认配置：
- 最大日志大小: 100MB
- 保留时间: 30天
- 压缩旧日志

### 性能监控

```bash
# 查看进程信息
ps aux | grep chatroom-app

# 查看资源使用
top -p $(pgrep chatroom-app)

# 查看网络连接
ss -tulpn | grep :8080

# 查看文件描述符
lsof -p $(pgrep chatroom-app)
```

## 🔒 安全配置

### 防火墙设置

```bash
# UFW 防火墙
sudo ufw allow 8080/tcp

# iptables
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
```

### SSL/TLS 配置

如需 HTTPS 支持，可以使用反向代理：

#### Nginx 配置示例

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## 🔄 更新和维护

### 应用更新

```bash
# 1. 编译新版本
cargo build --release

# 2. 停止服务
./chatroom-ctl.sh stop

# 3. 备份当前版本
sudo cp /opt/chatroom-app/target/release/chatroom-app \
        /opt/chatroom-app/target/release/chatroom-app.backup

# 4. 复制新版本
sudo cp target/release/chatroom-app /opt/chatroom-app/target/release/

# 5. 设置权限
sudo chown chatroom:chatroom /opt/chatroom-app/target/release/chatroom-app
sudo chmod +x /opt/chatroom-app/target/release/chatroom-app

# 6. 启动服务
./chatroom-ctl.sh start

# 7. 验证更新
./chatroom-ctl.sh health
```

### 自动化更新脚本

```bash
#!/bin/bash
# update.sh - 自动更新脚本

set -e

echo "开始更新聊天室应用..."

# 编译新版本
cargo build --release

# 停止服务
./chatroom-ctl.sh stop

# 备份和更新
sudo cp /opt/chatroom-app/target/release/chatroom-app \
        /opt/chatroom-app/target/release/chatroom-app.backup.$(date +%Y%m%d_%H%M%S)

sudo cp target/release/chatroom-app /opt/chatroom-app/target/release/
sudo chown chatroom:chatroom /opt/chatroom-app/target/release/chatroom-app
sudo chmod +x /opt/chatroom-app/target/release/chatroom-app

# 启动服务
./chatroom-ctl.sh start

# 验证
./chatroom-ctl.sh health

echo "更新完成！"
```

## 🗑 卸载

### 完全卸载

```bash
# 使用管理脚本卸载
./chatroom-ctl.sh uninstall
```

### 手动卸载

```bash
# 停止并禁用服务
sudo systemctl stop chatroom-app
sudo systemctl disable chatroom-app

# 删除服务文件
sudo rm -f /etc/systemd/system/chatroom-app.service
sudo rm -f /etc/default/chatroom-app

# 重新加载 systemd
sudo systemctl daemon-reload

# 删除应用目录
sudo rm -rf /opt/chatroom-app

# 删除用户和组
sudo userdel chatroom
sudo groupdel chatroom
```

## 🆘 故障排除

### 常见问题

#### 1. 服务启动失败

```bash
# 查看详细错误信息
sudo journalctl -u chatroom-app -n 50

# 检查配置文件
./chatroom-ctl.sh config

# 检查文件权限
ls -la /opt/chatroom-app/target/release/chatroom-app
```

#### 2. 端口被占用

```bash
# 查看端口占用
sudo netstat -tulpn | grep :8080

# 或使用 ss
sudo ss -tulpn | grep :8080

# 修改端口配置
sudo nano /etc/default/chatroom-app
```

#### 3. 权限问题

```bash
# 重新设置权限
sudo chown -R chatroom:chatroom /opt/chatroom-app
sudo chmod +x /opt/chatroom-app/target/release/chatroom-app
```

#### 4. 内存不足

```bash
# 查看内存使用
free -h

# 查看应用内存使用
ps aux | grep chatroom-app

# 调整系统配置或增加内存
```

### 性能调优

#### 1. 调整工作线程数

```bash
# 编辑配置文件
sudo nano /etc/default/chatroom-app

# 设置线程数 (通常为 CPU 核心数)
WORKER_THREADS=4
```

#### 2. 调整连接限制

```bash
# 系统级别限制
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# 应用级别限制
sudo nano /etc/default/chatroom-app
# 设置 MAX_CONNECTIONS=1000
```

## 📞 支持

如果遇到问题，请：

1. 查看日志: `./chatroom-ctl.sh logs`
2. 运行健康检查: `./chatroom-ctl.sh health`
3. 检查系统资源使用情况
4. 参考本文档的故障排除部分

---

**注意**: 本应用设计用于演示和小规模使用。在生产环境中使用时，请确保进行充分的安全评估和性能测试。