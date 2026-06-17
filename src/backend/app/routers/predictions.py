from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from ..database import get_db
from ..auth import get_current_player_id
from ..schemas import PlacePredictionRequest, PlacePredictionResponse

router = APIRouter(prefix="/api/predictions", tags=["predictions"])


@router.post("", response_model=PlacePredictionResponse, status_code=201)
def place_prediction(
    body: PlacePredictionRequest,
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    try:
        result = db.execute(
            text("""
                DECLARE @new_id BIGINT;
                EXEC dbo.usp_PlacePrediction
                    @proposition_id    = :prop_id,
                    @player_id         = :pid,
                    @amount            = :amount,
                    @currency_code     = :currency,
                    @direction         = :direction,
                    @new_prediction_id = @new_id OUTPUT;
                SELECT @new_id AS new_id;
            """),
            {
                "prop_id":  body.proposition_id,
                "pid":      player_id,
                "amount":   body.amount,
                "currency": body.currency_code,
                "direction": 1 if body.direction else 0,
            },
        )
        row = result.fetchone()
        db.commit()
        return PlacePredictionResponse(
            prediction_id=row.new_id if row else 0,
            message="Predicción registrada correctamente",
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
