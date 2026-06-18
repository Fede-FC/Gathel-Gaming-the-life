from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List
from ..database import get_db
from ..auth import get_current_player_id
from ..schemas import CurrencyWithRate, DepositRequest, TransactionRecord

router = APIRouter(prefix="/api/wallet", tags=["wallet"])


@router.get("/currencies", response_model=List[CurrencyWithRate])
def get_currencies(
    _: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    result = db.execute(text("""
        SELECT ct.currency_code, ct.currency_name, ct.currency_symbol,
               er.rate_to_usd
        FROM dbo.CurrencyType ct
        LEFT JOIN (
            SELECT currency_type_id, rate_to_usd,
                   ROW_NUMBER() OVER (PARTITION BY currency_type_id ORDER BY effective_date DESC) AS rn
            FROM dbo.ExchangeRate
        ) er ON er.currency_type_id = ct.currency_type_id AND er.rn = 1
        WHERE ct.is_virtual = 0 AND ct.enabled = 1
        ORDER BY ct.currency_code
    """))
    return [
        CurrencyWithRate(
            currency_code=r.currency_code,
            currency_name=r.currency_name,
            currency_symbol=r.currency_symbol,
            rate_to_usd=float(r.rate_to_usd) if r.rate_to_usd is not None else None,
        )
        for r in result.fetchall()
    ]


@router.post("/deposit")
def deposit(
    body: DepositRequest,
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    if body.amount <= 0:
        raise HTTPException(status_code=400, detail="El monto debe ser mayor a cero.")
    try:
        db.execute(
            text("""
                EXEC dbo.usp_DepositMoney
                    @player_id     = :player_id,
                    @currency_code = :currency_code,
                    @amount        = :amount
            """),
            {"player_id": player_id, "currency_code": body.currency_code, "amount": body.amount},
        )
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    return {"message": f"Depósito de {body.amount} {body.currency_code} registrado correctamente."}


@router.get("/history", response_model=List[TransactionRecord])
def get_history(
    size: int = Query(30, ge=1, le=100),
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    result = db.execute(
        text("""
            SELECT TOP (:size)
                t.amount, t.running_balance, t.description, t.created_at,
                ct.currency_code, ct.currency_symbol,
                tt.type_code AS transaction_type
            FROM dbo.[Transaction] t
            JOIN dbo.CurrencyType     ct ON t.currency_type_id     = ct.currency_type_id
            JOIN dbo.TransactionType  tt ON t.transaction_type_id  = tt.transaction_type_id
            WHERE t.player_id = :pid AND ct.is_virtual = 0
            ORDER BY t.created_at DESC
        """),
        {"pid": player_id, "size": size},
    )
    return [
        TransactionRecord(
            amount=float(r.amount),
            running_balance=float(r.running_balance),
            description=r.description,
            currency_code=r.currency_code,
            currency_symbol=r.currency_symbol,
            transaction_type=r.transaction_type,
            created_at=r.created_at,
        )
        for r in result.fetchall()
    ]
