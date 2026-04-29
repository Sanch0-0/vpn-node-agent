from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    CONTROLPLANE_URL: str  # for firewall rule
    HOST: str = "127.0.0.1"
    PORT: int = 9000
    WG_INTERFACE: str = "wg0"
    LOG_LEVEL: str = "info"

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
