use redis::Client;
use sqlx::PgPool;
use std::sync::Arc;
use tonic::{Request, Response, Status, transport::Server};
use tracing::{error, info};
use tower_http::trace::TraceLayer;

mod cache;
mod config;
mod db;
mod error;
mod models;
mod repositories;
mod utils;

pub mod auth {
    tonic::include_proto!("auth");
}

use auth::auth_service_server::{AuthService, AuthServiceServer};
use auth::{
    ForgotPasswordRequest, ForgotPasswordResponse, LoginRequest, LoginResponse,
    ResetPasswordRequest, ResetPasswordResponse, SignUpRequest, SignUpResponse,
    ValidateTokenRequest, ValidateTokenResponse,
};
use chrono::{Duration, Utc};
use config::Settings;
use error::AppError;
use models::requests::{
    ForgotPasswordRequestDto, LoginRequestDto, ResetPasswordRequestDto, SignUpRequestDto,
    ValidateTokenRequestDto,
};
use repositories::session::SessionRepository;
use repositories::user::UserRepository;
use utils::jwt::TokenManager;
use utils::password;
use uuid::Uuid;

#[derive(Debug)]
pub struct MyAuthService {
    pub pool: Arc<PgPool>,
    pub redis_client: Client,
    pub user_repo: UserRepository,
    pub settings: Settings,
}

#[tonic::async_trait]
impl AuthService for MyAuthService {
    async fn sign_up(
        &self,
        request: Request<SignUpRequest>,
    ) -> Result<Response<SignUpResponse>, Status> {
        info!("Got a SignUp request: {:?}", request);
        let req = request.into_inner();

        let dto: SignUpRequestDto = req.try_into().map_err(AppError::ValidationError)?;

        let hashed_password = password::hash_password(&dto.password).map_err(AppError::from)?;

        let user = self
            .user_repo
            .create(
                &dto.email,
                &hashed_password,
                &dto.first_name,
                &dto.last_name,
            )
            .await
            .map_err(AppError::DbError)?;

        let reply = SignUpResponse {
            success: true,

            message: "User signed up successfully".into(),

            user: Some(auth::User {
                id: user.id.to_string(),

                email: user.email,

                first_name: user.first_name,

                last_name: user.last_name,
            }),
        };

        Ok(Response::new(reply))
    }

    async fn login(
        &self,
        request: Request<LoginRequest>,
    ) -> Result<Response<LoginResponse>, Status> {
        info!("Got a Login request: {:?}", request);

        let req = request.into_inner();

        let dto: LoginRequestDto = req.try_into().map_err(AppError::ValidationError)?;

        let user = self
            .user_repo
            .find_by_email(&dto.email)
            .await
            .map_err(AppError::DbError)?;

        let user = match user {
            Some(u) => u,

            None => return Err(AppError::Unauthorized("Invalid credentials".to_string()).into()),
        };

        let password_matches = password::verify_password(&user.password_hash, &dto.password)
            .map_err(AppError::from)?;

        if !password_matches {
            return Err(AppError::Unauthorized("Invalid credentials".to_string()).into());
        }

        let token_manager = TokenManager::new(self.settings.jwt_secret.clone());

        let (access_token, access_exp) = token_manager
            .generate_access_token(user.id)
            .map_err(AppError::JwtError)?;

        let (refresh_token, refresh_exp) = token_manager
            .generate_refresh_token(user.id)
            .map_err(AppError::JwtError)?;

        let session_repo = SessionRepository::new(self.redis_client.clone());

        session_repo
            .store_refresh_token(
                user.id,
                &refresh_token,
                Duration::seconds((refresh_exp - Utc::now().timestamp() as usize) as i64),
            )
            .await
            .map_err(AppError::RedisError)?;

        self.user_repo
            .update_last_login(user.id)
            .await
            .map_err(AppError::DbError)?;

        let reply = LoginResponse {
            access_token,

            refresh_token,

            expires_in: access_exp as i64,

            user: Some(auth::User {
                id: user.id.to_string(),

                email: user.email,

                first_name: user.first_name,

                last_name: user.last_name,
            }),
        };

        Ok(Response::new(reply))
    }

