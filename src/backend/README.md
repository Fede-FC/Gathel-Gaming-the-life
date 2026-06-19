# /src/backend — REST API (FastAPI)

Backend del MVP de Gathel. Expone 19 endpoints REST, maneja autenticación JWT y se comunica con SQL Server exclusivamente a través de stored procedures para escrituras y queries directas para lecturas de solo lectura.

**Stack:** Python 3.11 · FastAPI · SQLAlchemy 2.0 · pymssql · python-jose

---

## Estructura

```
src/backend/
├── Dockerfile           # Imagen Docker del backend
├── requirements.txt     # Dependencias Python
└── app/
    ├── __init__.py
    ├── main.py          # Punto de entrada, registro de routers
    ├── auth.py          # Hashing de contraseñas y JWT
    ├── database.py      # Conexión y pool de SQLAlchemy
    ├── models.py        # Modelos ORM (solo lectura)
    ├── schemas.py       # Schemas de entrada/salida (Pydantic)
    └── routers/
        ├── auth.py         # Login, logout, registro
        ├── players.py      # Dashboard, búsqueda de usuarios
        ├── propositions.py # CRUD de proposiciones
        ├── predictions.py  # Predicciones
        ├── feed.py         # Feed de eventos
        └── wallet.py       # Billetera y transacciones
```

---

## Dockerfile

Imagen basada en `python:3.11-slim`. Instala FreeTDS (driver nativo para SQL Server en Linux, sin necesidad de ODBC) y las dependencias Python. Corre el servidor con `uvicorn` en el puerto 8000.

**Por qué FreeTDS:** la imagen oficial de ODBC para SQL Server en Linux requiere paquetes adicionales pesados. `pymssql` usa FreeTDS directamente, lo que resulta en una imagen más liviana y sin problemas de compatibilidad en ARM/WSL2.

---

## requirements.txt

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `fastapi` | 0.111.0 | Framework web asíncrono |
| `uvicorn[standard]` | 0.30.1 | Servidor ASGI de producción |
| `sqlalchemy` | 2.0.30 | ORM y manejo de conexiones |
| `pymssql` | 2.3.1 | Driver SQL Server vía FreeTDS |
| `python-jose[cryptography]` | 3.3.0 | Generación y validación de JWT |
| `python-multipart` | 0.0.9 | Soporte para form-data (login OAuth2) |
| `pydantic[email]` | 2.7.1 | Validación de schemas con soporte EmailStr |
