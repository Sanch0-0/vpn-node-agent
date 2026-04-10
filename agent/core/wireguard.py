import subprocess
from datetime import datetime
from typing import List, Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)


class WireGuardManager:
    def __init__(self, interface: str = "wg0"):
        self.interface = interface

    def _run_wg_command(self, args: List[str]) -> str:
        cmd = ["wg"] + args
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True,
                timeout=5,
            )
            return result.stdout
        except subprocess.CalledProcessError as e:
            logger.error(f"wg command failed: {e.stderr}")
            raise RuntimeError(f"WireGuard command error: {e.stderr}")

    def add_peer(
        self, public_key: str, allowed_ips: List[str], peer_id: Optional[str] = None
    ) -> None:
        args = [
            "set",
            self.interface,
            "peer",
            public_key,
            "allowed-ips",
            ",".join(allowed_ips),
            "persistent-keepalive",
            "25",
        ]
        # NOTE: keepalive-25 fixes NAT timeout
        self._run_wg_command(args)

        log_msg = f"Peer {public_key} added with allowed IPs {allowed_ips}"
        if peer_id:
            log_msg += f" (peer_id: {peer_id})"

        logger.info(log_msg)

    def remove_peer(self, public_key: str) -> None:
        args = ["set", self.interface, "peer", public_key, "remove"]
        self._run_wg_command(args)
        logger.info(f"Peer {public_key} removed")

    def get_status(self) -> Dict[str, Any]:
        try:
            output = self._run_wg_command(["show", self.interface, "dump"])
        except RuntimeError:
            return {
                "interface": self.interface,
                "status": "down",
                "active_peers": 0,
                "timestamp": datetime.utcnow(),
            }

        lines = output.strip().split("\n")

        if len(lines) < 2:
            peer_count = 0
        else:
            peer_count = len(lines) - 1  # first line - interface, others - peers

        return {
            "interface": self.interface,
            "status": "up",
            "active_peers": peer_count,
            "timestamp": datetime.utcnow(),
        }

    def get_peers(self) -> List[Dict[str, Any]]:
        output = self._run_wg_command(["show", self.interface, "dump"])
        lines = output.strip().split("\n")
        if len(lines) < 2:
            return []
        peers = []
        for line in lines[1:]:
            parts = line.split("\t")
            if len(parts) < 7:
                continue
            # NOTE: It saves from partial wg output

            public_key = parts[0]
            endpoint = parts[1] if parts[1] != "(none)" else None
            allowed_ips = parts[3].split(",") if parts[3] else []
            last_handshake_str = parts[4]
            transfer_rx = int(parts[5])
            transfer_tx = int(parts[6])

            last_handshake = None
            if last_handshake_str and last_handshake_str != "0":
                try:
                    last_handshake = datetime.utcfromtimestamp(int(last_handshake_str))
                except Exception:
                    pass

            peers.append(
                {
                    "public_key": public_key,
                    "endpoint": endpoint,
                    "allowed_ips": allowed_ips,
                    "last_handshake": last_handshake,
                    "transfer_rx": transfer_rx,
                    "transfer_tx": transfer_tx,
                }
            )
        return peers
