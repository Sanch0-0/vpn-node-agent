from fastapi import APIRouter, HTTPException
import logging
import os

from . import schemas
from .wireguard import WireGuardManager

logger = logging.getLogger(__name__)

router = APIRouter()
wg_manager = WireGuardManager(interface=os.getenv("WG_INTERFACE", "wg0"))


@router.post("/peers", response_model=schemas.AgentAddPeerResponse)
async def add_peer(request: schemas.AgentAddPeerRequest):
    """Add a new peer to WireGuard."""
    try:
        wg_manager.add_peer(
            request.public_key, request.allowed_ips, peer_id=request.peer_id
        )
        logger.info("Adding peer %s", request.public_key)
        return schemas.AgentAddPeerResponse(success=True)
    except Exception as e:
        logger.error(f"Failed to add peer: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete(
    "/peers/{public_key:path}", response_model=schemas.AgentRemovePeerResponse
)
async def remove_peer(public_key: str):
    """Remove a peer by public key."""
    try:
        wg_manager.remove_peer(public_key)
        logger.info("Removing peer %s", public_key)
        return schemas.AgentRemovePeerResponse(success=True)
    except Exception as e:
        logger.error(f"Failed to remove peer: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/status", response_model=schemas.AgentStatusResponse)
async def get_status():
    """Get node overall status."""
    try:
        status = wg_manager.get_status()
        return schemas.AgentStatusResponse(
            interface=status["interface"],
            status=status["status"],
            active_peers=status["active_peers"],
            uptime=status.get("uptime"),
            timestamp=status["timestamp"],
        )
    except Exception as e:
        logger.error(f"Failed to get status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/wireguard/status", response_model=schemas.WireGuardStatusResponse)
async def get_wireguard_status():
    """Get detailed WireGuard peers info."""
    try:
        peers_data = wg_manager.get_peers()
        peers = [schemas.WireGuardPeer(**p) for p in peers_data]
        return schemas.WireGuardStatusResponse(
            interface=wg_manager.interface, peers=peers
        )
    except Exception as e:
        logger.error(f"Failed to get wireguard status: {e}")
        raise HTTPException(status_code=500, detail=str(e))
