# iter-059 — alaja CLI UX improvements

> **Fecha**: 2026-09-12
> **Mandato**: arreglar 4 problemas del CLI de alaja reportados.

---

## Problemas a resolver

### P1 — `alaja` (sin args): arrow keys rotas
- Antes: prompt interactive con `← →` para moverte entre opciones.
- Ahora: muestra caracteres ANSI de las flechas + acepta "1" o "2" pero no se mueve.
- Fix: implementar prompt raw-mode con arrow keys reales + Enter.
- Archivo: `lib/alaja/cli/showcase.ex`.

### P2 — `alaja theme`: UX no intuitiva
- Sub-commands hard-coded (`init | set | list | show | all`).
- Cuando hay muchos temas, el output es gigante sin paginación.
- Tabla de comparación hecha con `IO.puts` manual, no usa `Alaja.Components.Table`.
- Fix:
  - TUI picker con arrow keys (estilo `fzf`) para `set`.
  - Usar `Alaja.Components.Table` con paginación.
  - `list` debe ser compacto: nombre + swatch + active marker.
- Archivo: `lib/alaja/cli/commands/theme.ex`.

### P3 — `alaja color`: tabla y colorwheel mejorables
- Colorwheel: el user dice "deja un poco que desear para ser un CLI de un framework DSL".
- Tabla de propiedades: ya usa `TableComp`, pero la wheel sí es ASCII plano.
- Fix:
  - Colorwheel: usar `ColorWheel.render/2` (Buffer-based, ya existe) en vez de PNG/raw.
  - Añadir vista previa lateral con la tabla de propiedades.
- Archivo: `lib/alaja/cli/commands/color.ex`.

### P4 — Output de `alaja theme show` (con muchos temas)
- Cuando hay 5+ temas, el compare table es enorme.
- Fix: paginar con `Alaja.CLI.Pagination` (existe) o pedir confirmación de continuar.
- Archivo: `lib/alaja/cli/commands/theme.ex`.

---

## Plan

1. SPEC.
2. Fix P1: arrow keys en showcase.
3. Fix P2 + P4: theme picker + tabla + paginación.
4. Fix P3: color table + wheel.
5. Tests.
6. Commit.

---

**Sign-off**: Mavis (root session) — 2026-09-12.