    async fn forgot_password(
        &self,
        request: Request<ForgotPasswordRequest>,
    ) -> Result<Response<ForgotPasswordResponse>, Status> {
        info!("Got a ForgotPassword request: {:?}", request);

        let req = request.into_inner();

        let dto: ForgotPasswordRequestDto = req.try_into().map_err(AppError::ValidationError)?;

        // Find the user by email (don't return error if not found for security reasons)

        let user = self
            .user_repo
            .find_by_email(&dto.email)
            .await
            .map_err(AppError::DbError)?;

        if let Some(user) = user {
            let reset_token = Uuid::new_v4().to_string();

            let session_repo = SessionRepository::new(self.redis_client.clone());

            session_repo
                .store_reset_token(&reset_token, user.id, Duration::minutes(30))
                .await
                .map_err(AppError::RedisError)?;

            // In a real application, you would send this token via email.

            info!(
                "Password reset token for user {}: {}",
                user.email, reset_token
            );
        }

        let reply = ForgotPasswordResponse {
            success: true,

            message: "If an account with that email exists, a password reset link has been sent."
                .into(),
        };

        Ok(Response::new(reply))
    }

    async fn reset_password(
        &self,
        request: Request<ResetPasswordRequest>,
    ) -> Result<Response<ResetPasswordResponse>, Status> {
        info!("Got a ResetPassword request: {:?}", request);

        let req = request.into_inner();

        let dto: ResetPasswordRequestDto = req.try_into().map_err(AppError::ValidationError)?;

        let session_repo = SessionRepository::new(self.redis_client.clone());

        let user_id = session_repo
            .get_user_id_from_reset_token(&dto.token)
            .await
            .map_err(AppError::RedisError)?;

        let user_id = match user_id {
            Some(id) => id,

            None => {
                return Err(
                    AppError::BadRequest("Invalid or expired reset token.".to_string()).into(),
                );
            }
        };

        let hashed_password = password::hash_password(&dto.new_password).map_err(AppError::from)?;

        self.user_repo
            .update_password(user_id, &hashed_password)
            .await
            .map_err(AppError::DbError)?;

        let reply = ResetPasswordResponse {
            success: true,

            message: "Password reset successfully".into(),
        };

        Ok(Response::new(reply))
    }

    async fn validate_token(
        &self,
        request: Request<ValidateTokenRequest>,
    ) -> Result<Response<ValidateTokenResponse>, Status> {
        info!("Got a ValidateToken request: {:?}", request);

        let req = request.into_inner();

        let dto: ValidateTokenRequestDto = req.try_into().map_err(AppError::ValidationError)?;

        let token_manager = TokenManager::new(self.settings.jwt_secret.clone());

        let claims = token_manager
            .validate_token(&dto.access_token)
            .map_err(AppError::JwtError)?;

        let user_id = Uuid::parse_str(&claims.sub)
            .map_err(|e| AppError::Internal(format!("Invalid user ID in token: {}", e)))?;

        let user = self
            .user_repo
            .find_by_id(user_id)
            .await
            .map_err(AppError::DbError)?;

        let user = match user {
            Some(u) if u.is_active => u,

            _ => {
                return Err(
                    AppError::Unauthorized("User not active or not found".to_string()).into(),
                );
            }
        };

        let reply = ValidateTokenResponse {
            valid: true,

            user: Some(auth::User {
                id: user.id.to_string(),

                email: user.email,

                first_name: user.first_name,

                last_name: user.last_name,
            }),

            message: "Token is valid".into(),
        };

        Ok(Response::new(reply))
    }
}

#[tokio::main]

async fn main() -> Result<(), AppError> {
    // 1. Initialize logging

    tracing_subscriber::fmt::init();

    // 2. Load configuration

    let settings = Settings::new().map_err(AppError::from)?;

    // 3. Initialize Database Pool

    let pool = db::init_pool(&settings.database_url)
        .await
        .map_err(AppError::DbError)?;

    info!("Running database migrations...");
    sqlx::migrate!("../backend/migrations")
        .run(&pool)
        .await
        .map_err(|e| AppError::Internal(format!("Failed to run migrations: {}", e)))?;
    info!("Database migrations applied successfully.");

    let pool_arc = Arc::new(pool);

    // 4. Initialize Redis Client

    let redis_client = cache::init_client(&settings.redis_url).map_err(AppError::RedisError)?;

    let user_repo = UserRepository::new(pool_arc.clone());

    let addr = format!("{}:{}", settings.server_host, settings.server_port)
        .parse()
        .map_err(AppError::from)?;

    let auth_service = MyAuthService {
        pool: pool_arc,

        redis_client,

        user_repo,

        settings,
    };

    info!("AuthService server listening on {}", addr);

    Server::builder()
        .layer(TraceLayer::new_for_grpc())
        .add_service(AuthServiceServer::new(auth_service))
        .serve(addr)
        .await?;

    Ok(())
}
