from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from ..database import get_db
from ..auth import get_current_player_id
from ..schemas import PlayerDashboard

router = APIRouter(prefix="/api/players", tags=["players"])


@router.get("/me", response_model=PlayerDashboard)
def get_dashboard(
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    # Escrituras → SP; lectura del dashboard → SP de lectura (usa ORM internamente en el SP)
    result = db.execute(
        text("EXEC dbo.usp_GetPlayerDashboard @player_id = :pid"),
        {"pid": player_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Jugador no encontrado")

    return PlayerDashboard(
        player_id=row.player_id,
        username=row.username,
        display_name=row.display_name,
        balance_points=row.balance_points,
        last_transaction_date=row.last_transaction_date,
    )
