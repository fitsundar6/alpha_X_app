import json
import logging
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query, status
from backend.ai.safety.auth import verify_admin_token, AuthenticatedAdmin
from backend.ai.controller.ai_controller import ai_controller
from backend.ai.tools.alpha_x_tools import alpha_x_tools
from backend.ai.memory.memory_manager import memory_manager
from backend.ai.database.connection import get_db_cursor
from backend.ai.models.schemas import (
    AiCoachChatRequest,
    AiCoachChatResponse,
    DailySummaryResponse,
    ProposalActionRequest,
)

logger = logging.getLogger("alpha_x_ai.api")
router = APIRouter(prefix="/api/v1/ai", tags=["Alpha X AI Coach"])

@router.get("/health")
def ai_health_check():
    """Health check endpoint for the Python AI Backend."""
    return {
        "status": "healthy",
        "service": "Alpha X Python AI Coach Backend",
        "version": "1.0.0",
        "engine": "FastAPI + PostgreSQL + RAG",
    }

@router.post("/chat", response_model=AiCoachChatResponse)
def handle_chat_message(
    req: AiCoachChatRequest,
    admin: AuthenticatedAdmin = Depends(verify_admin_token),
):
    """
    Primary natural language endpoint for Admin natural interaction with the AI Coach.
    Secured by Admin Bearer token.
    """
    try:
        response = ai_controller.handle_admin_message(req, admin_id=admin.id, admin_name=admin.name)
        return response
    except Exception as e:
        logger.error(f"Error handling AI chat message: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI processing error: {str(e)}",
        )

@router.get("/summary", response_model=DailySummaryResponse)
def get_daily_summary(
    date: Optional[str] = Query(None, description="Target date (YYYY-MM-DD)"),
    admin: AuthenticatedAdmin = Depends(verify_admin_token),
):
    """
    Retrieves Today's operational intelligence summary for Admin dashboard cards.
    """
    try:
        summary = alpha_x_tools.get_daily_gym_summary(date)
        return DailySummaryResponse(
            title="Today's AI Summary",
            date=summary["date"],
            workoutsCompleted=summary["workoutsCompletedToday"],
            foodLogsRecorded=summary["foodLogsRecordedToday"],
            weeklyCheckInsPending=summary["weeklyCheckInsPending"],
            clientsNeedReview=summary["clientsNeedingReviewCount"],
            totalActiveClients=summary["totalActiveClients"],
            attentionItems=summary["attentionItems"],
        )
    except Exception as e:
        logger.error(f"Error retrieving AI summary: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to retrieve AI summary")

@router.get("/proposals")
def get_proposals(
    status: Optional[str] = Query(None),
    clientId: Optional[str] = Query(None),
    type: Optional[str] = Query(None),
    admin: AuthenticatedAdmin = Depends(verify_admin_token),
):
    """Retrieves AI proposals (filtered by status, clientId, or type)."""
    conditions = []
    params: Dict[str, Any] = {}

    if status:
        conditions.append("status = %(status)s")
        params["status"] = status.upper()
    if clientId:
        conditions.append("(\"clientId\" = %(client_id)s OR \"clientProfileId\" = %(client_id)s)")
        params["client_id"] = clientId
    if type:
        conditions.append("\"proposalType\" = %(type)s")
        params["type"] = type.upper()

    where_clause = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    query = f"""
    SELECT 
        id, "conversationId", "clientProfileId", "clientId", "clientName",
        "proposalType", status, title, summary, reason,
        "currentDataJson", "proposedDataJson", "finalDataJson",
        "approvedById", "approvedByName", "approvedAt",
        "rejectedById", "rejectedAt", "rejectionReason",
        "createdAt", "updatedAt"
    FROM ai_proposals
    {where_clause}
    ORDER BY "createdAt" DESC
    LIMIT 50;
    """
    with get_db_cursor() as cur:
        cur.execute(query, params)
        proposals = cur.fetchall()

        parsed = []
        for p in proposals:
            payload = None
            current = None
            try:
                payload = json.loads(p.get("finalDataJson") or p.get("proposedDataJson") or "{}")
            except Exception:
                payload = {}
            try:
                if p.get("currentDataJson"):
                    current = json.loads(p["currentDataJson"])
            except Exception:
                current = None

            parsed.append({
                "id": str(p["id"]),
                "conversationId": str(p["conversationId"]) if p.get("conversationId") else None,
                "clientProfileId": p["clientProfileId"],
                "clientId": p.get("clientId"),
                "clientName": p["clientName"],
                "proposalType": p["proposalType"],
                "status": p["status"],
                "title": p["title"],
                "summary": p["summary"],
                "reason": p["reason"],
                "currentData": current,
                "proposedData": payload,
                "approvedByName": p.get("approvedByName"),
                "approvedAt": p["approvedAt"].isoformat() if p.get("approvedAt") else None,
                "rejectedAt": p["rejectedAt"].isoformat() if p.get("rejectedAt") else None,
                "rejectionReason": p.get("rejectionReason"),
                "createdAt": p["createdAt"].isoformat() if p.get("createdAt") else None,
            })
        return parsed

