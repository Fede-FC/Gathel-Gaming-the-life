import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

DB_HOST     = os.getenv("DB_HOST", "sql-server")
DB_PORT     = os.getenv("DB_PORT", "1433")
DB_NAME     = os.getenv("DB_NAME", "GathelDB")
DB_USER     = os.getenv("DB_USER", "sa")
DB_PASSWORD = os.getenv("DB_PASSWORD", "GathelPassword123!Secure")

CONNECTION_STRING = (
    f"mssql+pymssql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# Fixed-size pool: pool_size conexiones, max_overflow=0 → nunca supera el límite
engine = create_engine(
    CONNECTION_STRING,
    pool_size=5,
    max_overflow=0,
    pool_timeout=30,
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
