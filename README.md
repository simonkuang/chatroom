# 聊天室应用

一个基于 Rust Actix-Web 的实时聊天室应用，支持多房间聊天、密码保护等功能。

## 功能特性

1. **免登录使用** - 用户无需注册登录，输入昵称即可使用
2. **创建聊天室** - 可以创建新的聊天室，支持设置密码保护
3. **加入聊天室** - 通过房间ID加入现有聊天室
4. **密码管理** - 创建时可选择设置密码，房间内用户可修改密码
5. **实时聊天** - 基于WebSocket的实时消息传输
6. **本地存储** - 聊天记录保存在浏览器本地，不存储在服务器
7. **响应式设计** - 支持桌面和移动设备

## 技术栈

- **后端**: Rust + Actix-Web + WebSocket
- **前端**: 原生 JavaScript + HTML5 + CSS3
- **存储**: 浏览器 LocalStorage（客户端存储）

## 快速开始

### 环境要求

- Rust 1.70+ 
- Cargo

### 安装和运行

1. 克隆项目
```bash
git clone <repository-url>
cd chatroom-app
```

2. 安装依赖并运行
```bash
cargo run
```

3. 打开浏览器访问
```
http://127.0.0.1:8080
```

## 使用说明

### 创建聊天室

1. 在首页输入聊天室名称
2. 可选择设置密码（留空表示无密码）
3. 点击"创建聊天室"按钮
4. 创建成功后会自动填入房间ID到加入表单

### 加入聊天室

1. 输入聊天室ID
2. 如果房间有密码，输入密码
3. 输入您的昵称
4. 点击"加入聊天室"按钮

### 聊天功能

- 发送消息：在输入框输入消息，按回车或点击发送按钮
- 查看历史：聊天记录会保存在浏览器本地
- 修改密码：在聊天界面点击"修改密码"按钮
- 离开房间：点击"离开聊天室"按钮

## API 接口

### 创建聊天室
```
POST /api/rooms
Content-Type: application/json

{
  "name": "聊天室名称",
  "password": "可选密码"
}
```

### 获取聊天室列表
```
GET /api/rooms
```

### 加入聊天室验证
```
POST /api/rooms/join
Content-Type: application/json

{
  "room_id": "房间ID",
  "password": "可选密码"
}
```

### 修改房间密码
```
POST /api/rooms/password
Content-Type: application/json

{
  "room_id": "房间ID",
  "new_password": "新密码"
}
```

### WebSocket 连接
```
GET /ws
```

## WebSocket 消息格式

### 客户端消息

```json
// 加入房间
{
  "type": "join",
  "room_id": "房间ID",
  "username": "用户名",
  "password": "可选密码"
}

// 发送聊天消息
{
  "type": "chat",
  "content": "消息内容",
  "username": "用户名"
}

// 心跳检测
{
  "type": "ping"
}
```

### 服务器消息

```json
// 聊天消息
{
  "type": "chat",
  "content": "消息内容",
  "username": "用户名",
  "timestamp": "2023-12-01T12:00:00Z",
  "user_id": "用户ID"
}

// 用户加入
{
  "type": "user_joined",
  "username": "用户名",
  "user_id": "用户ID",
  "timestamp": "2023-12-01T12:00:00Z"
}

// 用户离开
{
  "type": "user_left",
  "username": "用户名",
  "user_id": "用户ID",
  "timestamp": "2023-12-01T12:00:00Z"
}

// 错误消息
{
  "type": "error",
  "message": "错误信息"
}
```

## 项目结构

```
chatroom-app/
├── src/
│   ├── main.rs          # 应用入口
│   ├── handlers.rs      # HTTP 路由处理
│   ├── websocket.rs     # WebSocket 处理
│   └── chatroom.rs      # 聊天室管理
├── static/
│   ├── index.html       # 前端页面
│   ├── style.css        # 样式文件
│   └── app.js           # 前端逻辑
├── Cargo.toml           # 依赖配置
└── README.md            # 项目说明
```

## 开发说明

### 添加新功能

1. 后端功能：在相应的模块中添加逻辑
2. API接口：在 `handlers.rs` 中添加新的路由
3. 前端功能：在 `app.js` 中添加相应的JavaScript代码

### 自定义配置

可以修改 `main.rs` 中的服务器配置：

```rust
HttpServer::new(move || {
    // 配置
})
.bind("127.0.0.1:8080")? // 修改监听地址和端口
.run()
.await
```

## 注意事项

1. 聊天记录仅保存在浏览器本地，清除浏览器数据会丢失历史记录
2. 服务器重启后所有聊天室会被清空
3. 密码采用明文传输和存储，仅用于演示，生产环境请使用加密
4. 当前版本不支持文件传输和富文本消息

## 许可证

MIT License