"""Text chunking for RAG ingestion."""

from config import CHUNK_SIZE, CHUNK_OVERLAP


def _token_count(text: str) -> int:
    """Approximate token count (1 token ~ 4 chars for English)."""
    return len(text) // 4


def _get_last_n_tokens(text: str, n: int) -> str:
    """Get approximately the last n tokens of text."""
    char_count = n * 4
    return text[-char_count:] if len(text) > char_count else text


def chunk_text(
    pages: list[dict],
    chunk_size: int = CHUNK_SIZE,
    overlap: int = CHUNK_OVERLAP,
) -> list[dict]:
    """
    Split extracted pages into chunks for embedding.

    Strategy:
    - Split by paragraphs (preserve semantic boundaries)
    - Merge small paragraphs until ~chunk_size tokens
    - 50-token overlap between consecutive chunks
    - Track page number in metadata

    Returns: [{"content": "...", "metadata": {"page": 3}}, ...]
    """
    chunks = []
    current_chunk = ""
    current_page = pages[0]["page"] if pages else 1

    for page in pages:
        paragraphs = page["text"].split("\n\n")
        for para in paragraphs:
            para = para.strip()
            if not para:
                continue

            if _token_count(current_chunk + para) < chunk_size:
                current_chunk += para + "\n\n"
            else:
                # Save current chunk if non-empty
                if current_chunk.strip():
                    chunks.append(
                        {
                            "content": current_chunk.strip(),
                            "metadata": {"page": current_page},
                        }
                    )

                # Start new chunk with overlap from previous
                overlap_text = _get_last_n_tokens(current_chunk, overlap)
                current_chunk = overlap_text + para + "\n\n"
                current_page = page["page"]

    # Don't forget the last chunk
    if current_chunk.strip():
        chunks.append(
            {
                "content": current_chunk.strip(),
                "metadata": {"page": current_page},
            }
        )

    return chunks
