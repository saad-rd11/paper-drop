"""Agent router: past paper analysis + practice paper generation."""

from fastapi import APIRouter, HTTPException
from models.schemas import AnalyzeRequest, GenerateRequest
from services.paper_agent import analyze_past_papers, generate_paper

router = APIRouter(prefix="/agent")


@router.post("/analyze")
async def analyze(req: AnalyzeRequest):
    """Analyze all past papers in a workspace to extract patterns."""
    try:
        analysis = analyze_past_papers(req.workspace_id)
        return {"analysis": analysis}
    except ValueError as e:
        raise HTTPException(400, str(e))
    except Exception as e:
        raise HTTPException(500, f"Analysis error: {str(e)}")


@router.post("/generate")
async def generate(req: GenerateRequest):
    """Generate a practice paper based on analysis + study material."""
    try:
        result = generate_paper(req.workspace_id, req.analysis)
        return result
    except ValueError as e:
        raise HTTPException(400, str(e))
    except Exception as e:
        raise HTTPException(500, f"Generation error: {str(e)}")
