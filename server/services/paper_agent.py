"""Past Paper Agent: analysis + practice paper generation."""

import json
import google.generativeai as genai
from config import get_supabase, configure_genai


# ── Analysis ─────────────────────────────────────────────────

ANALYSIS_PROMPT = """You are an expert academic exam analyst.
Analyze the following past examination papers and extract structured patterns.

Past Papers:
---
{papers_text}
---

Return a JSON object (no markdown fences, raw JSON only) with these fields:
- total_marks: typical total marks (number)
- duration: typical exam duration (string)
- sections: array of {{name, question_count, marks_each, topics}}
- topic_frequency: object mapping topic name to appearance count
- difficulty_distribution: {{easy: percent, medium: percent, hard: percent}}
- recurring_patterns: array of observation strings
- commonly_tested_concepts: array of concept strings
- question_types: array of question type strings

Be precise. Base analysis ONLY on the provided papers."""


def analyze_past_papers(workspace_id: str) -> dict:
    """
    Analyze all past papers in a workspace.
    Returns structured analysis as a dict.
    """
    supabase = get_supabase()

    # Get all documents marked as past papers
    docs = (
        supabase.table("documents")
        .select("id, file_name")
        .eq("workspace_id", workspace_id)
        .eq("is_past_paper", True)
        .execute()
    )

    if not docs.data:
        raise ValueError(
            "No past papers found. Upload and mark documents as past papers first."
        )

    # Get all chunks for these documents (full text reconstruction)
    doc_ids = [d["id"] for d in docs.data]
    all_text_parts = []

    for doc in docs.data:
        chunks = (
            supabase.table("document_chunks")
            .select("content, chunk_index")
            .eq("document_id", doc["id"])
            .order("chunk_index")
            .execute()
        )

        if chunks.data:
            doc_text = "\n".join(c["content"] for c in chunks.data)
            all_text_parts.append(f"=== {doc['file_name']} ===\n{doc_text}")

    if not all_text_parts:
        raise ValueError(
            "Past papers have not been processed yet. Please wait for processing to complete."
        )

    papers_text = "\n\n".join(all_text_parts)

    # Send to Gemini for analysis
    configure_genai()
    model = genai.GenerativeModel("models/gemini-2.5-flash")
    prompt = ANALYSIS_PROMPT.format(papers_text=papers_text)
    response = model.generate_content(prompt)

    # Parse JSON from response
    text = response.text.strip()
    # Strip markdown code fences if present
    if text.startswith("```"):
        text = text.split("\n", 1)[1]
        text = text.rsplit("```", 1)[0]

    analysis = json.loads(text)
    return analysis


# ── Generation ───────────────────────────────────────────────

GENERATION_PROMPT = """You are an expert exam paper creator.
Generate a realistic practice examination paper based on the
analysis of past papers and the study material provided.

Past Paper Analysis:
---
{analysis_json}
---

Study Material (for content accuracy):
---
{study_chunks}
---

Requirements:
1. Follow the EXACT structure from the analysis (same sections,
   same number of questions, same marks distribution)
2. Cover topics proportional to their frequency in past papers
3. Match the difficulty distribution
4. Create ORIGINAL questions (do not copy from past papers)
5. Base question content on the study material provided
6. Include mark allocations for each question
7. Include a suggested time allocation
8. Add a title like "Practice Examination Paper - [Subject]"

Format the paper in clean markdown with clear section headers."""


def generate_paper(workspace_id: str, analysis: dict) -> dict:
    """
    Generate a practice paper based on analysis and study material.
    Returns: {paper_id, title, content}
    """
    supabase = get_supabase()

    # Get study material chunks (non-past-paper documents)
    study_docs = (
        supabase.table("documents")
        .select("id")
        .eq("workspace_id", workspace_id)
        .eq("is_past_paper", False)
        .execute()
    )

    study_chunks_text = ""
    if study_docs.data:
        doc_ids = [d["id"] for d in study_docs.data]
        # Get a sample of chunks from study material for context
        for doc_id in doc_ids[:5]:  # limit to 5 docs
            chunks = (
                supabase.table("document_chunks")
                .select("content")
                .eq("document_id", doc_id)
                .limit(10)
                .execute()
            )
            if chunks.data:
                study_chunks_text += "\n".join(c["content"] for c in chunks.data)
                study_chunks_text += "\n\n"

    if not study_chunks_text:
        study_chunks_text = "(No study material available. Generate questions based on the topics in the analysis.)"

    # Generate with Gemini
    configure_genai()
    model = genai.GenerativeModel("models/gemini-2.5-flash")
    prompt = GENERATION_PROMPT.format(
        analysis_json=json.dumps(analysis, indent=2),
        study_chunks=study_chunks_text[:8000],  # cap context size
    )
    response = model.generate_content(prompt)
    content = response.text

    # Extract title from first line
    lines = content.strip().split("\n")
    title = lines[0].strip("# ").strip() if lines else "Practice Paper"

    # Save to database
    result = (
        supabase.table("generated_papers")
        .insert(
            {
                "workspace_id": workspace_id,
                "title": title,
                "content": content,
                "analysis": analysis,
            }
        )
        .select()
        .execute()
    )

    paper = result.data[0]
    return {
        "paper_id": paper["id"],
        "title": title,
        "content": content,
    }
