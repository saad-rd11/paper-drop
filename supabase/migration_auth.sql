-- PaperDrop Auth Migration
-- Run this in Supabase SQL Editor AFTER the initial schema.sql
-- Adds user_id to workspaces and updates RLS policies for per-user isolation

-- ─────────────────────────────────────────────────────────
-- 1. Add user_id column to workspaces
-- ─────────────────────────────────────────────────────────
ALTER TABLE workspaces
  ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- If you have existing rows, assign them to a user or delete them:
-- DELETE FROM workspaces WHERE user_id IS NULL;

-- Make user_id NOT NULL after backfilling (optional, recommended):
-- ALTER TABLE workspaces ALTER COLUMN user_id SET NOT NULL;

-- Index for fast per-user queries
CREATE INDEX idx_workspaces_user ON workspaces(user_id);

-- ─────────────────────────────────────────────────────────
-- 2. Drop old "allow all" RLS policies
-- ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Allow all on workspaces" ON workspaces;
DROP POLICY IF EXISTS "Allow all on documents" ON documents;
DROP POLICY IF EXISTS "Allow all on document_chunks" ON document_chunks;
DROP POLICY IF EXISTS "Allow all on chat_messages" ON chat_messages;
DROP POLICY IF EXISTS "Allow all on generated_papers" ON generated_papers;

-- ─────────────────────────────────────────────────────────
-- 3. New RLS policies — user can only access their own data
-- ─────────────────────────────────────────────────────────

-- Workspaces: user_id must match authenticated user
CREATE POLICY "Users can view own workspaces"
  ON workspaces FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own workspaces"
  ON workspaces FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own workspaces"
  ON workspaces FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own workspaces"
  ON workspaces FOR DELETE
  USING (auth.uid() = user_id);

-- Documents: workspace must belong to user
CREATE POLICY "Users can view own documents"
  ON documents FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM workspaces w WHERE w.id = documents.workspace_id AND w.user_id = auth.uid()
  ));

CREATE POLICY "Users can create own documents"
  ON documents FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM workspaces w WHERE w.id = documents.workspace_id AND w.user_id = auth.uid()
  ));

CREATE POLICY "Users can update own documents"
  ON documents FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM workspaces w WHERE w.id = documents.workspace_id AND w.user_id = auth.uid()
  ));

CREATE POLICY "Users can delete own documents"
  ON documents FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM workspaces w WHERE w.id = documents.workspace_id AND w.user_id = auth.uid()
  ));

-- Document chunks: workspace must belong to user (via document)
CREATE POLICY "Users can view own chunks"
  ON document_chunks FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM documents d
    JOIN workspaces w ON w.id = d.workspace_id
    WHERE d.id = document_chunks.document_id AND w.user_id = auth.uid()
  ));

CREATE POLICY "Users can create own chunks"
  ON document_chunks FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM documents d
    JOIN workspaces w ON w.id = d.workspace_id
    WHERE d.id = document_chunks.document_id AND w.user_id = auth.uid()
  ));

CREATE POLICY "Users can update own chunks"
  ON document_chunks FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM documents d
    JOIN workspaces w ON w.id = d.workspace_id
    WHERE d.id = document_chunks.document_id AND w.user_id = auth.uid()
  ));

CREATE POLICY "Users can delete own chunks"
  ON document_chunks FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM documents d
    JOIN workspaces w ON w.id = d.workspace_id
    WHERE d.id = document_chunks.document_id AND w.user_id = auth.uid()
  ));

-- Chat messages: workspace must belong to user
CREATE POLICY "Users can view own messages"
  ON chat_messages FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM workspaces w WHERE w.id = chat_messages.workspace_id AND w.user_id = auth.uid()
  ));

CREATE POLICY "Users can create own messages"
  ON chat_messages FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM workspaces w WHERE w.id = chat_messages.workspace_id AND w.user_id = auth.uid()
  ));

CREATE POLICY "Users can delete own messages"
  ON chat_messages FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM workspaces w WHERE w.id = chat_messages.workspace_id AND w.user_id = auth.uid()
  ));

-- Generated papers: workspace must belong to user
CREATE POLICY "Users can view own papers"
  ON generated_papers FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM workspaces w WHERE w.id = generated_papers.workspace_id AND w.user_id = auth.uid()
  ));

CREATE POLICY "Users can create own papers"
  ON generated_papers FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM workspaces w WHERE w.id = generated_papers.workspace_id AND w.user_id = auth.uid()
  ));

CREATE POLICY "Users can delete own papers"
  ON generated_papers FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM workspaces w WHERE w.id = generated_papers.workspace_id AND w.user_id = auth.uid()
  ));

-- ─────────────────────────────────────────────────────────
-- 4. Storage RLS — scope to authenticated users
-- ─────────────────────────────────────────────────────────
-- Drop old anon policies
DROP POLICY IF EXISTS "Allow anon downloads" ON storage.objects;
DROP POLICY IF EXISTS "Allow anon uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow anon updates" ON storage.objects;
DROP POLICY IF EXISTS "Allow anon deletes" ON storage.objects;

-- Authenticated users can manage files in pdfs bucket
CREATE POLICY "Auth users can download pdfs"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'pdfs' AND auth.role() = 'authenticated');

CREATE POLICY "Auth users can upload pdfs"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'pdfs' AND auth.role() = 'authenticated');

CREATE POLICY "Auth users can update pdfs"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'pdfs' AND auth.role() = 'authenticated');

CREATE POLICY "Auth users can delete pdfs"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'pdfs' AND auth.role() = 'authenticated');
