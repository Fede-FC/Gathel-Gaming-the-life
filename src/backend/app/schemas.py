from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    player_id: int
    username: str
    display_name: Optional[str]


class PlayerDashboard(BaseModel):
    player_id: int
    username: str
    display_name: Optional[str]
    balance_points: int
    last_transaction_date: Optional[datetime]


class PropositionActive(BaseModel):
    proposition_id: int
    title: str
    description: str
    creator_username: str
    target_username: str
    prediction_ends_at: Optional[datetime]
    created_at: datetime
    total_predictions: int


class PropositionResult(BaseModel):
    proposition_id: int
    title: str
    is_fulfilled: Optional[bool]
    resolved_at: Optional[datetime]
    amount: Optional[float]
    currency_code: Optional[str]
    direction: Optional[bool]
    result: Optional[str]


class CreatePropositionRequest(BaseModel):
    target_username: str
    title: str
    description: str
    voting_ends_at: datetime


class CreatePropositionResponse(BaseModel):
    proposition_id: int
    message: str


class PlacePredictionRequest(BaseModel):
    proposition_id: int
    amount: float
    currency_code: str = "POINTS"
    direction: bool


class PlacePredictionResponse(BaseModel):
    prediction_id: int
    message: str
