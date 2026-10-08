from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.database import engine
from app.models import Base
from app.routers import auth, households, media, sync


@asynccontextmanager
async def lifespan(_: FastAPI):
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(title="小家厨房 API", version="0.1.0", lifespan=lifespan)
settings = get_settings()
if settings.allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.get("/health", tags=["健康检查"])
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/v1/health", tags=["健康检查"])
async def api_health() -> dict[str, str]:
    return await health()


app.include_router(auth.router, prefix="/api/v1")
app.include_router(households.router, prefix="/api/v1")
app.include_router(media.router, prefix="/api/v1")
app.include_router(sync.router, prefix="/api/v1")
