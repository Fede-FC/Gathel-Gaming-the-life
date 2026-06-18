from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List
from ..database import get_db
from ..auth import get_current_player_id
from ..models import Player
from ..schemas import PlayerDashboard, MoneyBalance, PlayerSearchResult

router = APIRouter(prefix="/api/players", tags=["players"])


@router.get("/me", response_model=PlayerDashboard)
def get_dashboard(
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    result = db.execute(
        text("EXEC dbo.usp_GetPlayerDashboard @player_id = :pid"),
        {"pid": player_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Jugador no encontrado")

    money_result = db.execute(
        text("""
            SELECT ct.currency_code, ct.currency_symbol, t.running_balance
            FROM dbo.CurrencyType ct
            CROSS APPLY (
                SELECT TOP 1 running_balance
                FROM dbo.[Transaction]
                WHERE player_id = :pid AND currency_type_id = ct.currency_type_id
                ORDER BY transaction_id DESC
            ) t
            WHERE ct.is_virtual = 0 AND ct.enabled = 1
        """),
        {"pid": player_id},
    )
    money_balances = [
        MoneyBalance(
            currency_code=r.currency_code,
            currency_symbol=r.currency_symbol,
            current_balance=float(r.running_balance),
        )
        for r in money_result.fetchall()
    ]

    return PlayerDashboard(
        player_id=row.player_id,
        username=row.username,
        display_name=row.display_name,
        balance_points=row.balance_points,
        last_transaction_date=row.last_transaction_date,
        money_balances=money_balances,
    )


@router.get("/search", response_model=List[PlayerSearchResult])
def search_players(
    q: str = Query(..., min_length=2, max_length=50),
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    players = (
        db.query(Player)
        .filter(
            Player.username.ilike(f"%{q}%") | Player.display_name.ilike(f"%{q}%"),
            Player.enabled == True,
        )
        .limit(8)
        .all()
    )
    return [
        PlayerSearchResult(
            player_id=p.player_id,
            username=p.username,
            display_name=p.display_name,
        )
        for p in players
    ]
