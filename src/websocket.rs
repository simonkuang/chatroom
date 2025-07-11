use actix::prelude::*;
use actix_web_actors::ws;
use serde::{Deserialize, Serialize};
use std::time::{Duration, Instant};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use uuid::Uuid;

const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(5);
const CLIENT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ClientMessage {
    #[serde(rename = "chat")]
    Chat {
        content: String,
        username: String,
    },
    #[serde(rename = "join")]
    Join {
        room_id: String,
        username: String,
        password: Option<String>,
    },
    #[serde(rename = "ping")]
    Ping,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ServerMessage {
    #[serde(rename = "chat")]
    Chat {
        content: String,
        username: String,
        timestamp: chrono::DateTime<chrono::Utc>,
        user_id: String,
    },
    #[serde(rename = "user_joined")]
    UserJoined {
        username: String,
        user_id: String,
        timestamp: chrono::DateTime<chrono::Utc>,
    },
    #[serde(rename = "user_left")]
    UserLeft {
        username: String,
        user_id: String,
        timestamp: chrono::DateTime<chrono::Utc>,
    },
    #[serde(rename = "error")]
    Error {
        message: String,
    },
    #[serde(rename = "joined")]
    Joined {
        room_id: String,
        user_id: String,
    },
    #[serde(rename = "pong")]
    Pong,
}

// WebSocket会话管理器
pub struct WebSocketManager {
    pub sessions: HashMap<String, Addr<WebSocketSession>>,
    pub rooms: HashMap<String, Vec<String>>, // room_id -> user_ids
}

impl WebSocketManager {
    pub fn new() -> Self {
        Self {
            sessions: HashMap::new(),
            rooms: HashMap::new(),
        }
    }

    pub fn add_session(&mut self, user_id: String, room_id: String, addr: Addr<WebSocketSession>) {
        self.sessions.insert(user_id.clone(), addr);
        self.rooms.entry(room_id).or_insert_with(Vec::new).push(user_id);
    }

    pub fn remove_session(&mut self, user_id: &str, room_id: &str) {
        self.sessions.remove(user_id);
        if let Some(users) = self.rooms.get_mut(room_id) {
            users.retain(|id| id != user_id);
            if users.is_empty() {
                self.rooms.remove(room_id);
            }
        }
    }

    pub fn broadcast_to_room(&self, room_id: &str, message: ServerMessage, exclude_user: Option<&str>) {
        if let Some(user_ids) = self.rooms.get(room_id) {
            for user_id in user_ids {
                if let Some(exclude_id) = exclude_user {
                    if user_id == exclude_id {
                        continue;
                    }
                }
                if let Some(addr) = self.sessions.get(user_id) {
                    let _ = addr.do_send(BroadcastMessage {
                        room_id: room_id.to_string(),
                        message: message.clone(),
                        exclude_user: None,
                    });
                }
            }
        }
    }
}

pub struct WebSocketSession {
    pub id: String,
    pub room_id: Option<String>,
    pub username: Option<String>,
    pub hb: Instant,
    pub ws_manager: Arc<RwLock<WebSocketManager>>,
}

impl WebSocketSession {
    pub fn new(ws_manager: Arc<RwLock<WebSocketManager>>) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            room_id: None,
            username: None,
            hb: Instant::now(),
            ws_manager,
        }
    }

    fn hb(&self, ctx: &mut <Self as Actor>::Context) {
        ctx.run_interval(HEARTBEAT_INTERVAL, |act, ctx| {
            if Instant::now().duration_since(act.hb) > CLIENT_TIMEOUT {
                println!("WebSocket Client heartbeat failed, disconnecting!");
                ctx.stop();
                return;
            }

            ctx.ping(b"");
        });
    }

    fn send_message(&self, msg: ServerMessage, ctx: &mut <Self as Actor>::Context) {
        if let Ok(text) = serde_json::to_string(&msg) {
            ctx.text(text);
        }
    }
}

impl Actor for WebSocketSession {
    type Context = ws::WebsocketContext<Self>;

    fn started(&mut self, ctx: &mut Self::Context) {
        self.hb(ctx);
    }

