# /src/frontend/src — Código Fuente del Frontend

Contiene toda la lógica de la aplicación React: punto de entrada, estilos globales, routing, estado de autenticación, cliente HTTP y componentes.

---

## main.jsx

Punto de entrada de React. Monta la aplicación en el `div#root` del `index.html` y envuelve todo con `AuthProvider` para que el contexto de autenticación esté disponible globalmente.

---

## App.jsx

Define el sistema de routing completo de la aplicación con React Router DOM v7.

**Rutas públicas** (accesibles sin login):
- `/login` → `<Login />`
- `/register` → `<Register />`

**Rutas privadas** (redirigen a `/login` si no hay sesión):
- `/` → `<Dashboard />`
- `/feed` → `<Feed />`
- `/propositions` → `<Propositions />`
- `/wallet` → `<Wallet />`
- `/results` → `<Results />`

**`PrivateRoute`:** componente guard que lee el contexto de autenticación. Si `player` es null (no hay sesión), redirige a `/login`. Protege todas las rutas privadas sin repetir lógica.

**`Layout`:** envuelve las páginas privadas con el `<Navbar />` en la parte superior y un `<main>` con clase `main-content`.

---

## index.css

Estilos globales de la aplicación. Implementa el tema oscuro usando CSS custom properties (variables CSS).

**Variables principales definidas:**
- `--bg-primary` / `--bg-secondary` / `--bg-card` — fondos en escala de grises oscuros
- `--text-primary` / `--text-secondary` — colores de texto
- `--accent` / `--accent-hover` — color de acento (botones, links activos)
- `--success` / `--error` / `--warning` — colores semánticos para estados

**Estilos globales incluidos:** reset CSS, tipografía base, clases de utilidad para badges de estado de proposiciones (`.badge-active`, `.badge-pending`, `.badge-resolved`, etc.), estilos de formularios, tarjetas y el layout de navbar + contenido.

---

## api/

Subcarpeta con el cliente HTTP. Ver `README` de esa carpeta.

## components/

Subcarpeta con componentes reutilizables. Ver `README` de esa carpeta.

## context/

Subcarpeta con el contexto de autenticación. Ver `README` de esa carpeta.

## pages/

Subcarpeta con las 7 páginas de la aplicación. Ver `README` de esa carpeta.

---

## Archivos de configuración (en /src/frontend/)

### vite.config.js
Configuración de Vite (bundler de desarrollo). Define un proxy de desarrollo: todas las peticiones a `/api/*` se redirigen a `http://localhost:8000` durante desarrollo local. En producción esto lo hace nginx.

### nginx.conf
Configuración del servidor web en producción (dentro del contenedor Docker).
- `try_files $uri $uri/ /index.html` — SPA fallback: cualquier ruta que no sea un archivo estático devuelve `index.html`, permitiendo que React Router maneje la navegación del lado del cliente
- `location /api/` — proxy inverso al backend en `http://backend:8000`

### package.json
Dependencias y scripts del proyecto frontend.

| Dependencia | Propósito |
|-------------|-----------|
| `react` + `react-dom` | Framework UI |
| `react-router-dom` v7 | Routing SPA |
| `axios` | Cliente HTTP con interceptores |
| `vite` | Dev server y bundler |
| `@vitejs/plugin-react` | Soporte JSX en Vite |

### index.html
Archivo HTML raíz. Contiene el `div#root` donde React monta la aplicación y la referencia al `main.jsx`.
