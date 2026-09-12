# alaja — CLI 100% alaja DSL (iter-046 plan)

> **Fecha**: 2026-09-12
> **Mandato**: el CLI de alaja debe usar 100% el DSL de alaja.
> **Cero lógica de librería en el CLI — solo parsing + dispatch.**

---

## Estado actual

`lib/alaja/cli.ex` (top-level) — usa `use Alaja.CLI.Definition`. ✅
`lib/alaja/cli/dispatch.ex` — thin wrapper. ✅
`lib/alaja/cli/commands/` — 2,320 LOC hand-rolled con OptionParser.

| Command module | LOC actual | Estado |
|----------------|------------|--------|
| show/pulsar | 197 → 38 | ✅ iter-046 DSL reescrito |
| show/bar | 109 → 33 | ✅ iter-046 DSL reescrito |
| show/animated_bar | 166 | ⏳ iter-047 (siguiente) |
| show/header | 130 | ⏳ iter-047 |
| show/table | 321 | ⏳ iter-047 |
| show/image | 156 | ⏳ iter-047 |
| show/gradient | 119 | ⏳ iter-047 |
| show/json | 98 | ⏳ iter-047 |
| show/message | 466 | ⏳ iter-047 |
| show/ask | ~80 | ⏳ iter-047 |
| show/yesno | ~80 | ⏳ iter-047 |
| show/breadcrumbs | ~80 | ⏳ iter-047 |
| show/animate | ~100 | ⏳ iter-047 |
| show/list | ~80 | ⏳ iter-047 |
| show/menu | ~80 | ⏳ iter-047 |
| show/separator | ~80 | ⏳ iter-047 |
| color | 414 | ⏳ iter-047 |
| theme | 283 | ⏳ iter-047 |
| action | 355 | ⏳ iter-047 |
| (root commands) | - | (ya en lib/alaja/cli.ex via Dispatch) |

## Patrón aplicado en iter-046

1. **Mover parsing al back**:
   - `parse_pulse_chars/1`, `parse_direction/1`, `parse_content_type/1`
     movidos a `Alaja.Components.Pulsar`.

2. **Reescribir CLI con DSL**:
   - `use Alaja.CLI.Definition, otp_app: :alaja`
   - `argument :text, :string, required: true|false`
   - `flag :name, :type, default: ...`
   - `run fn opts -> ... end` (1-arity)

3. **Handler pattern** (cuando la lógica es no-trivial):
   - `Alaja.CLI.Commands.Show.Pulsar.Handler.run/1` — pure dispatcher.
   - El `run` del CLI delega a Handler.
   - Handler llama a las funciones públicas del back.

## Acceptance iter-046

- [x] pulsar CLI reescrito con DSL.
- [x] Pulsar.parse_* helpers públicos.
- [x] bar CLI reescrito con DSL.
- [ ] animated_bar, header, table, image, gradient, json, message (iter-047)
- [ ] ask, yesno, breadcrumbs, animate, list, menu, separator (iter-047)
- [ ] color, theme, action (iter-047)

## Próximo paso

iter-047: aplicar el mismo patrón a los 18 commands restantes.
Patrón replicable, ~5 min por command.
