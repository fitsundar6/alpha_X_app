import logging
from contextlib import contextmanager
from typing import Generator, Any, Dict, List, Optional
import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool
from backend.ai.config import settings

logger = logging.getLogger("alpha_x_ai.database")

# Initialize global connection pool
_pool: Optional[ConnectionPool] = None

def get_connection_pool() -> ConnectionPool:
    global _pool
    if _pool is None:
        logger.info("Initializing Alpha X AI PostgreSQL Connection Pool...")
        _pool = ConnectionPool(
            conninfo=settings.DATABASE_URL,
            min_size=2,
            max_size=15,
            kwargs={"row_factory": dict_row},
            open=True,
        )
    return _pool

def close_connection_pool():
    global _pool
    if _pool is not None:
        logger.info("Closing Alpha X AI PostgreSQL Connection Pool...")
        _pool.close()
        _pool = None

@contextmanager
def get_db_cursor() -> Generator[psycopg.Cursor, None, None]:
    """
    Context manager yielding a psycopg dictionary cursor from the connection pool.
    Automatically commits on normal completion or rolls back on exception.
    """
    pool = get_connection_pool()
    with pool.connection() as conn:
        with conn.cursor() as cur:
            try:
                yield cur
                conn.commit()
            except Exception as e:
                conn.rollback()
                logger.error(f"Database error during transaction: {e}")
                raise

def init_ai_database_tables():
    """
    Idempotently ensures all required AI tables and indices exist in the PostgreSQL database.
    Matches Prisma schema definitions and extends with memory and knowledge indices.
    """
    ddl = """
    -- 1. AI Conversations
    CREATE TABLE IF NOT EXISTS ai_conversations (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "adminId" TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT 'Alpha X AI Session',
        "activeClientId" TEXT,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_ai_conversations_admin_id ON ai_conversations("adminId");
    CREATE INDEX IF NOT EXISTS idx_ai_conversations_active_client_id ON ai_conversations("activeClientId");

    -- 2. AI Messages
    CREATE TABLE IF NOT EXISTS ai_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "conversationId" UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
        sender TEXT NOT NULL,
        content TEXT NOT NULL,
        intent TEXT,
        "metadataJson" TEXT,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation_id ON ai_messages("conversationId");

    -- 3. AI Proposals
    CREATE TABLE IF NOT EXISTS ai_proposals (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "conversationId" UUID REFERENCES ai_conversations(id) ON DELETE SET NULL,
        "clientProfileId" TEXT NOT NULL,
        "clientId" TEXT,
        "clientName" TEXT NOT NULL,
        "proposalType" TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        reason TEXT NOT NULL,
        "currentDataJson" TEXT,
        "proposedDataJson" TEXT NOT NULL,
        "finalDataJson" TEXT,
        "approvedById" TEXT,
        "approvedByName" TEXT,
        "approvedAt" TIMESTAMP WITH TIME ZONE,
        "rejectedById" TEXT,
        "rejectedAt" TIMESTAMP WITH TIME ZONE,
        "rejectionReason" TEXT,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_ai_proposals_client_profile_id ON ai_proposals("clientProfileId");
    CREATE INDEX IF NOT EXISTS idx_ai_proposals_status ON ai_proposals(status);
    CREATE INDEX IF NOT EXISTS idx_ai_proposals_type ON ai_proposals("proposalType");

    -- 4. AI Audit Logs
    CREATE TABLE IF NOT EXISTS ai_audit_logs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "adminId" TEXT NOT NULL,
        "adminName" TEXT,
        "clientId" TEXT,
        "clientName" TEXT,
        action TEXT NOT NULL,
        details TEXT NOT NULL,
        "metadataJson" TEXT,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_ai_audit_logs_admin_id ON ai_audit_logs("adminId");
    CREATE INDEX IF NOT EXISTS idx_ai_audit_logs_client_id ON ai_audit_logs("clientId");
    CREATE INDEX IF NOT EXISTS idx_ai_audit_logs_created_at ON ai_audit_logs("createdAt");

    -- 5. AI Memory (Controlled structured preferences & past feedback)
    CREATE TABLE IF NOT EXISTS ai_memories (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "clientId" TEXT,
        "clientProfileId" TEXT,
        category TEXT NOT NULL, -- 'ADMIN_PREFERENCE', 'EXERCISE_PREFERENCE', 'RECOVERY_NOTE', 'NUTRITION_CONSTRAINT'
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        "recordedById" TEXT NOT NULL,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_ai_memories_client_id ON ai_memories("clientId");
    CREATE INDEX IF NOT EXISTS idx_ai_memories_category ON ai_memories(category);

    -- 6. AI Knowledge Chunks (For Local RAG storage & keyword/vector retrieval)
    CREATE TABLE IF NOT EXISTS ai_knowledge_chunks (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        category TEXT NOT NULL, -- 'EXERCISE', 'TRAINING', 'NUTRITION', 'COACHING', 'POLICY'
        topic TEXT NOT NULL,
        source TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        "metadataJson" TEXT,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_ai_knowledge_chunks_category ON ai_knowledge_chunks(category);
    CREATE INDEX IF NOT EXISTS idx_ai_knowledge_chunks_topic ON ai_knowledge_chunks(topic);

    -- 7. AI Evaluation Records
    CREATE TABLE IF NOT EXISTS ai_evaluations (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "testCaseName" TEXT NOT NULL,
        "inputPrompt" TEXT NOT NULL,
        "detectedIntent" TEXT NOT NULL,
        "dataRetrievalAccuracy" FLOAT NOT NULL,
        "calculationAccuracy" FLOAT NOT NULL,
        "hallucinationDetected" BOOLEAN NOT NULL DEFAULT FALSE,
        "latencyMs" INT NOT NULL,
        passed BOOLEAN NOT NULL,
        notes TEXT,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );
    """
    logger.info("Verifying and ensuring AI database tables...")
    with get_db_cursor() as cur:
        cur.execute(ddl)
    logger.info("AI database tables verified successfully.")
