import logging
from typing import Optional, Dict, Any
import jwt
from fastapi import HTTPException, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from backend.ai.config import settings

logger = logging.getLogger("alpha_x_ai.auth")
security = HTTPBearer(auto_error=False)

class AuthenticatedAdmin:
    def __init__(self, id: str, email: str, name: str = "Alpha X Administrator"):
        self.id = id
        self.email = email.strip().lower()
        self.name = name

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "email": self.email,
            "name": self.name,
            "role": "ADMIN",
        }

def verify_admin_token(credentials: Optional[HTTPAuthorizationCredentials] = Security(security)) -> AuthenticatedAdmin:
    """
    Enforces that the caller is an authenticated Master Administrator.
    Validates token signature against JWT_ACCESS_SECRET and ensures the email matches ADMIN_EMAIL.
    """
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token is required for Alpha X AI Coach",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials.strip()

    # Development / test bypass (matches existing Node.js auth logic)
    if settings.DEBUG:
        if token in ("alpha_x_mock_token_for_admin", "local_admin_session_token", "test_admin_token"):
            return AuthenticatedAdmin(
                id="admin_alex_stone",
                email=settings.ADMIN_EMAIL,
                name="Admin Alex",
            )

    try:
        # Decode and verify JWT
        decoded = jwt.decode(
            token,
            settings.JWT_ACCESS_SECRET,
            algorithms=["HS256"],
            options={"verify_exp": True},
        )
        email = (decoded.get("email") or "").strip().lower()
        admin_id = str(decoded.get("id") or "admin_alex_stone")
        admin_name = str(decoded.get("name") or "Alpha X Administrator")

        # Strict Single-Admin Verification
        if email != settings.ADMIN_EMAIL:
            logger.warning(f"Forbidden AI access attempt by non-admin: {email}")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: Alpha X AI Coach is strictly restricted to authorized administrators",
            )

        return AuthenticatedAdmin(id=admin_id, email=email, name=admin_name)

    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin session token has expired. Please re-authenticate.",
        )
    except jwt.InvalidTokenError as e:
        logger.warning(f"Invalid token supplied to AI Coach: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session token is invalid or malformed",
        )

def sanitize_sensitive_data(data: Any) -> Any:
    """
    Recursively strips passwords, hashes, internal tokens, and system secrets from data structures
    prior to ingestion by AI reasoning models or returning to the client.
    """
    if isinstance(data, dict):
        sanitized = {}
        for k, v in data.items():
            k_lower = k.lower()
            if any(secret_key in k_lower for secret_key in ("password", "passwordhash", "secret", "token", "hash")):
                continue
            sanitized[k] = sanitize_sensitive_data(v)
        return sanitized
    elif isinstance(data, list):
        return [sanitize_sensitive_data(item) for item in data]
    return data
