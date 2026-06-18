from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List
from ..database import get_db
from ..auth import get_current_player_id
from ..schemas import FeedEvent

router = APIRouter(prefix="/api/feed", tags=["feed"])

VISIBLE_EVENTS = (
    "PROPOSITION_CREATED", "AI_APPROVED", "PROPOSITION_ACCEPTED",
    "PROPOSITION_REJECTED", "PREDICTION_MADE", "PROPOSITION_RESOLVED",
)


@router.get("", response_model=List[FeedEvent])
def get_feed(
    size: int = Query(40, ge=1, le=100),
    _: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    placeholders = ", ".join(f"'{c}'" for c in VISIBLE_EVENTS)
    result = db.execute(
        text(f"""
            SELECT TOP (:size)
                ge.event_id, ge.created_at,
                et.type_code, et.description AS event_description,
                a.username  AS actor_username,
                a.display_name AS actor_display,
                p.proposition_id, p.title AS proposition_title
            FROM dbo.GameEvent ge
            JOIN dbo.EventType et ON ge.event_type_id = et.event_type_id
            JOIN dbo.Player    a  ON ge.actor_player_id = a.player_id
            LEFT JOIN dbo.Proposition p ON ge.proposition_id = p.proposition_id
            WHERE et.type_code IN ({placeholders})
            ORDER BY ge.created_at DESC
        """),
        {"size": size},
    )
    return [
        FeedEvent(
            event_id=r.event_id,
            type_code=r.type_code,
            event_description=r.event_description,
            actor_username=r.actor_username,
            actor_display=r.actor_display,
            proposition_id=r.proposition_id,
            proposition_title=r.proposition_title,
            created_at=r.created_at,
        )
        for r in result.fetchall()
    ]
