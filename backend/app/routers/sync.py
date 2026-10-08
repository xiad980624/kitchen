from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.models import SyncRecord, User
from app.routers.households import member_for
from app.schemas import SyncConflictOut, SyncPullOut, SyncPushIn, SyncPushOut, SyncRecordOut
from app.security import get_current_user

router = APIRouter(prefix="/sync", tags=["同步"])


def as_output(record: SyncRecord) -> SyncRecordOut:
    return SyncRecordOut(
        resource=record.resource,
        item_id=record.item_id,
        revision=record.revision,
        payload=record.payload,
        is_deleted=record.is_deleted,
        updated_at=record.updated_at,
    )


@router.post("/push", response_model=SyncPushOut)
async def push(
    payload: SyncPushIn,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> SyncPushOut:
    await member_for(payload.household_id, user.id, session)
    accepted: list[SyncRecordOut] = []
    conflicts: list[SyncConflictOut] = []

    for change in payload.changes:
        record = await session.scalar(
            select(SyncRecord).where(
                SyncRecord.household_id == payload.household_id,
                SyncRecord.resource == change.resource,
                SyncRecord.item_id == change.item_id,
            )
        )
        if record is not None and change.base_revision != record.revision:
            conflicts.append(
                SyncConflictOut(resource=change.resource, item_id=change.item_id, server_record=as_output(record))
            )
            continue
        if record is None and change.base_revision != 0:
            continue
        if record is None:
            record = SyncRecord(
                household_id=payload.household_id,
                resource=change.resource,
                item_id=change.item_id,
                revision=1,
                payload=change.payload,
                is_deleted=change.is_deleted,
                updated_by_id=user.id,
            )
            session.add(record)
        else:
            record.revision += 1
            record.payload = change.payload
            record.is_deleted = change.is_deleted
            record.updated_by_id = user.id
        await session.flush()
        accepted.append(as_output(record))

    await session.commit()
    return SyncPushOut(accepted=accepted, conflicts=conflicts)


@router.get("/pull", response_model=SyncPullOut)
async def pull(
    household_id: str,
    cursor: datetime | None = Query(default=None),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> SyncPullOut:
    await member_for(household_id, user.id, session)
    statement = select(SyncRecord).where(SyncRecord.household_id == household_id)
    if cursor is not None:
        statement = statement.where(SyncRecord.updated_at > cursor)
    records = list((await session.scalars(statement.order_by(SyncRecord.updated_at).limit(500))).all())
    next_cursor = records[-1].updated_at if records else cursor
    return SyncPullOut(changes=[as_output(record) for record in records], next_cursor=next_cursor)
