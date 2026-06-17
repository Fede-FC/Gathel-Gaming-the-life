from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routers import auth, players, propositions, predictions

app = FastAPI(
    title="Gathel Gaming API",
    version="1.0.0",
    description="Backend MVP — Gathel Gaming the Life",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(players.router)
app.include_router(propositions.router)
app.include_router(predictions.router)


@app.get("/api/health")
def health():
    return {"status": "ok", "service": "gathel-backend"}
