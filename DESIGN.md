# PaperDrop — System Design

> A mobile app where students create workspaces, drop PDFs, chat with them
> using RAG, and use an AI agent that analyzes past papers to generate
> practice exams.

**Stack:** Flutter + Riverpod + Supabase + FastAPI (Python) + Google Gemini

---

## 1. Architecture

```
┌────────────────────────────────────────────┐
│              Flutter Mobile App            │
│                                            │
│   Workspaces ── Documents ── Chat ── Agent │
│        │            │          │        │  │
│        └────────────┴──────────┴────────┘  │
│                     │                      │
│              supabase_flutter              │
│              + dio (HTTP)                  │
└─────────────┬──────────────────────────────┘
              │
              │  REST / Realtime
              ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│        Supabase          │    │    Python Backend        │
│                          │    │    (FastAPI)             │
│  ┌────────────────────┐  │    │                         │
│  │ Postgres + pgvector│◄─┼────┤  /process-pdf           │
│  ├────────────────────┤  │    │  /chat                  │
│  │ Storage (PDFs)     │  │    │  /agent/analyze          │
│  └────────────────────┘  │    │  /agent/generate         │
│                          │    │                         │
└──────────────────────────┘    │  Gemini API             │
                                └─────────────────────────┘
```

**Why this split:**

| Component | Responsibility |
|-----------|---------------|
| Flutter | UI, local state, file picking, navigation |
| Supabase | Persistence (Postgres), file storage (PDFs), pgvector |
| Python backend | PDF processing, embeddings, RAG, agent logic |
| Gemini | Embeddings (`text-embedding-004`), chat (`1.5-flash`), agent (`1.5-pro`) |

No auth required (university project scope). Single-user, all workspaces local.

---

## 2. Data Model

```sql
-- Enable vector similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- ─────────────────────────────────────
-- Workspaces
-- ─────────────────────────────────────
CREATE TABLE workspaces (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         TEXT NOT NULL,
    description  TEXT DEFAULT '',
    chat_summary TEXT,              -- compressed older chat history
    created_at   TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────
-- Documents (uploaded PDFs)
-- ─────────────────────────────────────
CREATE TABLE documents (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id  UUID REFERENCES workspaces(id) ON DELETE CASCADE,
    file_name     TEXT NOT NULL,
    storage_path  TEXT NOT NULL,
    page_count    INT DEFAULT 0,
    is_past_paper BOOLEAN DEFAULT false,
    processed     BOOLEAN DEFAULT false,
    created_at    TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────
-- Document chunks (for RAG retrieval)
-- ─────────────────────────────────────
CREATE TABLE document_chunks (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id  UUID REFERENCES documents(id) ON DELETE CASCADE,
    chunk_index  INT NOT NULL,
    content      TEXT NOT NULL,
    embedding    VECTOR(768),
    metadata     JSONB DEFAULT '{}'    -- { "page": 3 }
);

CREATE INDEX ON document_chunks
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ─────────────────────────────────────
-- Chat messages
-- ─────────────────────────────────────
CREATE TABLE chat_messages (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
    role         TEXT CHECK (role IN ('user', 'assistant')),
    content      TEXT NOT NULL,
    sources      JSONB DEFAULT '[]',   -- [{"doc": "file.pdf", "page": 3}]
    created_at   TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────
-- Generated practice papers
-- ─────────────────────────────────────
CREATE TABLE generated_papers (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
    title        TEXT NOT NULL,
    content      TEXT NOT NULL,         -- markdown
    analysis     JSONB DEFAULT '{}',    -- the analysis that produced this
    created_at   TIMESTAMPTZ DEFAULT now()
);
```

**Storage bucket:** `pdfs` — path pattern: `{workspace_id}/{document_id}.pdf`

---

## 3. Context Engineering

The core design principle: **put the right information in the context window
at the right time, nothing more.**

### 3.1 Context Window Layout

Every Gemini call for chat is assembled from 5 layers:

```
┌─────────────────────────────────────────┐
│  Layer 1: System Prompt      (~200 tok) │  Fixed persona + rules
│  Layer 2: Conversation Summary(~300 tok)│  Compressed older turns
│  Layer 3: Recent Messages   (~1500 tok) │  Last 6 messages verbatim
│  Layer 4: Retrieved Chunks  (~2500 tok) │  Top-5 relevant chunks
│  Layer 5: Current Question     (~50 tok)│  The user's message
├─────────────────────────────────────────┤
│  Total: ~4500 tokens per request        │
└─────────────────────────────────────────┘
```

### 3.2 Multi-Turn Strategy: Sliding Window + Compression

```
Messages 1-6:   (compressed into summary after message 7 arrives)
Messages 7-12:  (kept verbatim as "recent messages")
Message 13:     (current question)
```

