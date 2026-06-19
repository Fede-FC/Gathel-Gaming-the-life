# /src/frontend/src/context — Contexto Global

---

## AuthContext.jsx

Contexto de React que maneja el estado de autenticación de forma global. Cualquier componente de la app puede leer si hay sesión activa y quién es el jugador logueado, sin necesidad de pasar props.

**Estado gestionado:**
- `player` — objeto con `player_id`, `username`, `display_name` y `access_token`. Es `null` cuando no hay sesión.

**Inicialización:** al cargar la app, intenta recuperar el jugador guardado en `localStorage`. Si existe, la sesión se restaura automáticamente (el usuario no tiene que loguearse de nuevo al refrescar la página).

**Funciones expuestas:**

`login(username, password)`:
1. Hace `POST /api/auth/login`
2. Guarda el JWT en `localStorage.token`
3. Guarda el objeto player en `localStorage.player`
4. Actualiza el estado `player` → todas las páginas se re-renderizan con la sesión activa

`logout()`:
1. Llama a `POST /api/auth/logout` (best-effort, ignora errores de red)
2. Borra `localStorage.token` y `localStorage.player`
3. Pone `player = null` → las rutas privadas redirigen a `/login`

**Hook de acceso:**
```js
import { useAuth } from '../context/AuthContext'
const { player, login, logout } = useAuth()
```

**`AuthProvider`:** componente que envuelve toda la app en `main.jsx`. Hace disponible el contexto a todos los componentes descendientes.
