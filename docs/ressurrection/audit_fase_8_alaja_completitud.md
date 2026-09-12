# alaja — audit completitud (iter-038)

> **Fecha**: 2026-09-12
> **Tamaño**: 23,095 LOC, ~120 módulos
> **Tests**: 68 archivos
> **Meta**: alaja 100% terminado + integración CLI en zaguan

---

## Estado actual

| Área | LOC | Estado |
|------|-----|--------|
| `alaja/app.ex` | 464 | ✅ |
| `alaja/cli/definition.ex` (DSL) | 765 | ✅ |
| `alaja/cli/help.ex` (auto-gen) | 588 | ✅ |
| `alaja/cli/color.ex` | 571 | ✅ |
| `alaja/cli/commands/` | ~3000 | ✅ |
| `alaja/components/` (Pulsar, MultiBar, AnimatedBar, Gradient, etc) | ~5000 | ✅ |
| `alaja/buffer.ex` + `alaja/cell.ex` + `alaja/layout.ex` | ~1300 | ✅ |
| `alaja/syntax.ex` | 425 | ✅ |
| `alaja/theme/custom_templates.ex` | 689 | ✅ |
| `alaja/ansi.ex` | ~250 | ✅ |

alaja está **production-grade**. Componentes, DSL, help auto-gen, color
management, animations, todos funcionan.

## Gap principal: zaguan CLI no usa alaja

`Zaguan.CLI` (1,362 LOC) está hand-rolled con pattern matching en `argv`.
Debería usar `Alaja.CLI.Definition` DSL declarativamente.

### Plan iter-038

1. SPEC (este doc).
2. Reescribir `Zaguan.CLI` para usar `use Alaja.CLI.Definition`.
3. Definir los 16 comandos core como `command name, description do ... end`.
4. Mantener el shim `Zaguan.Ecosystem.CLI` para backwards compat.
5. Tests: integración end-to-end de la DSL.
6. `mix ex_doc` debería seguir funcionando.

### No-goals

- Reescribir TODOS los subcommands (son 44). Solo los 16 top-level.
- Mantener `Zaguan.CLI` viejo como fallback para tests internos.

### Acceptance

- [ ] `lib/zaguan/cli.ex` reescrito con `use Alaja.CLI.Definition`.
- [ ] 16 comandos top-level declarados.
- [ ] `mix run --help` funciona via Alaja.CLI.Help.
- [ ] `Zaguan.Ecosystem.CLI.help/0` ahora viene de alaja directamente.
- [ ] Tests del CLI pasan.
