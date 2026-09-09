from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "Mokhtar"
    database_url: str = "postgresql://mokhtar:mokhtar@localhost:5432/mokhtar"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_days: int = 365  # long-lived sessions; re-issue via Mokhtar code
    invite_code_expire_days: int = 7
    invite_code_max_attempts: int = 5
    default_currency: str = "ILS"

    class Config:
        env_file = ".env"


settings = Settings()
