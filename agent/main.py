from fastapi import FastAPI
import logging
from .config import settings
from agent.core.routers import router

logging.basicConfig(
    level=settings.LOG_LEVEL.upper(),
    format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="VPN Node Agent",
    description="Manage WireGuard on VPN node",
    version="1.0.0",
)

app.include_router(router, prefix="/agent")


@app.get("/health")
async def health():
    return {"status": "ok"}
