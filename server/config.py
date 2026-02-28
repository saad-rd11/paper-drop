import os
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")  # service role key for backend
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

# Lazy Supabase client singleton — avoids crash on import when env vars are empty
_supabase_client = None


def get_supabase():
    """Return a cached Supabase client, created on first call."""
    global _supabase_client
    if _supabase_client is None:
        from supabase import create_client

        if not SUPABASE_URL or not SUPABASE_KEY:
            raise RuntimeError(
                "SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in server/.env"
            )
        _supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)
    return _supabase_client


# Lazy Gemini configuration — avoids crash on import when key is empty
_genai_configured = False


def configure_genai():
    """Configure Gemini API on first call."""
    global _genai_configured
    if not _genai_configured:
        import google.generativeai as genai

        if not GEMINI_API_KEY:
            raise RuntimeError("GEMINI_API_KEY must be set in server/.env")
        genai.configure(api_key=GEMINI_API_KEY)
        _genai_configured = True


# Storage
PDF_BUCKET = "pdfs"

# RAG
CHUNK_SIZE = 500  # target tokens per chunk
CHUNK_OVERLAP = 50  # overlap tokens between chunks
TOP_K = 5  # chunks retrieved per query
SIMILARITY_THRESHOLD = 0.3

# Context window
RECENT_MESSAGE_WINDOW = 6  # messages kept verbatim
