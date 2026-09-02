from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator

class AllotmentStatus(str, Enum):
    ALLOTTED = "ALLOTTED"
    NOT_ALLOTTED = "NOT_ALLOTTED"
    NO_RECORD = "NO_RECORD"
    NOT_LIVE = "NOT_LIVE"
    HUMAN_REQUIRED = "HUMAN_REQUIRED"
    TEMPORARY_ERROR = "TEMPORARY_ERROR"
    UNKNOWN = "UNKNOWN"
    UNSUPPORTED_REGISTRAR = "UNSUPPORTED_REGISTRAR"

class AllotmentCheckRequest(BaseModel):
    ipoName: str = Field(min_length=2, max_length=250)
    pan: str = Field(min_length=10, max_length=10)
    registrar: str = Field(default="KFIN", min_length=2, max_length=50)
    ipoId: Optional[str] = Field(default=None, max_length=250)

    @field_validator("ipoName")
    @classmethod
    def normalize_ipo_name(cls, value: str) -> str:
        return " ".join(value.strip().split())

    @field_validator("registrar")
    @classmethod
    def normalize_registrar(cls, value: str) -> str:
        return value.strip().upper()

    @field_validator("pan")
    @classmethod
    def validate_pan(cls, value: str) -> str:
        import re
        normalized = value.strip().upper()
        if not re.fullmatch(r"[A-Z]{5}[0-9]{4}[A-Z]", normalized):
            raise ValueError("Invalid PAN format.")
        return normalized


class AllotmentCheckResponse(BaseModel):
    status: AllotmentStatus
    registrar: str
    ipoName: str
    sharesAllotted: Optional[int] = None
    applicationNumber: Optional[str] = None
    message: Optional[str] = None
