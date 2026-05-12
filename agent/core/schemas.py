from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# === PEER CREATE ===
class AgentAddPeerRequest(BaseModel):
    peer_id: Optional[str] = None
    public_key: str
    allowed_ips: List[str]


class AgentAddPeerResponse(BaseModel):
    success: bool
    message: Optional[str] = None


# === PEER DELETE ===
class AgentRemovePeerResponse(BaseModel):
    success: bool
    message: Optional[str] = None


# === NODE STATUS ===
class AgentStatusResponse(BaseModel):
    status: str
    active_peers: int
    interface: str
    uptime: Optional[int] = None
    timestamp: datetime


class AgentMetricsResponse(BaseModel):
    cpu_percent: float
    memory_percent: float
    transfer_rx_bytes: int
    transfer_tx_bytes: int
    active_peers: int
    timestamp: datetime


# === WIREGUARD PEER INFO ===
class WireGuardPeer(BaseModel):
    public_key: str
    endpoint: Optional[str] = None
    allowed_ips: List[str]
    last_handshake: Optional[datetime]
    transfer_rx: int
    transfer_tx: int


class WireGuardStatusResponse(BaseModel):
    interface: str
    peers: List[WireGuardPeer]
