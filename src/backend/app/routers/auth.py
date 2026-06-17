from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import Player
from ..auth import verify_password, create_access_token
from ..schemas import LoginRequest, TokenResponse

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    player = db.query(Player).filter(
        Player.username == body.username,
        Player.enabled == True
    ).first()

    if not player or not verify_password(body.password, player.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contraseña incorrectos",
        )

    token = create_access_token({"sub": str(player.player_id)})
    return TokenResponse(
        access_token=token,
        player_id=player.player_id,
        username=player.username,
        display_name=player.display_name,
    )


@router.post("/logout")
def logout():
    # JWT es stateless; el cliente descarta el token
    return {"message": "Sesión cerrada"}
