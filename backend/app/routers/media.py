from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_session
from app.models import MediaAsset, User, new_id
from app.routers.households import member_for
from app.schemas import MediaOut
from app.security import get_current_user

router = APIRouter(prefix="/media", tags=["图片"])
MAX_IMAGE_BYTES = 8 * 1024 * 1024
EXTENSION_BY_CONTENT_TYPE = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/heic": ".heic",
    "image/heif": ".heif",
    "image/webp": ".webp",
}


@router.post("/images", response_model=MediaOut, status_code=status.HTTP_201_CREATED)
async def upload_image(
    household_id: str = Form(),
    image: UploadFile = File(),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> MediaOut:
    await member_for(household_id, user.id, session)
    content_type = image.content_type or ""
    extension = EXTENSION_BY_CONTENT_TYPE.get(content_type)
    if extension is None:
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="仅支持 JPG、PNG、HEIC 和 WebP 图片")
    content = await image.read()
    if not content or len(content) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="图片必须小于 8 MB")

    asset = MediaAsset(
        household_id=household_id,
        uploaded_by_id=user.id,
        filename=f"{new_id()}{extension}",
        content_type=content_type,
    )
    media_root: Path = get_settings().media_root
    media_root.mkdir(parents=True, exist_ok=True)
    (media_root / asset.filename).write_bytes(content)
    session.add(asset)
    await session.commit()
    await session.refresh(asset)
    return MediaOut(id=asset.id, url=f"/api/v1/media/images/{asset.id}")


@router.get("/images/{asset_id}")
async def fetch_image(
    asset_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> FileResponse:
    asset = await session.get(MediaAsset, asset_id)
    if asset is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="图片不存在")
    await member_for(asset.household_id, user.id, session)
    path = get_settings().media_root / asset.filename
    if not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="图片文件不存在")
    return FileResponse(path, media_type=asset.content_type)
