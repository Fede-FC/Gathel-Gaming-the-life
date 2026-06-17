from sqlalchemy import Column, Integer, BigInteger, String, Boolean, DateTime, Numeric, ForeignKey
from sqlalchemy.orm import relationship
from .database import Base


class PropositionStatus(Base):
    __tablename__ = "PropositionStatus"
    status_id   = Column(Integer, primary_key=True)
    status_code = Column(String(30))
    description = Column(String(200))


class CurrencyType(Base):
    __tablename__ = "CurrencyType"
    currency_type_id = Column(Integer, primary_key=True)
    currency_code    = Column(String(30))
    currency_symbol  = Column(String(10))
    is_virtual       = Column(Boolean)


class Player(Base):
    __tablename__ = "Player"
    player_id            = Column(Integer, primary_key=True, index=True)
    username             = Column(String(50), unique=True, index=True)
    email                = Column(String(150), unique=True)
    password_hash        = Column(String(256))
    display_name         = Column(String(100))
    balance_points       = Column(BigInteger, default=100)
    balance_version      = Column(Integer, default=1)
    enabled              = Column(Boolean, default=True)
    last_transaction_date = Column(DateTime, nullable=True)
    created_at           = Column(DateTime)
    updated_at           = Column(DateTime)


class Proposition(Base):
    __tablename__ = "Proposition"
    proposition_id    = Column(Integer, primary_key=True, index=True)
    creator_player_id = Column(Integer, ForeignKey("Player.player_id"))
    target_player_id  = Column(Integer, ForeignKey("Player.player_id"))
    status_id         = Column(Integer, ForeignKey("PropositionStatus.status_id"))
    title             = Column(String(150))
    description       = Column(String(1000))
    is_fulfilled      = Column(Boolean, nullable=True)
    voting_ends_at    = Column(DateTime, nullable=True)
    prediction_ends_at = Column(DateTime, nullable=True)
    resolved_at       = Column(DateTime, nullable=True)
    enabled           = Column(Boolean, default=True)
    created_at        = Column(DateTime)
    updated_at        = Column(DateTime)

    creator = relationship("Player", foreign_keys=[creator_player_id])
    target  = relationship("Player", foreign_keys=[target_player_id])
    status  = relationship("PropositionStatus")


class Prediction(Base):
    __tablename__ = "Prediction"
    prediction_id    = Column(BigInteger, primary_key=True)
    proposition_id   = Column(Integer, ForeignKey("Proposition.proposition_id"))
    player_id        = Column(Integer, ForeignKey("Player.player_id"))
    amount           = Column(Numeric(18, 4))
    currency_type_id = Column(Integer, ForeignKey("CurrencyType.currency_type_id"))
    direction        = Column(Boolean)
    result           = Column(String(10), nullable=True)
    created_at       = Column(DateTime)

    proposition  = relationship("Proposition")
    currency     = relationship("CurrencyType")
