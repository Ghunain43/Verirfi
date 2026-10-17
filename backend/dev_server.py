# Temporary local wrapper so mobile isn't blocked on the real routes. Do NOT commit.
from fastapi import FastAPI
from pydantic import BaseModel
from backend.app.agents import run_quick_check

app = FastAPI()


class In(BaseModel):
    text: str
    lang: str = "auto"


@app.post("/api/v1/quick-check")
async def qc(body: In):
    r = await run_quick_check(body.text, body.lang)
    return r.model_dump()