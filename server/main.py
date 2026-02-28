"""PaperDrop Backend - FastAPI server."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import processing, chat, agent

app = FastAPI(
    title="PaperDrop API",
    description="PDF processing, RAG chat, and past paper agent",
    version="1.0.0",
)

# Allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(processing.router)
app.include_router(chat.router)
app.include_router(agent.router)


@app.get("/")
def health():
    return {"status": "ok", "service": "paperdrop-api"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
