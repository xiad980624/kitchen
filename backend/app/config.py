from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://littlekitchen:littlekitchen@db:5432/littlekitchen"
    jwt_secret: str = Field(min_length=32)
    access_token_days: int = Field(default=30, ge=1, le=365)
    cors_origins: str = ""
    media_root: Path = Path("/app/data/uploads")

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def allowed_origins(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
