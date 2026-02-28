from pydantic import BaseModel


class ProcessPdfRequest(BaseModel):
    document_id: str
    workspace_id: str


class ChatRequest(BaseModel):
    workspace_id: str
    message: str


class AnalyzeRequest(BaseModel):
    workspace_id: str


class GenerateRequest(BaseModel):
    workspace_id: str
    analysis: dict
