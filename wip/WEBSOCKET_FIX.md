# WebSocket 连接问题快速修复指南

## 🚨 问题描述
WebSocket 连接到 `wss://chat.tianwen.tech/ws` 失败

## 🔧 立即修复步骤

### 1. 检查 OpenResty 配置

确保您的 OpenResty 配置包含以下关键设置：

```nginx
# 在 server 块中添加 WebSocket 支持
location /ws {
    proxy_pass http://127.0.0.1:8080;
    
    # 关键的 WebSocket 头部 - 必须包含
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # 标准代理头部
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # 超时设置 - 很重要
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 3600s;  # WebSocket 长连接需要长超时
    
    # 禁用缓冲 - WebSocket 必需
    proxy_buffering off;
    proxy_request_buffering off;
}
```

### 2. 添加 WebSocket 升级映射

在 `http` 块中添加：

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
```

然后在 location /ws 中使用：
```nginx
proxy_set_header Connection $connection_upgrade;
```

### 3. 检查后端服务

确保聊天室应用正在运行：

```bash
# 检查服务状态
./chatroom-ctl.sh status

# 如果未运行，启动服务
./chatroom-ctl.sh start

# 检查端口监听
netstat -tuln | grep :8080
```

### 4. 运行诊断脚本

```bash
# 运行 WebSocket 诊断
./websocket-debug.sh
```

### 5. 重启 OpenResty

```bash
# 测试配置
sudo openresty -t

# 重新加载配置
sudo openresty -s reload

# 或完全重启
sudo systemctl restart openresty
```

## 🔍 常见问题排查

### 问题 1: 握手失败 (101 状态码未返回)

**原因**: 缺少 WebSocket 升级头部

**解决方案**:
```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

### 问题 2: 连接立即断开

**原因**: 超时设置过短或缓冲问题

**解决方案**:
```nginx
proxy_read_timeout 3600s;
proxy_buffering off;
proxy_request_buffering off;
```

### 问题 3: SSL/TLS 相关错误

**原因**: HTTPS 到 HTTP 后端的代理问题

**解决方案**:
```nginx
proxy_set_header X-Forwarded-Proto $scheme;
proxy_ssl_verify off;  # 如果后端是 HTTP
```

### 问题 4: 防火墙阻塞

**检查方法**:
```bash
# 检查端口
sudo netstat -tuln | grep :443
sudo netstat -tuln | grep :8080

# 检查防火墙
sudo ufw status
sudo iptables -L
```

## 📝 完整的 OpenResty 配置示例

```nginx
http {
    # WebSocket 升级映射
    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }
    
    upstream chatroom_backend {
        server 127.0.0.1:8080;
        keepalive 32;
    }
    
    server {
        listen 443 ssl http2;
        server_name chat.tianwen.tech;
        
        # SSL 配置
        ssl_certificate /path/to/your/certificate.crt;
        ssl_certificate_key /path/to/your/private.key;
        
        # WebSocket 路由
        location /ws {
            proxy_pass http://chatroom_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 3600s;
            
            proxy_buffering off;
            proxy_request_buffering off;
        }
        
        # 其他路由
        location / {
            proxy_pass http://chatroom_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

## 🧪 测试 WebSocket 连接

### 方法 1: 使用浏览器开发者工具

1. 打开 `https://chat.tianwen.tech`
2. 按 F12 打开开发者工具
3. 查看 Network 标签页
4. 尝试加入聊天室
5. 查看 WebSocket 连接状态

### 方法 2: 使用 curl 测试握手

```bash
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  https://chat.tianwen.tech/ws
```

期望返回: `HTTP/1.1 101 Switching Protocols`

### 方法 3: 使用 websocat

```bash
# 安装 websocat
cargo install websocat

# 测试连接
echo '{"type":"ping"}' | websocat wss://chat.tianwen.tech/ws
```

## 📋 检查清单

- [ ] OpenResty 配置包含 WebSocket 升级头部
- [ ] 设置了正确的超时时间 (3600s)
- [ ] 禁用了代理缓冲
- [ ] 后端聊天室应用正在运行
- [ ] 端口 8080 正在监听
- [ ] SSL 证书配置正确
- [ ] 防火墙允许相关端口
- [ ] OpenResty 配置语法正确
- [ ] 重启了 OpenResty 服务

## 🆘 如果问题仍然存在

1. **查看错误日志**:
   ```bash
   sudo tail -f /var/log/openresty/error.log
   sudo journalctl -u chatroom-app -f
   ```

2. **运行完整诊断**:
   ```bash
   ./websocket-debug.sh
   ```

3. **检查网络连通性**:
   ```bash
   # 从服务器内部测试
   curl -I http://127.0.0.1:8080
   
   # 测试 WebSocket 握手
   curl -I -H "Upgrade: websocket" -H "Connection: upgrade" http://127.0.0.1:8080/ws
   ```

4. **临时禁用 SSL 测试**:
   ```bash
   # 添加临时 HTTP 配置进行测试
   server {
       listen 8081;
       location /ws {
           proxy_pass http://127.0.0.1:8080;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
       }
   }
   ```

## 📞 获取帮助

如果按照以上步骤仍无法解决问题，请提供以下信息：

1. OpenResty 版本: `openresty -v`
2. 错误日志内容
3. 诊断脚本输出
4. 网络测试结果

---

**重要提示**: WebSocket 连接失败通常是由于缺少正确的升级头部或超时设置导致的。请确保严格按照上述配置进行设置。