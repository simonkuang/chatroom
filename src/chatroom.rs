use std::collections::HashMap;
use uuid::Uuid;
use serde::{Deserialize, Serialize};
use actix::Addr;
use crate::websocket::WebSocketSession;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatRoom {
    pub id: String,
    pub name: String,
    pub password: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    #[serde(skip)]
    pub sessions: HashMap<String, Addr<WebSocketSession>>,
}

impl ChatRoom {
    pub fn new(name: String, password: Option<String>) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name,
            password,
            created_at: chrono::Utc::now(),
            sessions: HashMap::new(),
        }
    }

    pub fn add_session(&mut self, user_id: String, addr: Addr<WebSocketSession>) {
        self.sessions.insert(user_id, addr);
    }

    pub fn remove_session(&mut self, user_id: &str) {
        self.sessions.remove(user_id);
    }

    pub fn has_password(&self) -> bool {
        self.password.is_some()
    }

    pub fn verify_password(&self, password: &str) -> bool {
        match &self.password {
            Some(room_password) => room_password == password,
            None => true,
        }
    }

    pub fn update_password(&mut self, new_password: String) -> Result<(), String> {
        if new_password.trim().is_empty() {
            return Err("密码不能为空".to_string());
        }
        self.password = Some(new_password);
        Ok(())
    }
}

#[derive(Debug)]
pub struct ChatRoomManager {
    rooms: HashMap<String, ChatRoom>,
}

impl ChatRoomManager {
    pub fn new() -> Self {
        Self {
            rooms: HashMap::new(),
        }
    }

    pub fn create_room(&mut self, name: String, password: Option<String>) -> Result<String, String> {
        if name.trim().is_empty() {
            return Err("聊天室名称不能为空".to_string());
        }

        let room = ChatRoom::new(name, password);
        let room_id = room.id.clone();
        self.rooms.insert(room_id.clone(), room);
        Ok(room_id)
    }

    pub fn get_room(&self, room_id: &str) -> Option<&ChatRoom> {
        self.rooms.get(room_id)
    }

    pub fn get_room_mut(&mut self, room_id: &str) -> Option<&mut ChatRoom> {
        self.rooms.get_mut(room_id)
    }

    pub fn join_room(&mut self, room_id: &str, user_id: String, password: Option<String>, addr: Addr<WebSocketSession>) -> Result<(), String> {
        let room = self.rooms.get_mut(room_id)
            .ok_or("聊天室不存在")?;

        // 验证密码
        if let Some(room_password) = &room.password {
            match password {
                Some(provided_password) => {
                    if room_password != &provided_password {
                        return Err("密码错误".to_string());
                    }
                }
                None => return Err("该聊天室需要密码".to_string()),
            }
        }

        room.add_session(user_id, addr);
        Ok(())
    }

    pub fn update_room_password(&mut self, room_id: &str, new_password: String) -> Result<(), String> {
        let room = self.rooms.get_mut(room_id)
            .ok_or("聊天室不存在")?;
        
        room.update_password(new_password)
    }

    pub fn list_rooms(&self) -> Vec<RoomInfo> {
        self.rooms.values().map(|room| RoomInfo {
            id: room.id.clone(),
            name: room.name.clone(),
            has_password: room.has_password(),
            user_count: room.sessions.len(),
            created_at: room.created_at,
        }).collect()
    }
}

#[derive(Serialize, Deserialize)]
pub struct RoomInfo {
    pub id: String,
    pub name: String,
    pub has_password: bool,
    pub user_count: usize,
    pub created_at: chrono::DateTime<chrono::Utc>,
}