**Compression** happens after every 6 messages. Template-based, no extra API call:

```python
def compress_history(messages: list[dict]) -> str:
    """Extract topics and page refs from old messages into a one-liner."""
    topics = set()
    pages = set()
    for msg in messages:
        # Extract topic keywords from assistant answers
        if msg["role"] == "assistant":
            for ref in (msg.get("sources") or []):
                pages.add(f'{ref["doc"]} p.{ref["page"]}')
        # Simple keyword extraction from questions
        if msg["role"] == "user":
            topics.add(msg["content"][:80])

    parts = []
    if topics:
        parts.append(f"Topics discussed: {'; '.join(topics)}")
    if pages:
        parts.append(f"Sources referenced: {', '.join(pages)}")
    return ". ".join(parts) if parts else ""
```

The summary is stored in `workspaces.chat_summary` and updated in-place.
No in-memory session state. The database is the single source of truth.

### 3.3 Query Rewriting for Follow-Ups

Follow-up questions like "What about deletion?" lose meaning without context.
Before embedding, the query is rewritten by concatenating the last exchange:

```python
def rewrite_query(user_message: str, recent: list[dict]) -> str:
    if len(recent) < 2:
        return user_message
    last_answer = recent[-1]["content"][:200]  # trim for embedding
    return f"{last_answer} {user_message}"
```

"What about deletion?" becomes:
"BST stores elements in sorted order... What about deletion?"

This embeds correctly and retrieves BST deletion chunks.

### 3.4 Full Context Assembly

```python
SYSTEM_PROMPT = (
    "You are PaperDrop, a study assistant. Answer using ONLY the "
    "provided document context. Cite sources as [Page X]. "
    "If the context doesn't cover the question, say so."
)
WINDOW = 6  # recent messages kept verbatim

def build_context(workspace_id, user_message, chat_history, summary):
    updated_summary = summary

    # Split history into old (compress) and recent (keep)
    if len(chat_history) > WINDOW:
        old = chat_history[:-WINDOW]
        recent = chat_history[-WINDOW:]
        updated_summary = compress_history(old)
    else:
        recent = chat_history

    # Rewrite query for retrieval
    search_query = rewrite_query(user_message, recent)
    query_embedding = embed(search_query)
    chunks = vector_search(workspace_id, query_embedding, limit=5)

    # Assemble messages for Gemini
    messages = [{"role": "user", "parts": [SYSTEM_PROMPT]}]

    if updated_summary:
        messages[0]["parts"][0] += f"\n\nPrior context: {updated_summary}"

    for msg in recent:
        messages.append({
            "role": msg["role"] if msg["role"] == "user" else "model",
            "parts": [msg["content"]]
        })

    # Final message: chunks + question
    ctx = format_chunks(chunks)
    messages.append({
        "role": "user",
        "parts": [f"Document context:\n{ctx}\n\nQuestion: {user_message}"]
    })

    return messages, updated_summary
```

~50 lines. No frameworks. No LangChain.

### 3.5 Agent Context (Simpler)

The past-paper agent is NOT a conversation. It's two one-shot calls:

```
Analyze: all past paper text  ──► Gemini Pro ──► structured JSON
Generate: analysis + notes chunks ──► Gemini Pro ──► practice paper (markdown)
```

No history management needed. Gemini's 1M-token window handles
multiple full papers in a single prompt.

---

## 4. RAG Pipeline

### 4.1 Ingestion (on PDF upload)

```
PDF ──► PyMuPDF (text per page) ──► Chunker ──► Gemini Embeddings ──► Postgres
```

**Chunking strategy:**
- Target: ~500 tokens per chunk
- Split by paragraphs first (preserve semantic boundaries)
- Merge small paragraphs until hitting the target
- 50-token overlap between consecutive chunks
- Store page number in metadata

```python
def chunk_text(pages: list[dict], target=500, overlap=50) -> list[dict]:
    chunks, current, current_page = [], "", pages[0]["page"]

    for page in pages:
        for para in page["text"].split("\n\n"):
            if token_count(current + para) < target:
                current += para + "\n\n"
            else:
                if current.strip():
                    chunks.append({"content": current.strip(),
                                   "metadata": {"page": current_page}})
                tail = get_last_n_tokens(current, overlap)
                current = tail + para + "\n\n"
                current_page = page["page"]

    if current.strip():
        chunks.append({"content": current.strip(),
                       "metadata": {"page": current_page}})
    return chunks
```

**Embedding:** Gemini `text-embedding-004`, 768 dimensions, batched (100/call).

### 4.2 Retrieval (on chat)

