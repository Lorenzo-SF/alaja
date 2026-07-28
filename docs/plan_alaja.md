# Plan for `@alaja` (CLI & Rendering Kit)

> **Goal** – Clean up unnecessary `Alaja.Supervisor` (no children), consolidate shared `Show.*` command modules into a `Base` module, and tighten test coverage.

---

## 1. Preparation

| Step | Action | Outcome |
|------|--------|---------|
| 1.1 | Verify clean working branch `fix-tools-domains` |
| 1.2 | Ensure the working tree is clean (commit any in‑progress changes before starting) |
| 1.3 | Ensure `mix deps.get` for local overrides (pote, arrea, etc.) |
| 1.4 | Confirm `alaja/mix.exs` has proper `path:` overrides
| 1.5 | Commit any pending changes in this repo before starting modifications

## 2. Implementation

| Target | Task |
|--------|------|
| **Supervisor** | Remove `Alaja.Application` child list and adjust supervision tree so `Alaja.Application` still calls the empty `start/2` but no need to start a child; optional minimal placeholder.
| **Command Modules** | Create `lib/alaja/cli/commands/base.ex` that implements generic show‑command helpers.
| **Refactor** | Update all `Show.*` modules to use `Base` functions, removing duplicated code like header, bar rendering, etc.

## 3. Tests

| Test File | Coverage Goal | Main Checks |
|-----------|---------------|-------------|
| `test/alaja/cli/commands/show_test.exs` | 100 % on show modules | • Correct rendering of ASCII boxes
| | | • Colors handled via `pote`

Run `mix test --cover` across the whole project.

## 4. Documentation

* Add a new section in `README.md` describing the `Base` module and why `Alaja.Supervisor` was removed.
* Update the CHANGELOG with ``(refactor‑alaja‑cli)``.
* Ensure docs page includes the new `Base` module.

## 5. Quality

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict --format=json
mix test --cover
mix dialyzer
```

## 6. Commit & Push

```bash
git add -A
git commit -m "Clean alaja CLI: move Show modules to Base, remove supervisor"
git push origin fix-tools-domains
```

---

**End of plan for `@alaja`**