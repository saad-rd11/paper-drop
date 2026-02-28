"""RAG engine: retrieval + context assembly + generation."""

import json
import google.generativeai as genai
from config import (
    TOP_K,
    SIMILARITY_THRESHOLD,
    RECENT_MESSAGE_WINDOW,
    get_supabase,
    configure_genai,
)

SYSTEM_PROMPT = (
    "You are PaperDrop, a study assistant. Answer using ONLY the "
    "provided document context. Cite sources as [Page X]. "
    "If the context doesn't cover the question, say so. "
    "Be concise and use markdown formatting."
)


# ── Vector Search ────────────────────────────────────────────


def vector_search(workspace_id: str, query_embedding: list[float]) -> list[dict]:
    """Find top-K similar chunks in a workspace via pgvector."""
    supabase = get_supabase()
    # Use Supabase RPC for vector similarity search
    result = supabase.rpc(
        "match_chunks",
        {
            "query_embedding": query_embedding,
            "match_workspace_id": workspace_id,
            "match_threshold": SIMILARITY_THRESHOLD,
            "match_count": TOP_K,
        },
    ).execute()

    return result.data or []


# ── Context Engineering ──────────────────────────────────────


def _compress_history(messages: list[dict]) -> str:
    """Template-based compression of old messages into a summary."""
    topics = set()
    pages = set()

    for msg in messages:
        if msg["role"] == "user":
            topics.add(msg["content"][:80])
        if msg["role"] == "assistant":
            sources = msg.get("sources") or []
            if isinstance(sources, str):
                try:
                    sources = json.loads(sources)
                except (json.JSONDecodeError, TypeError):
                    sources = []
            for ref in sources:
                if isinstance(ref, dict):
                    pages.add(f"{ref.get('doc', '?')} p.{ref.get('page', '?')}")

    parts = []
    if topics:
        parts.append(f"Topics discussed: {'; '.join(list(topics)[:5])}")
    if pages:
        parts.append(f"Sources referenced: {', '.join(list(pages)[:10])}")
    return ". ".join(parts) if parts else ""


def _rewrite_query(user_message: str, recent: list[dict]) -> str:
    """Make a follow-up query self-contained for better embedding."""
    if len(recent) < 2:
        return user_message
    last_answer = recent[-1].get("content", "")[:200]
    return f"{last_answer} {user_message}"


def _format_chunks(chunks: list[dict]) -> str:
    """Format retrieved chunks into a context string."""
    parts = []
    for c in chunks:
        doc_name = c.get("file_name", "document")
        page = c.get("page", "?")
        content = c.get("content", "")
        parts.append(f"[{doc_name}, Page {page}]\n{content}")
    return "\n\n---\n\n".join(parts)


def build_context(
    workspace_id: str,
    user_message: str,
    chat_history: list[dict],
    summary: str | None,
    query_embedding: list[float],
) -> tuple[list[dict], str, list[dict]]:
    """
    Assemble the Gemini prompt using the 5-layer context strategy.

    Returns: (messages_for_gemini, updated_summary, retrieved_chunks)
    """
    updated_summary = summary or ""
    window = RECENT_MESSAGE_WINDOW

    # Split into old (compress) and recent (keep verbatim)
    if len(chat_history) > window:
        old_msgs = chat_history[:-window]
        recent_msgs = chat_history[-window:]
        updated_summary = _compress_history(old_msgs)
    else:
        recent_msgs = chat_history

    # Retrieve relevant chunks
    chunks = vector_search(workspace_id, query_embedding)

    # Assemble messages for Gemini
    system_parts = SYSTEM_PROMPT
    if updated_summary:
        system_parts += f"\n\nPrior conversation context: {updated_summary}"

    messages = []

    # Add recent conversation turns
    for msg in recent_msgs:
        role = "user" if msg["role"] == "user" else "model"
        messages.append({"role": role, "parts": [msg["content"]]})

    # Final message: context + question
    ctx = _format_chunks(chunks)
    final_msg = f"Document context:\n{ctx}\n\nQuestion: {user_message}"
    messages.append({"role": "user", "parts": [final_msg]})

    return messages, updated_summary, chunks


# ── Chat ─────────────────────────────────────────────────────


def chat(workspace_id: str, user_message: str) -> dict:
    """
    Full RAG chat pipeline:
    1. Load history + summary
    2. Rewrite query for retrieval
    3. Build context with 5-layer strategy
    4. Generate response with Gemini
    5. Save messages to DB
    6. Return response + sources
    """
    from services.embedder import embed_query

    supabase = get_supabase()

    # 1. Load chat history and summary
    history_rows = (
        supabase.table("chat_messages")
        .select("*")
        .eq("workspace_id", workspace_id)
        .order("created_at")
        .execute()
    )
    chat_history = history_rows.data or []

    workspace_row = (
        supabase.table("workspaces")
        .select("chat_summary")
        .eq("id", workspace_id)
        .single()
        .execute()
    )
    summary = workspace_row.data.get("chat_summary")

    # 2. Rewrite query for better retrieval
    recent = chat_history[-RECENT_MESSAGE_WINDOW:]
    search_query = _rewrite_query(user_message, recent)
    query_embedding = embed_query(search_query)

    # 3. Build context
    messages, updated_summary, chunks = build_context(
        workspace_id,
        user_message,
        chat_history,
        summary,
        query_embedding,
    )

    # 4. Generate response
    configure_genai()
    model = genai.GenerativeModel(
        "gemini-1.5-flash",
        system_instruction=SYSTEM_PROMPT,
    )
    response = model.generate_content(messages)
    reply = response.text

    # 5. Build source citations
    sources = []
    seen = set()
    for c in chunks:
        key = (c.get("file_name", ""), c.get("page", 0))
        if key not in seen:
            sources.append({"doc": key[0], "page": key[1]})
            seen.add(key)

    # 6. Save both messages to DB
    supabase.table("chat_messages").insert(
        {
            "workspace_id": workspace_id,
            "role": "user",
            "content": user_message,
            "sources": [],
        }
    ).execute()

    supabase.table("chat_messages").insert(
        {
            "workspace_id": workspace_id,
            "role": "assistant",
            "content": reply,
            "sources": sources,
        }
    ).execute()

    # 7. Update summary if changed
    if updated_summary != (summary or ""):
        supabase.table("workspaces").update({"chat_summary": updated_summary}).eq(
            "id", workspace_id
        ).execute()

    return {"reply": reply, "sources": sources}
