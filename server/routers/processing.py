"""PDF processing router: extract, chunk, embed, store."""

import json
from fastapi import APIRouter, HTTPException
from config import get_supabase, PDF_BUCKET
from models.schemas import ProcessPdfRequest
from services.pdf_extractor import extract_text
from services.chunker import chunk_text
from services.embedder import embed_texts

router = APIRouter()


@router.post("/process-pdf")
async def process_pdf(req: ProcessPdfRequest):
    """
    Full ingestion pipeline:
    1. Download PDF from Supabase Storage
    2. Extract text (PyMuPDF)
    3. Chunk text (~500 tokens, 50 overlap)
    4. Embed chunks (Gemini text-embedding-004)
    5. Store chunks + embeddings in document_chunks
    6. Mark document as processed
    """
    supabase = get_supabase()

    # 1. Get document record
    doc = (
        supabase.table("documents")
        .select("*")
        .eq("id", req.document_id)
        .single()
        .execute()
    )

    if not doc.data:
        raise HTTPException(404, "Document not found")

    storage_path = doc.data["storage_path"]
    if not storage_path:
        raise HTTPException(400, "Document has no storage path")

    # 2. Download PDF bytes
    pdf_bytes = supabase.storage.from_(PDF_BUCKET).download(storage_path)

    # 3. Extract text
    try:
        pages = extract_text(pdf_bytes)
    except ValueError as e:
        raise HTTPException(422, str(e))

    # 4. Chunk
    chunks = chunk_text(pages)
    if not chunks:
        raise HTTPException(422, "No text chunks could be created from this PDF")

    # 5. Embed
    texts = [c["content"] for c in chunks]
    embeddings = embed_texts(texts)

    # 6. Store chunks
    rows = []
    for i, (chunk, embedding) in enumerate(zip(chunks, embeddings)):
        rows.append(
            {
                "document_id": req.document_id,
                "chunk_index": i,
                "content": chunk["content"],
                "embedding": embedding,
                "metadata": chunk["metadata"],
            }
        )

    # Insert in batches of 50
    for i in range(0, len(rows), 50):
        batch = rows[i : i + 50]
        supabase.table("document_chunks").insert(batch).execute()

    # 7. Mark as processed
    supabase.table("documents").update(
        {
            "processed": True,
            "page_count": len(pages),
        }
    ).eq("id", req.document_id).execute()

    return {
        "status": "ok",
        "pages": len(pages),
        "chunks": len(chunks),
    }
