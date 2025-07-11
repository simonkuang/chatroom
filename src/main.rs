mod websocket;
mod chatroom;
mod handlers;

use actix_web::{web, App, HttpServer, middleware::Logger};
use std::sync::Arc;
use tokio::sync::RwLock;
use chatroom::ChatRoomManager;
use websocket::WebSocketManager;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init();
    
    let chat_manager = Arc::new(RwLock::new(ChatRoomManager::new()));
    let ws_manager = Arc::new(RwLock::new(WebSocketManager::new()));
    
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(chat_manager.clone()))
            .app_data(web::Data::new(ws_manager.clone()))
            .wrap(Logger::default())
            .service(handlers::index)
            .service(handlers::create_room)
            .service(handlers::list_rooms)
            .service(handlers::join_room)
            .service(handlers::update_password)
            .service(handlers::websocket_handler)
            .service(actix_web::web::resource("/static/{filename:.*}")
                .route(actix_web::web::get().to(handlers::static_files)))
    })
    .bind("0.0.0.0:9099")?
    .run()
    .await
}
