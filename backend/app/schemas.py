from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=80)


class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    display_name: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class HouseholdCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)


class HouseholdOut(BaseModel):
    id: str
    name: str
    role: str


class InvitationCreate(BaseModel):
    expires_in_days: int = Field(default=7, ge=1, le=30)


class InvitationOut(BaseModel):
    token: str
    household_id: str
    expires_at: datetime


class SyncChangeIn(BaseModel):
    resource: str = Field(pattern="^(kitchen_snapshot|recipe|pantry_item|meal_plan|shopping_item)$")
    item_id: str = Field(min_length=1, max_length=128)
    payload: dict[str, Any] | None = None
    is_deleted: bool = False
    base_revision: int = Field(default=0, ge=0)


class SyncPushIn(BaseModel):
    household_id: str
    changes: list[SyncChangeIn] = Field(min_length=1, max_length=200)


class SyncRecordOut(BaseModel):
    resource: str
    item_id: str
    revision: int
    payload: dict[str, Any] | None
    is_deleted: bool
    updated_at: datetime


class SyncConflictOut(BaseModel):
    resource: str
    item_id: str
    server_record: SyncRecordOut


class SyncPushOut(BaseModel):
    accepted: list[SyncRecordOut]
    conflicts: list[SyncConflictOut]


class SyncPullOut(BaseModel):
    changes: list[SyncRecordOut]
    next_cursor: datetime | None


class MediaOut(BaseModel):
    id: str
    url: str
