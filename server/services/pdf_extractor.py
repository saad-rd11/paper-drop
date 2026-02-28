"""PDF text extraction using PyMuPDF."""

import fitz  # pymupdf


def extract_text(pdf_bytes: bytes) -> list[dict]:
    """
    Extract text from PDF bytes, page by page.
    Returns: [{"page": 1, "text": "..."}, ...]
    """
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    pages = []
    for i, page in enumerate(doc):
        text = page.get_text("text")
        if text.strip():
            pages.append({"page": i + 1, "text": text})
    doc.close()

    if not pages:
        raise ValueError("No extractable text found. PDF may be scanned/image-only.")

    return pages
