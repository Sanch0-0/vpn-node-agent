from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    AGENT_TOKEN: str
    CONTROL_PLANE_IP: str  # for firewall rule

    HOST: str = "127.0.0.1"
    PORT: int = 9000
    WG_INTERFACE: str = "wg0"
    LOG_LEVEL: str = "info"

    class Config:
        env_file = ".env"


settings = Settings()
