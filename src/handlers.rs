use actix_web::{web, HttpRequest, HttpResponse, Result, get, post};
use actix_web_actors::ws;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use crate::chatroom::ChatRoomManager;
use crate::websocket::{WebSocketSession, WebSocketManager};

#[derive(Deserialize)]
pub struct CreateRoomRequest {
    name: String,
    password: Option<String>,
}

#[derive(Deserialize)]
pub struct JoinRoomRequest {
    room_id: String,
    password: Option<String>,
}

#[derive(Deserialize)]
pub struct UpdatePasswordRequest {
    room_id: String,
    new_password: String,
}

#[derive(Serialize)]
pub struct ApiResponse<T> {
    success: bool,
    data: Option<T>,
    message: Option<String>,
}

impl<T> ApiResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            message: None,
        }
    }

    pub fn error(message: String) -> Self {
        Self {
            success: false,
            data: None,
            message: Some(message),
        }
    }
}

#[get("/")]
pub async fn index() -> Result<HttpResponse> {
    let html = include_str!("../static/index.html");
    Ok(HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(html))
}

#[post("/api/rooms")]
pub async fn create_room(
    chat_manager: web::Data<Arc<RwLock<ChatRoomManager>>>,
    req: web::Json<CreateRoomRequest>,
) -> Result<HttpResponse> {
    let mut manager = chat_manager.write().await;
    
    match manager.create_room(req.name.clone(), req.password.clone()) {
        Ok(room_id) => {
            #[derive(Serialize)]
            struct CreateRoomResponse {
                room_id: String,
            }
            
            Ok(HttpResponse::Ok().json(ApiResponse::success(CreateRoomResponse { room_id })))
        }
        Err(e) => Ok(HttpResponse::BadRequest().json(ApiResponse::<()>::error(e))),
    }
}

#[get("/api/rooms")]
pub async fn list_rooms(
    chat_manager: web::Data<Arc<RwLock<ChatRoomManager>>>,
) -> Result<HttpResponse> {
    let manager = chat_manager.read().await;
    let rooms = manager.list_rooms();
    Ok(HttpResponse::Ok().json(ApiResponse::success(rooms)))
}

#[post("/api/rooms/join")]
pub async fn join_room(
    chat_manager: web::Data<Arc<RwLock<ChatRoomManager>>>,
    req: web::Json<JoinRoomRequest>,
) -> Result<HttpResponse> {
    let manager = chat_manager.read().await;
    
    match manager.get_room(&req.room_id) {
        Some(room) => {
            if let Some(room_password) = &room.password {
                match &req.password {
                    Some(provided_password) => {
                        if room_password != provided_password {
                            return Ok(HttpResponse::Unauthorized().json(ApiResponse::<()>::error("密码错误".to_string())));
                        }
                    }
                    None => {
                        return Ok(HttpResponse::BadRequest().json(ApiResponse::<()>::error("该聊天室需要密码".to_string())));
                    }
                }
            }
            
            #[derive(Serialize)]
            struct JoinRoomResponse {
                room_id: String,
                room_name: String,
            }
            
            Ok(HttpResponse::Ok().json(ApiResponse::success(JoinRoomResponse {
                room_id: room.id.clone(),
                room_name: room.name.clone(),
            })))
        }
        None => Ok(HttpResponse::NotFound().json(ApiResponse::<()>::error("聊天室不存在".to_string()))),
    }
}

#[post("/api/rooms/password")]
pub async fn update_password(
    chat_manager: web::Data<Arc<RwLock<ChatRoomManager>>>,
    req: web::Json<UpdatePasswordRequest>,
) -> Result<HttpResponse> {
    let mut manager = chat_manager.write().await;
    
    match manager.update_room_password(&req.room_id, req.new_password.clone()) {
        Ok(()) => Ok(HttpResponse::Ok().json(ApiResponse::success("密码更新成功"))),
        Err(e) => Ok(HttpResponse::BadRequest().json(ApiResponse::<()>::error(e))),
    }
}

#[get("/ws")]
pub async fn websocket_handler(
    req: HttpRequest,
    stream: web::Payload,
    _chat_manager: web::Data<Arc<RwLock<ChatRoomManager>>>,
    ws_manager: web::Data<Arc<RwLock<WebSocketManager>>>,
) -> Result<HttpResponse> {
    let session = WebSocketSession::new(ws_manager.get_ref().clone());
    ws::start(session, &req, stream)
}

pub async fn static_files(path: web::Path<String>) -> Result<HttpResponse> {
    let filename = path.into_inner();
    
    match filename.as_str() {
        "style.css" => {
            let css = include_str!("../static/style.css");
            Ok(HttpResponse::Ok()
                .content_type("text/css")
                .body(css))
        }
        "app.js" => {
            let js = include_str!("../static/app.js");
            Ok(HttpResponse::Ok()
                .content_type("application/javascript")
                .body(js))
        }
        _ => Ok(HttpResponse::NotFound().body("File not found")),
    }
}