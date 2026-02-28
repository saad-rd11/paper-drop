"""Chat router: RAG-powered conversational Q&A."""

from fastapi import APIRouter, HTTPException
from models.schemas import ChatRequest
from services.rag import chat as rag_chat

router = APIRouter()


@router.post("/chat")
async def chat(req: ChatRequest):
    """
    RAG chat endpoint.
    1. Loads chat history + summary from DB
    2. Rewrites query for follow-up context
    3. Embeds query, retrieves relevant chunks (pgvector)
    4. Builds 5-layer context window
    5. Generates response with Gemini
    6. Saves messages + updates summary
    """
    try:
        result = rag_chat(req.workspace_id, req.message)
        return result
    except Exception as e:
        raise HTTPException(500, f"Chat error: {str(e)}")
