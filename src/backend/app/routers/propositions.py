from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List
from ..database import get_db
from ..auth import get_current_player_id
from ..models import Player
from ..schemas import (
    PropositionActive, PropositionResult,
    CreatePropositionRequest, CreatePropositionResponse,
    MyProposition, IncomingProposition, AcceptPropositionRequest,
)

router = APIRouter(prefix="/api/propositions", tags=["propositions"])


@router.get("/active", response_model=List[PropositionActive])
def get_active_propositions(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    _: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    result = db.execute(
        text("EXEC dbo.usp_GetActivePropositions @page_number = :p, @page_size = :s"),
        {"p": page, "s": size},
    )
    rows = result.fetchall()
    return [
        PropositionActive(
            proposition_id=r.proposition_id,
            title=r.title,
            description=r.description,
            creator_username=r.creator_username,
            target_username=r.target_username,
            prediction_ends_at=r.prediction_ends_at,
            created_at=r.created_at,
            total_predictions=r.total_predictions,
        )
        for r in rows
    ]


@router.get("/results", response_model=List[PropositionResult])
def get_results(
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    result = db.execute(
        text("EXEC dbo.usp_GetPropositionResults @player_id = :pid"),
        {"pid": player_id},
    )
    rows = result.fetchall()
    return [
        PropositionResult(
            proposition_id=r.proposition_id,
            title=r.title,
            is_fulfilled=r.is_fulfilled,
            resolved_at=r.resolved_at,
            amount=float(r.amount) if r.amount is not None else None,
            currency_code=r.currency_code,
            direction=bool(r.direction) if r.direction is not None else None,
            result=r.result,
        )
        for r in rows
    ]


@router.get("/mine", response_model=List[MyProposition])
def get_my_propositions(
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    result = db.execute(
        text("""
            SELECT p.proposition_id, p.title, p.description,
                   p.created_at, p.prediction_ends_at,
                   ps.status_code, t.username AS target_username
            FROM dbo.Proposition p
            JOIN dbo.PropositionStatus ps ON p.status_id = ps.status_id
            JOIN dbo.Player t ON p.target_player_id = t.player_id
            WHERE p.creator_player_id = :pid AND p.enabled = 1
            ORDER BY p.created_at DESC
        """),
        {"pid": player_id},
    )
    return [
        MyProposition(
            proposition_id=r.proposition_id,
            title=r.title,
            description=r.description,
            created_at=r.created_at,
            prediction_ends_at=r.prediction_ends_at,
            status_code=r.status_code,
            target_username=r.target_username,
        )
        for r in result.fetchall()
    ]


@router.get("/incoming", response_model=List[IncomingProposition])
def get_incoming_propositions(
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    result = db.execute(
        text("""
            SELECT p.proposition_id, p.title, p.description,
                   p.created_at, p.prediction_ends_at, p.is_accepted_by_target,
                   ps.status_code, c.username AS creator_username
            FROM dbo.Proposition p
            JOIN dbo.PropositionStatus ps ON p.status_id = ps.status_id
            JOIN dbo.Player c ON p.creator_player_id = c.player_id
            WHERE p.target_player_id = :pid AND p.enabled = 1
              AND ps.status_code IN ('PENDING', 'ACTIVE', 'PREDICTION_CLOSED')
            ORDER BY p.created_at DESC
        """),
        {"pid": player_id},
    )
    return [
        IncomingProposition(
            proposition_id=r.proposition_id,
            title=r.title,
            description=r.description,
            created_at=r.created_at,
            prediction_ends_at=r.prediction_ends_at,
            status_code=r.status_code,
            is_accepted_by_target=bool(r.is_accepted_by_target),
            creator_username=r.creator_username,
        )
        for r in result.fetchall()
    ]


@router.post("/{proposition_id}/accept")
def accept_proposition(
    proposition_id: int,
    body: AcceptPropositionRequest,
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    try:
        db.execute(
            text("""
                EXEC dbo.usp_AcceptProposition
                    @proposition_id     = :prop_id,
                    @target_player_id   = :player_id,
                    @prediction_ends_at = :ends_at
            """),
            {"prop_id": proposition_id, "player_id": player_id, "ends_at": body.prediction_ends_at},
        )
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    return {"message": "Proposición aceptada. Ya está disponible para predicciones."}


@router.post("/{proposition_id}/reject")
def reject_proposition(
    proposition_id: int,
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    try:
        db.execute(
            text("""
                EXEC dbo.usp_RejectProposition
                    @proposition_id   = :prop_id,
                    @target_player_id = :player_id
            """),
            {"prop_id": proposition_id, "player_id": player_id},
        )
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    return {"message": "Proposición rechazada. Se descontó 1 punto."}


@router.post("", response_model=CreatePropositionResponse, status_code=201)
def create_proposition(
    body: CreatePropositionRequest,
    player_id: int = Depends(get_current_player_id),
    db: Session = Depends(get_db),
):
    # Lectura (ORM): resolver el target_username a target_player_id
    target = db.query(Player).filter(
        Player.username == body.target_username,
        Player.enabled == True,
    ).first()
    if not target:
        raise HTTPException(status_code=404, detail="Jugador destino no encontrado")

    # Escritura → SP
    result = db.execute(
        text("""
            DECLARE @new_id INT;
            EXEC dbo.usp_CreateProposition
                @creator_player_id  = :creator,
                @target_player_id   = :target,
                @title              = :title,
                @description        = :desc,
                @voting_ends_at     = :voting_ends,
                @new_proposition_id = @new_id OUTPUT;
            SELECT @new_id AS new_id;
        """),
        {
            "creator": player_id,
            "target": target.player_id,
            "title": body.title,
            "desc": body.description,
            "voting_ends": body.voting_ends_at,
        },
    )
    row = result.fetchone()
    new_id = row.new_id if row else None
    db.commit()

    return CreatePropositionResponse(
        proposition_id=new_id or 0,
        message="Proposición creada y enviada a revisión AI",
    )