```sql
SELECT
    dc.content,
    dc.metadata,
    d.file_name,
    1 - (dc.embedding <=> $1::vector) AS similarity
FROM document_chunks dc
JOIN documents d ON d.id = dc.document_id
WHERE d.workspace_id = $2
  AND 1 - (dc.embedding <=> $1::vector) > 0.3
ORDER BY dc.embedding <=> $1::vector
LIMIT 5;
```

Cosine similarity, 0.3 threshold to filter noise, top 5 chunks.

### 4.3 Generation

Chunks are formatted and injected into the prompt:

```
[DSA_Notes.pdf, Page 42]
A binary search tree is a data structure where...

[DSA_Notes.pdf, Page 43]
Deletion in BST has three cases...
```

Gemini generates the answer citing page numbers. Response + sources saved to `chat_messages`.

---

## 5. Past Paper Agent

### 5.1 Analysis

Collect all docs with `is_past_paper = true`, reconstruct full text, send to Gemini Pro:

```python
ANALYSIS_PROMPT = """Analyze these past examination papers.
Return a JSON object with:
- total_marks, duration
- sections: [{name, question_count, marks_each, topics}]
- topic_frequency: {topic: count}
- difficulty_distribution: {easy: %, medium: %, hard: %}
- recurring_patterns: [observations]
- commonly_tested_concepts: [concepts]

Past Papers:
---
{papers_text}
---"""
```

Output: structured JSON stored alongside the generated paper.

### 5.2 Generation

Takes the analysis JSON + retrieves chunks from study material (non-past-paper docs):

```python
GENERATION_PROMPT = """Create a practice exam paper that matches
this structure exactly:

Analysis: {analysis_json}

Study material for content accuracy:
{study_chunks}

Requirements:
- Same sections, question counts, and mark allocations as analyzed
- Cover topics proportional to their past frequency
- Original questions (not copied from past papers)
- Include suggested time allocation
- Format in clean markdown"""
```

Output: markdown, saved in `generated_papers`.

---

## 6. API Endpoints (Python Backend)

```
POST /process-pdf
  Body: { document_id, workspace_id }
  → Downloads PDF from Supabase Storage
  → Extracts text, chunks, embeds, stores
  → Updates documents.processed = true

POST /chat
  Body: { workspace_id, message }
  → Loads chat history + summary from DB
  → build_context() → Gemini → save response
  → Returns: { reply, sources }

POST /agent/analyze
  Body: { workspace_id }
  → Loads all past papers, sends to Gemini Pro
  → Returns: { analysis: {...} }

POST /agent/generate
  Body: { workspace_id, analysis }
  → Retrieves study material chunks
  → Gemini Pro generates paper
  → Saves to generated_papers
  → Returns: { paper_id, title, content }
```

---

## 7. Flutter App Structure

```
lib/
├── main.dart                          # Entry, Supabase init
├── app.dart                           # MaterialApp + GoRouter
│
├── config/
│   └── constants.dart                 # Supabase URL, backend URL
│
├── models/
│   ├── workspace.dart                 # Workspace data class
│   ├── document.dart                  # Document data class
│   ├── chat_message.dart              # ChatMessage data class
│   └── generated_paper.dart           # GeneratedPaper data class
│
├── services/
│   ├── supabase_service.dart          # All Supabase DB + Storage ops
│   ├── api_service.dart               # HTTP calls to Python backend
│
├── providers/
│   ├── workspace_provider.dart        # CRUD + list workspaces
│   ├── document_provider.dart         # Upload, list, delete docs
│   ├── chat_provider.dart             # Send message, load history
│   └── agent_provider.dart            # Analyze, generate
│
├── screens/
│   ├── home_screen.dart               # Workspace grid
│   ├── workspace_screen.dart          # Tabs: Documents | Chat | Agent
│   ├── chat_screen.dart               # Chat interface
│   ├── agent_screen.dart              # Analysis + generation UI
│   └── pdf_viewer_screen.dart         # View PDF
│
└── widgets/
    ├── workspace_card.dart
    ├── document_tile.dart
    ├── chat_bubble.dart
    └── upload_sheet.dart
```

### Screen Flow

```
Home (workspace grid)
  │
  ├── [+] Create Workspace
  │
  └── Tap workspace ──► Workspace Screen (3 tabs)
                            │
                            ├── Documents Tab
                            │     ├── Upload PDF (file picker)
                            │     ├── Toggle "past paper" flag
                            │     └── Tap to view PDF
                            │
                            ├── Chat Tab
                            │     ├── Message list (bubbles)
                            │     ├── Source citations (page refs)
                            │     └── Text input + send
                            │
                            └── Agent Tab
                                  ├── "Analyze Past Papers" button
                                  ├── Analysis results (topics, patterns)
                                  ├── "Generate Practice Paper" button
                                  └── Generated paper preview + download
```

