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
    DATABASE_URL: str = os.getenv("DATABASE_URL", "")

    # Security & Auth
    JWT_ACCESS_SECRET: str = os.getenv("JWT_ACCESS_SECRET", "")
    ADMIN_EMAIL: str = os.getenv("ADMIN_EMAIL", "").strip().lower()

    # AI Models & Keys
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    DEFAULT_AI_MODEL: str = os.getenv("AI_MODEL", "gemini-flash-lite-latest")

    # Knowledge / RAG
    KNOWLEDGE_DIR: Path = BASE_DIR / "knowledge" / "documents"

settings = Settings()
