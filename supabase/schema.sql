-- PaperDrop Database Schema
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor > New Query)

-- ─────────────────────────────────────────────────────────
-- 1. Enable pgvector extension (required for embeddings)
-- ─────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS vector;

-- ─────────────────────────────────────────────────────────
-- 2. Tables
-- ─────────────────────────────────────────────────────────

CREATE TABLE workspaces (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         TEXT NOT NULL,
    description  TEXT DEFAULT '',
    chat_summary TEXT,
    created_at   TIMESTAMPTZ DEFAULT now()
);

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

CREATE TABLE document_chunks (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id  UUID REFERENCES documents(id) ON DELETE CASCADE,
    chunk_index  INT NOT NULL,
    content      TEXT NOT NULL,
    embedding    HALFVEC(3072),
    metadata     JSONB DEFAULT '{}'
);

CREATE TABLE chat_messages (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
    role         TEXT CHECK (role IN ('user', 'assistant')),
    content      TEXT NOT NULL,
    sources      JSONB DEFAULT '[]',
    created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE generated_papers (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
    title        TEXT NOT NULL,
    content      TEXT NOT NULL,
    analysis     JSONB DEFAULT '{}',
    created_at   TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────────────────────
-- 3. Indexes
-- ─────────────────────────────────────────────────────────

CREATE INDEX idx_documents_workspace ON documents(workspace_id);
CREATE INDEX idx_chunks_document ON document_chunks(document_id);
CREATE INDEX idx_chat_workspace ON chat_messages(workspace_id, created_at);
CREATE INDEX idx_papers_workspace ON generated_papers(workspace_id);

-- pgvector index using halfvec to support 3072 dimensions (Gemini embeddings)
-- halfvec supports up to 4000 dimensions with hnsw index
CREATE INDEX idx_chunks_embedding ON document_chunks
    USING hnsw ((embedding::halfvec(3072)) halfvec_cosine_ops);

-- ─────────────────────────────────────────────────────────
-- 4. RPC function for vector similarity search
--    Called from Python backend via supabase.rpc("match_chunks", {...})
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION match_chunks(
    query_embedding VECTOR(3072),
    match_workspace_id UUID,
    match_threshold FLOAT,
    match_count INT
)
RETURNS TABLE (
    id UUID,
    document_id UUID,
    chunk_index INT,
    content TEXT,
    metadata JSONB,
    file_name TEXT,
    page INT,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        dc.id,
        dc.document_id,
        dc.chunk_index,
        dc.content,
        dc.metadata,
        d.file_name,
        (dc.metadata->>'page')::INT AS page,
        1 - (dc.embedding::halfvec(3072) <=> query_embedding::halfvec(3072)) AS similarity
    FROM document_chunks dc
    JOIN documents d ON d.id = dc.document_id
    WHERE d.workspace_id = match_workspace_id
      AND 1 - (dc.embedding::halfvec(3072) <=> query_embedding::halfvec(3072)) > match_threshold
    ORDER BY dc.embedding::halfvec(3072) <=> query_embedding::halfvec(3072)
    LIMIT match_count;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 5. Storage bucket (run separately or create via Dashboard)
-- ─────────────────────────────────────────────────────────
-- Go to Supabase Dashboard > Storage > Create bucket named "pdfs"
-- Set it to public or configure RLS as needed

-- ─────────────────────────────────────────────────────────
-- 6. Row Level Security (disabled for MVP / no-auth)
-- ─────────────────────────────────────────────────────────
-- For a university project with no auth, disable RLS:
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE generated_papers ENABLE ROW LEVEL SECURITY;

-- Allow all operations (no auth required)
CREATE POLICY "Allow all on workspaces" ON workspaces FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on documents" ON documents FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on document_chunks" ON document_chunks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on chat_messages" ON chat_messages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on generated_papers" ON generated_papers FOR ALL USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────
-- 7. Storage RLS Policies (run after creating "pdfs" bucket)
-- ─────────────────────────────────────────────────────────
-- These allow the Flutter app (using anon key) to upload/download

-- Allow anon to select (download) from pdfs bucket
CREATE POLICY "Allow anon downloads" ON storage.objects
    FOR SELECT USING (bucket_id = 'pdfs');

-- Allow anon to insert (upload) to pdfs bucket
CREATE POLICY "Allow anon uploads" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'pdfs');

-- Allow anon to update in pdfs bucket
CREATE POLICY "Allow anon updates" ON storage.objects
    FOR UPDATE USING (bucket_id = 'pdfs');

-- Allow anon to delete from pdfs bucket
CREATE POLICY "Allow anon deletes" ON storage.objects
    FOR DELETE USING (bucket_id = 'pdfs');
