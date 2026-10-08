from datetime import UTC, datetime, timedelta
from secrets import token_urlsafe

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.models import Household, HouseholdMember, Invitation, User
from app.schemas import HouseholdCreate, HouseholdOut, InvitationCreate, InvitationOut
from app.security import get_current_user

router = APIRouter(prefix="/households", tags=["家庭"])


async def member_for(
    household_id: str, user_id: str, session: AsyncSession
) -> HouseholdMember:
    member = await session.scalar(
        select(HouseholdMember).where(
            HouseholdMember.household_id == household_id,
            HouseholdMember.user_id == user_id,
        )
    )
    if member is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="你不属于这个家庭")
    return member


@router.get("", response_model=list[HouseholdOut])
async def list_households(
    user: User = Depends(get_current_user), session: AsyncSession = Depends(get_session)
) -> list[HouseholdOut]:
    result = await session.execute(
        select(Household, HouseholdMember.role)
        .join(HouseholdMember, Household.id == HouseholdMember.household_id)
        .where(HouseholdMember.user_id == user.id)
        .order_by(Household.created_at)
    )
    return [HouseholdOut(id=household.id, name=household.name, role=role) for household, role in result.all()]


@router.post("", response_model=HouseholdOut, status_code=status.HTTP_201_CREATED)
async def create_household(
    payload: HouseholdCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> HouseholdOut:
    household = Household(name=payload.name.strip(), owner_id=user.id)
    session.add(household)
    await session.flush()
    session.add(HouseholdMember(household_id=household.id, user_id=user.id, role="owner"))
    await session.commit()
    return HouseholdOut(id=household.id, name=household.name, role="owner")


@router.post("/{household_id}/invitations", response_model=InvitationOut, status_code=status.HTTP_201_CREATED)
async def create_invitation(
    household_id: str,
    payload: InvitationCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> InvitationOut:
    member = await member_for(household_id, user.id, session)
    if member.role != "owner":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="只有创建者可以邀请成员")

    invitation = Invitation(
        token=token_urlsafe(32),
        household_id=household_id,
        created_by_id=user.id,
        expires_at=datetime.now(UTC) + timedelta(days=payload.expires_in_days),
    )
    session.add(invitation)
    await session.commit()
    return InvitationOut(token=invitation.token, household_id=household_id, expires_at=invitation.expires_at)


@router.post("/invitations/{token}/accept", response_model=HouseholdOut)
async def accept_invitation(
    token: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> HouseholdOut:
    invitation = await session.scalar(select(Invitation).where(Invitation.token == token))
    now = datetime.now(UTC)
    if invitation is None or invitation.accepted_at is not None or invitation.expires_at <= now:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="邀请不存在、已被使用或已经过期")
    if await session.scalar(
        select(HouseholdMember).where(
            HouseholdMember.household_id == invitation.household_id,
            HouseholdMember.user_id == user.id,
        )
    ):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="你已经在这个家庭中")

    household = await session.get(Household, invitation.household_id)
    if household is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="家庭不存在")
    invitation.accepted_by_id = user.id
    invitation.accepted_at = now
    session.add(HouseholdMember(household_id=household.id, user_id=user.id, role="member"))
    await session.commit()
    return HouseholdOut(id=household.id, name=household.name, role="member")
