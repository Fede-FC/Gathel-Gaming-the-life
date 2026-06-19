# /src/frontend/src/components — Componentes Reutilizables

---

## Navbar.jsx

Barra de navegación superior que aparece en todas las páginas privadas (envuelta en el `<Layout>` de `App.jsx`).

**Contenido:**
- Logo / nombre de la plataforma "Gathel" (link a `/`)
- Links de navegación: Dashboard, Feed, Proposiciones, Billetera, Resultados
- Nombre del jugador autenticado (`player.display_name` o `player.username`)
- Botón de logout que llama a `AuthContext.logout()` y redirige a `/login`

**Estado activo:** usa `NavLink` de React Router, que aplica automáticamente la clase `active` al link de la ruta actual, permitiendo resaltarlo con CSS.

**Responsive:** el menú se adapta a pantallas pequeñas (móvil) colapsando los links.
