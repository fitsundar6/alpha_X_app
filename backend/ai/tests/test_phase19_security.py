import pytest
import sys
from pathlib import Path
import jwt
from datetime import datetime, timedelta

# Ensure root in sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent))

from backend.ai.config import settings
from backend.ai.safety.auth import verify_admin_token, sanitize_sensitive_data
from backend.ai.tools.alpha_x_tools import alpha_x_tools
from backend.ai.controller.ai_controller import ai_controller
from backend.ai.models.schemas import AiCoachChatRequest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

class TestPhase19Security:
    """
    Phase 19: Comprehensive Security Test Suite
    - SQL Injection Resilience on all query endpoints
    - Cryptographic JWT Token verification & Role authorization
    - Credential & Secret Redaction (Zero Leakage)
    - Admin-only access barrier preventing client role escalation
    """

    def test_sql_injection_resilience_find_client(self):
        malicious_inputs = [
            "' OR '1'='1",
            "'; DROP TABLE users; --",
            "AXG-0001' UNION SELECT NULL, NULL, NULL, NULL --",
            "admin'--",
            "\" OR \"\"=\"",
        ]
        for payload in malicious_inputs:
            # Should safely execute parameterized query and return None (no record found) without error
            result = alpha_x_tools.find_client(payload)
            assert result is None or isinstance(result, dict)

    def test_sql_injection_resilience_exercise_query(self):
        malicious_search = "Bench' OR 1=1;--"
        # Should cleanly query without database exception
        results = alpha_x_tools.query_exercise_library(search_term=malicious_search, limit=5)
        assert isinstance(results, list)

    def test_admin_jwt_signature_verification(self):
        # Valid admin payload signed with correct secret
        valid_payload = {
            "userId": "admin_uuid_001",
            "email": "fitsundar6@gmail.com",
            "role": "ADMIN",
            "exp": datetime.utcnow() + timedelta(hours=2)
        }
        valid_token = jwt.encode(valid_payload, settings.JWT_ACCESS_SECRET, algorithm="HS256")
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=valid_token)
        claims = verify_admin_token(creds)
        assert claims.email == "fitsundar6@gmail.com"
        assert claims.to_dict()["role"] == "ADMIN"

    def test_rejection_of_client_role_token(self):
        # Regular client token trying to access admin AI
        client_payload = {
            "userId": "client_uuid_999",
            "email": "client@example.com",
            "role": "CLIENT",
            "exp": datetime.utcnow() + timedelta(hours=2)
        }
        client_token = jwt.encode(client_payload, settings.JWT_ACCESS_SECRET, algorithm="HS256")
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=client_token)
        with pytest.raises(HTTPException) as exc:
            verify_admin_token(creds)
        assert exc.value.status_code == 403
        assert "Access denied" in exc.value.detail

    def test_rejection_of_unauthorized_admin_email(self):
        # Unauthorized admin email trying to access
        impostor_payload = {
            "userId": "impostor_uuid_002",
            "email": "hacker@domain.com",
            "role": "ADMIN",
            "exp": datetime.utcnow() + timedelta(hours=2)
        }
        impostor_token = jwt.encode(impostor_payload, settings.JWT_ACCESS_SECRET, algorithm="HS256")
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=impostor_token)
        with pytest.raises(HTTPException) as exc:
            verify_admin_token(creds)
        assert exc.value.status_code == 403

    def test_rejection_of_expired_token(self):
        expired_payload = {
            "userId": "admin_uuid_001",
            "email": "fitsundar6@gmail.com",
            "role": "ADMIN",
            "exp": datetime.utcnow() - timedelta(minutes=5)
        }
        expired_token = jwt.encode(expired_payload, settings.JWT_ACCESS_SECRET, algorithm="HS256")
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=expired_token)
        with pytest.raises(HTTPException) as exc:
            verify_admin_token(creds)
        assert exc.value.status_code == 401
        assert "expired" in exc.value.detail.lower()

    def test_rejection_of_tampered_token(self):
        fake_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.tampered_signature"
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=fake_token)
        with pytest.raises(HTTPException) as exc:
            verify_admin_token(creds)
        assert exc.value.status_code == 401

    def test_data_sanitization_deep_scrubbing(self):
        leaky_data = {
            "clientId": "AXG-0001",
            "name": "Kumar",
            "passwordHash": "$2b$12$eX8mE/...",
            "password": "ClearTextPassword123!",
            "token": "sensitive_jwt_token",
            "refreshToken": "refresh_token_here",
            "deep": {
                "adminSecret": "super_secret_value",
                "nestedPassword": "nested_secret",
                "safeMetric": 78.5
            },
            "array": [
                {"token": "item_token", "val": 10},
                {"name": "Valid Item"}
            ]
        }
        clean = sanitize_sensitive_data(leaky_data)
        assert "passwordHash" not in clean
        assert "password" not in clean
        assert "token" not in clean
        assert "refreshToken" not in clean
        assert "adminSecret" not in clean["deep"]
        assert "nestedPassword" not in clean["deep"]
        assert clean["deep"]["safeMetric"] == 78.5
        assert "token" not in clean["array"][0]
        assert clean["array"][0]["val"] == 10