    fn stopped(&mut self, _ctx: &mut Self::Context) {
        // 用户离开时清理会话
        if let (Some(room_id), Some(username)) = (&self.room_id, &self.username) {
            let ws_manager = self.ws_manager.clone();
            let user_id = self.id.clone();
            let room_id_clone = room_id.clone();
            let username_clone = username.clone();
            
            actix::spawn(async move {
                let mut manager = ws_manager.write().await;
                manager.remove_session(&user_id, &room_id_clone);
                
                // 通知其他用户有用户离开
                let leave_msg = ServerMessage::UserLeft {
                    username: username_clone,
                    user_id: user_id.clone(),
                    timestamp: chrono::Utc::now(),
                };
                manager.broadcast_to_room(&room_id_clone, leave_msg, Some(&user_id));
            });
        }
    }
}

impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for WebSocketSession {
    fn handle(&mut self, msg: Result<ws::Message, ws::ProtocolError>, ctx: &mut Self::Context) {
        match msg {
            Ok(ws::Message::Ping(msg)) => {
                self.hb = Instant::now();
                ctx.pong(&msg);
            }
            Ok(ws::Message::Pong(_)) => {
                self.hb = Instant::now();
            }
            Ok(ws::Message::Text(text)) => {
                self.hb = Instant::now();
                
                match serde_json::from_str::<ClientMessage>(&text) {
                    Ok(client_msg) => {
                        match client_msg {
                            ClientMessage::Chat { content, username } => {
                                if let Some(room_id) = &self.room_id {
                                    let server_msg = ServerMessage::Chat {
                                        content,
                                        username,
                                        timestamp: chrono::Utc::now(),
                                        user_id: self.id.clone(),
                                    };
                                    
                                    // 广播消息到房间内的所有用户
                                    let ws_manager = self.ws_manager.clone();
                                    let room_id_clone = room_id.clone();
                                    let msg_clone = server_msg.clone();
                                    
                                    actix::spawn(async move {
                                        let manager = ws_manager.read().await;
                                        manager.broadcast_to_room(&room_id_clone, msg_clone, None);
                                    });
                                }
                            }
                            ClientMessage::Join { room_id, username, password } => {
                                self.room_id = Some(room_id.clone());
                                self.username = Some(username.clone());
                                
                                // 将会话添加到WebSocket管理器
                                let ws_manager = self.ws_manager.clone();
                                let user_id = self.id.clone();
                                let room_id_clone = room_id.clone();
                                let username_clone = username.clone();
                                let addr = ctx.address();
                                
                                actix::spawn(async move {
                                    let mut manager = ws_manager.write().await;
                                    manager.add_session(user_id.clone(), room_id_clone.clone(), addr);
                                    
                                    // 通知其他用户有新用户加入
                                    let join_msg = ServerMessage::UserJoined {
                                        username: username_clone,
                                        user_id: user_id.clone(),
                                        timestamp: chrono::Utc::now(),
                                    };
                                    manager.broadcast_to_room(&room_id_clone, join_msg, Some(&user_id));
                                });
                                
                                let server_msg = ServerMessage::Joined {
                                    room_id,
                                    user_id: self.id.clone(),
                                };
                                self.send_message(server_msg, ctx);
                            }
                            ClientMessage::Ping => {
                                let server_msg = ServerMessage::Pong;
                                self.send_message(server_msg, ctx);
                            }
                        }
                    }
                    Err(e) => {
                        let error_msg = ServerMessage::Error {
                            message: format!("Invalid message format: {}", e),
                        };
                        self.send_message(error_msg, ctx);
                    }
                }
            }
            Ok(ws::Message::Binary(_)) => {
                println!("Unexpected binary message");
            }
            Ok(ws::Message::Close(reason)) => {
                ctx.close(reason);
                ctx.stop();
            }
            _ => ctx.stop(),
        }
    }
}

// 消息类型用于Actor间通信
#[derive(Message)]
#[rtype(result = "()")]
pub struct BroadcastMessage {
    pub room_id: String,
    pub message: ServerMessage,
    pub exclude_user: Option<String>,
}

impl Handler<BroadcastMessage> for WebSocketSession {
    type Result = ();

    fn handle(&mut self, msg: BroadcastMessage, ctx: &mut Self::Context) {
        if let Some(exclude_id) = &msg.exclude_user {
            if exclude_id == &self.id {
                return;
            }
        }
        
        if let Some(room_id) = &self.room_id {
            if room_id == &msg.room_id {
                self.send_message(msg.message, ctx);
            }
        }
    }
}