@router.post("/proposals/{id}/approve")
def approve_proposal(
    id: str,
    admin: AuthenticatedAdmin = Depends(verify_admin_token),
):
    """
    Approves an AI proposal, updates client plan in database, increments version, and writes audit record.
    """
    try:
        updated = alpha_x_tools.approve_proposal(id, admin_id=admin.id, admin_name=admin.name)
        memory_manager.record_proposal_feedback(
            proposal_id=id,
            action="APPROVED",
            admin_id=admin.id,
            client_id=updated.get("clientId"),
        )
        return {
            "message": "Proposal approved successfully. Active plan updated for athlete.",
            "proposal": updated,
        }
    except Exception as e:
        logger.error(f"Error approving proposal {id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/proposals/{id}/reject")
def reject_proposal(
    id: str,
    req: ProposalActionRequest,
    admin: AuthenticatedAdmin = Depends(verify_admin_token),
):
    """Rejects an AI proposal and records reason in audit log and structured memory."""
    try:
        rejected = alpha_x_tools.reject_proposal(id, admin_id=admin.id, reason=req.reason)
        memory_manager.record_proposal_feedback(
            proposal_id=id,
            action="REJECTED",
            admin_id=admin.id,
            client_id=rejected.get("clientId"),
            reason=req.reason,
        )
        return {
            "message": "Proposal rejected successfully.",
            "proposal": rejected,
        }
    except Exception as e:
        logger.error(f"Error rejecting proposal {id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/proposals/{id}/edit")
def edit_proposal(
    id: str,
    req: ProposalActionRequest,
    admin: AuthenticatedAdmin = Depends(verify_admin_token),
):
    """Saves Admin modifications to an AI proposal before approval."""
    if not req.editedPayload:
        raise HTTPException(status_code=400, detail="Edited payload is required")
    try:
        edited = alpha_x_tools.edit_proposal(id, admin_id=admin.id, edited_payload=req.editedPayload)
        return {
            "message": "Proposal updated with admin modifications.",
            "proposal": edited,
        }
    except Exception as e:
        logger.error(f"Error editing proposal {id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/audit-logs")
def get_audit_logs(
    limit: int = 100,
    admin: AuthenticatedAdmin = Depends(verify_admin_token),
):
    """Retrieves audit trail of all AI queries and Coach approval decisions."""
    with get_db_cursor() as cur:
        cur.execute("""
            SELECT id, "adminId", "adminName", "clientId", "clientName", action, details, "metadataJson", "createdAt"
            FROM ai_audit_logs
            ORDER BY "createdAt" DESC
            LIMIT %(limit)s;
        """, {"limit": limit})
        logs = cur.fetchall()
        for l in logs:
            if l.get("createdAt"):
                l["createdAt"] = l["createdAt"].isoformat()
        return logs
