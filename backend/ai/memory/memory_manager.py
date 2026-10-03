import logging
from typing import Dict, Any, List, Optional
from backend.ai.database.connection import get_db_cursor

logger = logging.getLogger("alpha_x_ai.memory")

class AIMemoryManager:
    """
    Controlled, structured memory layer.
    Stores and audits coaching preferences, past proposal decisions, and client notes.
    Never stores arbitrary, uncontrolled memory.
    """

    def record_memory(
        self,
        category: str,
        key: str,
        value: str,
        recorded_by_id: str,
        client_id: Optional[str] = None,
        client_profile_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Saves a structured preference or past decision."""
        query = """
        INSERT INTO ai_memories (
            "clientId", "clientProfileId", category, key, value, "recordedById", "updatedAt"
        ) VALUES (
            %(client_id)s, %(cp_id)s, %(cat)s, %(key)s, %(val)s, %(rec_id)s, NOW()
        ) RETURNING *;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {
                "client_id": client_id,
                "cp_id": client_profile_id,
                "cat": category.upper(),
                "key": key,
                "val": value,
                "rec_id": recorded_by_id,
            })
            return cur.fetchone()

    def get_client_memories(self, client_id: Optional[str] = None, client_profile_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """Retrieves structured context and preferences relevant to an athlete."""
        if not client_id and not client_profile_id:
            return []

        query = """
        SELECT category, key, value, "createdAt"
        FROM ai_memories
        WHERE "clientId" = %(c_id)s OR "clientProfileId" = %(cp_id)s
        ORDER BY "createdAt" DESC
        LIMIT 10;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"c_id": client_id, "cp_id": client_profile_id})
            return cur.fetchall()

    def record_proposal_feedback(
        self, proposal_id: str, action: str, admin_id: str, client_id: Optional[str], reason: Optional[str] = None
    ):
        """Records feedback when an Admin approves or rejects a proposal to improve future recommendations."""
        key = f"PROPOSAL_{proposal_id}_{action}"
        val = f"Action: {action}. Feedback/Reason: {reason or 'Standard decision'}"
        self.record_memory(
            category="PROPOSAL_DECISION",
            key=key,
            value=val,
            recorded_by_id=admin_id,
            client_id=client_id,
        )

memory_manager = AIMemoryManager()