### State Management (Riverpod)

```dart
// Workspace list
final workspacesProvider = AsyncNotifierProvider<WorkspacesNotifier, List<Workspace>>(
  WorkspacesNotifier.new,
);

// Documents for a workspace
final documentsProvider = AsyncNotifierProvider.family<DocumentsNotifier, List<Document>, String>(
  DocumentsNotifier.new,
);

// Chat messages for a workspace
final chatProvider = AsyncNotifierProvider.family<ChatNotifier, List<ChatMessage>, String>(
  ChatNotifier.new,
);

// Agent state (analysis result + generated papers)
final agentProvider = AsyncNotifierProvider.family<AgentNotifier, AgentState, String>(
  AgentNotifier.new,
);
```

---

## 8. Dependencies

### Flutter (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.3.0
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  go_router: ^14.0.0
  dio: ^5.4.0
  file_picker: ^8.0.0
  flutter_pdfview: ^1.3.2
  flutter_markdown: ^0.7.1
  uuid: ^4.3.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.0
  flutter_lints: ^4.0.0
```

### Python (`requirements.txt`)

```
fastapi==0.115.0
uvicorn==0.30.0
pymupdf==1.24.0
google-generativeai==0.8.0
supabase==2.9.0
pydantic==2.9.0
python-dotenv==1.0.0
numpy==1.26.0
```

---

## 9. Error Handling

| Scenario | Handling |
|----------|----------|
| Scanned PDF (no text) | Detect empty extraction → return error to UI |
| Large PDF (>50 pages) | Process normally, chunking handles it |
| No past papers uploaded | Agent tab shows "Upload at least one past paper" |
| Only 1 past paper | Warn but proceed — analysis still works |
| Irrelevant question | Low similarity scores → "I couldn't find this in your documents" |
| Gemini rate limit | Exponential backoff (3 retries) |
| Network offline | Flutter shows snackbar, queues retry |
| Empty workspace chat | Show onboarding: "Upload a PDF to start chatting" |

---

## 10. Development Phases

### Phase 1: Foundation (Days 1-2)
- [ ] Flutter project + Supabase init
- [ ] Supabase: run schema SQL, create storage bucket
- [ ] Workspace CRUD (create, list, delete)
- [ ] Home screen with workspace cards
- [ ] Navigation with GoRouter

### Phase 2: PDF Pipeline (Days 3-4)
- [ ] Python backend: FastAPI scaffold
- [ ] PDF upload from Flutter → Supabase Storage
- [ ] `/process-pdf`: extract → chunk → embed → store
- [ ] Document list UI + upload sheet
- [ ] Processing status indicator

### Phase 3: Chat (Days 5-6)
- [ ] `/chat` endpoint with full context engine
- [ ] `build_context()` with sliding window + compression
- [ ] Chat screen UI with bubbles + source citations
- [ ] Multi-turn conversation support
- [ ] Query rewriting for follow-ups

### Phase 4: Agent (Days 7-8)
- [ ] `/agent/analyze` endpoint
- [ ] `/agent/generate` endpoint
- [ ] Agent screen: analysis display + generation trigger
- [ ] Generated paper preview (markdown render)
- [ ] Past paper flag toggle on documents

### Phase 5: Polish (Days 9-10)
- [ ] PDF viewer screen
- [ ] Loading states, error handling, empty states
- [ ] UI polish (colors, typography, spacing)
- [ ] Testing on device
- [ ] Final build (APK)

---

## 11. File Tree (Complete)

```
paperdrop/
├── DESIGN.md                          # This file
│
├── app/                               # Flutter project
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart
│       ├── app.dart
│       ├── config/
│       ├── models/
│       ├── services/
│       ├── providers/
│       ├── screens/
│       └── widgets/
│
├── server/                            # Python backend
│   ├── main.py
│   ├── requirements.txt
│   ├── .env.example
│   ├── config.py
│   ├── routers/
│   │   ├── processing.py
│   │   ├── chat.py
│   │   └── agent.py
│   └── services/
│       ├── pdf_extractor.py
│       ├── chunker.py
│       ├── embedder.py
│       ├── rag.py
│       └── paper_agent.py
│
└── supabase/
    └── schema.sql                     # Database migration
```

---

## 12. Deployment (MVP)

| Component | Where | Cost |
|-----------|-------|------|
| Flutter | APK on device | Free |
| Supabase | supabase.com free tier (500MB DB, 1GB storage) | Free |
| Python backend | localhost during dev, Railway/Render for demo | Free tier |
| Gemini API | Google AI Studio key (15 RPM, 1M tok/min) | Free |

**Total cost: $0**
