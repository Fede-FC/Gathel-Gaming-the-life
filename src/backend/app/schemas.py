from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime


class LoginRequest(BaseModel):
    username: str
    password: str


class RegisterRequest(BaseModel):
    username: str
    email: EmailStr
    password: str
    display_name: Optional[str] = None


class RegisterResponse(BaseModel):
    player_id: int
    username: str
    message: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    player_id: int
    username: str
    display_name: Optional[str]


class MoneyBalance(BaseModel):
    currency_code: str
    currency_symbol: Optional[str]
    current_balance: float


class PlayerDashboard(BaseModel):
    player_id: int
    username: str
    display_name: Optional[str]
    balance_points: int
    last_transaction_date: Optional[datetime]
    money_balances: List[MoneyBalance] = []


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


class MyProposition(BaseModel):
    proposition_id: int
    title: str
    description: str
    created_at: datetime
    prediction_ends_at: Optional[datetime]
    status_code: str
    target_username: str


class IncomingProposition(BaseModel):
    proposition_id: int
    title: str
    description: str
    created_at: datetime
    prediction_ends_at: Optional[datetime]
    status_code: str
    is_accepted_by_target: bool
    creator_username: str


class AcceptPropositionRequest(BaseModel):
    prediction_ends_at: datetime


class PlayerSearchResult(BaseModel):
    player_id: int
    username: str
    display_name: Optional[str]


class PlacePredictionRequest(BaseModel):
    proposition_id: int
    amount: float
    currency_code: str = "POINTS"
    direction: bool


class PlacePredictionResponse(BaseModel):
    prediction_id: int
    message: str
