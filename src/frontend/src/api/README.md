# /src/frontend/src/api — Cliente HTTP

---

## client.js

Instancia de Axios configurada con los interceptores de autenticación y manejo de errores.

**Configuración base:**
```js
const api = axios.create({ baseURL: '/api' })
```
Todas las llamadas usan `/api` como base, que en desarrollo Vite redirige a `localhost:8000` y en producción nginx redirige al contenedor `backend`.

**Interceptor de request (salida):**
Antes de cada llamada, lee el JWT de `localStorage` y lo adjunta como `Authorization: Bearer <token>`. Si no hay token (usuario no logueado), la petición sale sin header de autorización.

**Interceptor de response (entrada):**
Si el servidor devuelve un `401 Unauthorized`:
1. Borra `token` y `player` de `localStorage`
2. Redirige a `/login` con `window.location.href`

Esto asegura que si el JWT expira (8 horas) o es inválido, el usuario es redirigido automáticamente al login sin importar en qué página esté.

**Uso:** todas las páginas importan este cliente en lugar de axios directamente:
```js
import api from '../api/client'
api.get('/players/me')
api.post('/predictions', { ... })
```
