"""Gemini embedding service."""

import google.generativeai as genai
from config import configure_genai

EMBEDDING_MODEL = "models/text-embedding-004"


def embed_texts(texts: list[str]) -> list[list[float]]:
    """
    Embed a list of texts using Gemini text-embedding-004.
    Returns list of 768-dim vectors.
    Batches automatically (API supports up to 100 per call).
    """
    configure_genai()
    embeddings = []
    batch_size = 100

    for i in range(0, len(texts), batch_size):
        batch = texts[i : i + batch_size]
        result = genai.embed_content(
            model=EMBEDDING_MODEL,
            content=batch,
            task_type="retrieval_document",
        )
        embeddings.extend(result["embedding"])

    return embeddings


def embed_query(text: str) -> list[float]:
    """Embed a single query for retrieval."""
    configure_genai()
    result = genai.embed_content(
        model=EMBEDDING_MODEL,
        content=text,
        task_type="retrieval_query",
    )
    return result["embedding"]
