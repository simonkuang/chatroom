class ChatApp {
    constructor() {
        this.ws = null;
        this.currentRoom = null;
        this.currentUser = null;
        this.messages = [];
        this.init();
    }

    init() {
        this.bindEvents();
        this.loadRooms();
        this.loadMessagesFromStorage();
    }

    bindEvents() {
        // 创建聊天室
        document.getElementById('create-room-btn').addEventListener('click', () => {
            this.createRoom();
        });

        // 加入聊天室
        document.getElementById('join-room-btn').addEventListener('click', () => {
            this.joinRoom();
        });

        // 刷新聊天室列表
        document.getElementById('refresh-rooms-btn').addEventListener('click', () => {
            this.loadRooms();
        });

        // 发送消息
        document.getElementById('send-message-btn').addEventListener('click', () => {
            this.sendMessage();
        });

        // 回车发送消息
        document.getElementById('message-input').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.sendMessage();
            }
        });

        // 离开聊天室
        document.getElementById('leave-room-btn').addEventListener('click', () => {
            this.leaveRoom();
        });

        // 修改密码
        document.getElementById('update-password-btn').addEventListener('click', () => {
            this.showUpdatePasswordModal();
        });

        // 模态框事件
        document.querySelector('.close').addEventListener('click', () => {
            this.hideModal();
        });

        document.getElementById('modal-cancel').addEventListener('click', () => {
            this.hideModal();
        });

        // 点击模态框外部关闭
        document.getElementById('modal').addEventListener('click', (e) => {
            if (e.target === document.getElementById('modal')) {
                this.hideModal();
            }
        });
    }

    async createRoom() {
        const name = document.getElementById('room-name').value.trim();
        const password = document.getElementById('room-password').value.trim();

        if (!name) {
            this.showNotification('请输入聊天室名称', 'error');
            return;
        }

        try {
            const response = await fetch('/api/rooms', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    name: name,
                    password: password || null
                })
            });

            const result = await response.json();

            if (result.success) {
                this.showNotification('聊天室创建成功！', 'success');
                document.getElementById('room-name').value = '';
                document.getElementById('room-password').value = '';
                document.getElementById('join-room-id').value = result.data.room_id;
                this.loadRooms();
            } else {
                this.showNotification(result.message || '创建失败', 'error');
            }
        } catch (error) {
            this.showNotification('网络错误，请重试', 'error');
            console.error('Error creating room:', error);
        }
    }

    async joinRoom() {
        const roomId = document.getElementById('join-room-id').value.trim();
        const password = document.getElementById('join-password').value.trim();
        const username = document.getElementById('username').value.trim();

        if (!roomId) {
            this.showNotification('请输入聊天室ID', 'error');
            return;
        }

        if (!username) {
            this.showNotification('请输入您的昵称', 'error');
            return;
        }

        try {
            const response = await fetch('/api/rooms/join', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    room_id: roomId,
                    password: password || null
                })
            });

            const result = await response.json();

            if (result.success) {
                this.currentRoom = {
                    id: roomId,
                    name: result.data.room_name
                };
                this.currentUser = username;
                this.connectWebSocket();
                this.showChatPage();
                this.loadMessagesFromStorage();
            } else {
                this.showNotification(result.message || '加入失败', 'error');
            }
        } catch (error) {
            this.showNotification('网络错误，请重试', 'error');
            console.error('Error joining room:', error);
        }
    }

    connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/ws`;
        
        this.ws = new WebSocket(wsUrl);

        this.ws.onopen = () => {
            console.log('WebSocket connected');
            // 发送加入房间消息
            this.ws.send(JSON.stringify({
                type: 'join',
                room_id: this.currentRoom.id,
                username: this.currentUser,
                password: document.getElementById('join-password').value.trim() || null
            }));
        };

        this.ws.onmessage = (event) => {
            const message = JSON.parse(event.data);
            this.handleWebSocketMessage(message);
        };

        this.ws.onclose = () => {
            console.log('WebSocket disconnected');
            this.showNotification('连接已断开', 'error');
        };

        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
            this.showNotification('连接错误', 'error');
        };
    }

    handleWebSocketMessage(message) {
        switch (message.type) {
            case 'chat':
                this.addMessage(message);
                break;
            case 'user_joined':
                this.addSystemMessage(`${message.username} 加入了聊天室`);
                break;
            case 'user_left':
                this.addSystemMessage(`${message.username} 离开了聊天室`);
                break;
            case 'error':
                this.showNotification(message.message, 'error');
                break;
            case 'joined':
                this.showNotification('成功加入聊天室！', 'success');
                break;
        }
    }

    addMessage(message) {
        const messageData = {
            ...message,
            isOwn: message.username === this.currentUser
        };
        
        this.messages.push(messageData);
        this.saveMessagesToStorage();
        this.renderMessage(messageData);
        this.scrollToBottom();
    }

    addSystemMessage(content) {
        const messageData = {
            type: 'system',
            content: content,
            timestamp: new Date().toISOString(),
            isOwn: false
        };
        
        this.messages.push(messageData);
        this.saveMessagesToStorage();
        this.renderMessage(messageData);
        this.scrollToBottom();
    }

    renderMessage(message) {
        const messagesContainer = document.getElementById('chat-messages');
        const messageElement = document.createElement('div');
        
        if (message.type === 'system') {
            messageElement.className = 'message system';
            messageElement.innerHTML = `
                <div class="message-content">${this.escapeHtml(message.content)}</div>
            `;
        } else {
            messageElement.className = `message ${message.isOwn ? 'own' : 'other'}`;
            const time = new Date(message.timestamp).toLocaleTimeString();
            
            messageElement.innerHTML = `
                <div class="message-header">${this.escapeHtml(message.username)}</div>
                <div class="message-content">${this.escapeHtml(message.content)}</div>
                <div class="message-time">${time}</div>
            `;
        }
        
        messagesContainer.appendChild(messageElement);
    }

    sendMessage() {
        const input = document.getElementById('message-input');
        const content = input.value.trim();

        if (!content) {
            return;
        }

        if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
            this.showNotification('连接已断开，请重新加入聊天室', 'error');
            return;
        }

        this.ws.send(JSON.stringify({
            type: 'chat',
            content: content,
            username: this.currentUser
        }));

        // 不在这里立即显示消息，等待服务器广播回来
        input.value = '';
    }

    leaveRoom() {
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
        
        this.currentRoom = null;
        this.currentUser = null;
        this.showHomePage();
        this.clearForm();
    }

    showChatPage() {
        document.getElementById('home-page').classList.remove('active');
        document.getElementById('chat-page').classList.add('active');
        document.getElementById('chat-room-name').textContent = this.currentRoom.name;
        
        // 清空并重新渲染消息
        const messagesContainer = document.getElementById('chat-messages');
        messagesContainer.innerHTML = '';
        
        this.messages.forEach(message => {
            this.renderMessage(message);
        });
        
        this.scrollToBottom();
    }

    showHomePage() {
        document.getElementById('chat-page').classList.remove('active');
        document.getElementById('home-page').classList.add('active');
    }

    clearForm() {
        document.getElementById('join-room-id').value = '';
        document.getElementById('join-password').value = '';
        document.getElementById('username').value = '';
    }

    async loadRooms() {
        try {
            const response = await fetch('/api/rooms');
            const result = await response.json();

            if (result.success) {
                this.renderRooms(result.data);
            } else {
                this.showNotification('加载聊天室列表失败', 'error');
            }
        } catch (error) {
            this.showNotification('网络错误，请重试', 'error');
            console.error('Error loading rooms:', error);
        }
    }

    renderRooms(rooms) {
        const container = document.getElementById('rooms-list');
        
        if (rooms.length === 0) {
            container.innerHTML = '<p style="text-align: center; color: #7f8c8d;">暂无聊天室</p>';
            return;
        }

        container.innerHTML = rooms.map(room => `
            <div class="room-item">
                <div class="room-info">
                    <h4>${this.escapeHtml(room.name)}</h4>
                    <div class="room-meta">
                        ID: ${room.id} | 
                        用户: ${room.user_count} | 
                        ${room.has_password ? '<span class="password-indicator">🔒 需要密码</span>' : '🔓 无密码'} |
                        创建时间: ${new Date(room.created_at).toLocaleString()}
                    </div>
                </div>
                <div class="room-actions">
                    <button class="btn btn-small btn-primary" onclick="app.quickJoin('${room.id}')">
                        快速加入
                    </button>
                </div>
            </div>
        `).join('');
    }

    quickJoin(roomId) {
        document.getElementById('join-room-id').value = roomId;
        document.getElementById('join-room-id').scrollIntoView({ behavior: 'smooth' });
    }

    showUpdatePasswordModal() {
        if (!this.currentRoom) {
            return;
        }

        document.getElementById('modal-title').textContent = '修改聊天室密码';
        document.getElementById('modal-body').innerHTML = `
            <input type="password" id="new-password" placeholder="新密码" style="width: 100%;">
            <small style="color: #7f8c8d;">注意：修改密码后，新用户需要使用新密码才能加入</small>
        `;

        document.getElementById('modal-confirm').onclick = () => {
            this.updatePassword();
        };

        this.showModal();
    }

    async updatePassword() {
        const newPassword = document.getElementById('new-password').value.trim();

        if (!newPassword) {
            this.showNotification('密码不能为空', 'error');
            return;
        }

        try {
            const response = await fetch('/api/rooms/password', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    room_id: this.currentRoom.id,
                    new_password: newPassword
                })
            });

            const result = await response.json();

            if (result.success) {
                this.showNotification('密码修改成功！', 'success');
                this.hideModal();
            } else {
                this.showNotification(result.message || '修改失败', 'error');
            }
        } catch (error) {
            this.showNotification('网络错误，请重试', 'error');
            console.error('Error updating password:', error);
        }
    }

    showModal() {
        document.getElementById('modal').style.display = 'block';
    }

    hideModal() {
        document.getElementById('modal').style.display = 'none';
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.remove();
        }, 3000);
    }

    scrollToBottom() {
        const messagesContainer = document.getElementById('chat-messages');
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // 本地存储消息
    saveMessagesToStorage() {
        if (this.currentRoom) {
            const key = `chatroom_messages_${this.currentRoom.id}`;
            localStorage.setItem(key, JSON.stringify(this.messages));
        }
    }

    loadMessagesFromStorage() {
        if (this.currentRoom) {
            const key = `chatroom_messages_${this.currentRoom.id}`;
            const stored = localStorage.getItem(key);
            if (stored) {
                this.messages = JSON.parse(stored);
            } else {
                this.messages = [];
            }
        }
    }
}

// 初始化应用
const app = new ChatApp();