import os
from pathlib import Path
from dotenv import load_dotenv

# Locate and load the backend/.env file
BASE_DIR = Path(__file__).resolve().parent
ENV_PATH = BASE_DIR.parent / ".env"
if ENV_PATH.exists():
    load_dotenv(dotenv_path=ENV_PATH)
else:
    load_dotenv()

class Settings:
    # Server
    HOST: str = os.getenv("AI_HOST", "0.0.0.0")
    PORT: int = int(os.getenv("AI_PORT", "8000"))
    ENVIRONMENT: str = os.getenv("NODE_ENV", "development")
    DEBUG: bool = ENVIRONMENT != "production"

    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql://neondb_owner:npg_GCMBSVF1Z3fJ@ep-wispy-scene-a5yzabm1-pooler.us-east-2.aws.neon.tech/alpha-x-mobile-db?sslmode=require"
    )

    # Security & Auth
    JWT_ACCESS_SECRET: str = os.getenv("JWT_ACCESS_SECRET", "alpha_x_dev_access_secret_key_change_in_production_32_chars")
    ADMIN_EMAIL: str = os.getenv("ADMIN_EMAIL", "fitsundar6@gmail.com").strip().lower()

    # AI Models & Keys
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    DEFAULT_AI_MODEL: str = os.getenv("AI_MODEL", "gpt-4o-mini")

    # Knowledge / RAG
    KNOWLEDGE_DIR: Path = BASE_DIR / "knowledge" / "documents"

settings = Settings()
