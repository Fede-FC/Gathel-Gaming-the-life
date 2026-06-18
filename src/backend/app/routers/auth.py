from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from ..database import get_db
from ..models import Player
from ..auth import verify_password, create_access_token, hash_password
from ..schemas import LoginRequest, TokenResponse, RegisterRequest, RegisterResponse

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


@router.post("/register", response_model=RegisterResponse, status_code=201)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    result = db.execute(
        text("""
            DECLARE @new_id INT;
            EXEC dbo.usp_RegisterPlayer
                @username      = :username,
                @email         = :email,
                @password_hash = :password_hash,
                @display_name  = :display_name,
                @new_player_id = @new_id OUTPUT;
            SELECT @new_id AS new_id;
        """),
        {
            "username": body.username,
            "email": body.email,
            "password_hash": hash_password(body.password),
            "display_name": body.display_name,
        },
    )
    row = result.fetchone()
    db.commit()

    if not row or not row.new_id:
        raise HTTPException(status_code=400, detail="No se pudo crear el jugador")

    return RegisterResponse(
        player_id=row.new_id,
        username=body.username,
        message="Jugador registrado con 100 puntos de bienvenida",
    )


@router.post("/logout")
def logout():
    # JWT es stateless; el cliente descarta el token
    return {"message": "Sesión cerrada"}
