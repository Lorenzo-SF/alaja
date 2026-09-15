Switched the project packaging from `mix escript` to a Mix release packaged by
Batamanta. No API change for library users.

- `mix.exs` now declares the project as a release (`batamanta: [format: :release, ...]`)
  and the legacy `escript: [main_module: Alaja.CLI]` entry has been removed.
- The compiled artefact is still a self-contained, single-file binary named `alaja`
  and is installed by `mix gen` to `~/bin/alaja` exactly as before. The difference
  is internal: the binary now embeds an OTP release (with its ERTS, app graph and
  release scripts) rather than a flat escript.
- Docstrings and comments that previously referred to the escript format (in
  `lib/alaja.ex`, `lib/alaja/cli/definition.ex`, `lib/alaja/application.ex`,
  `lib/alaja/config.ex`, and `test/alaja/theme_switching_test.exs`) have been
  updated to reflect the new release format.
- `docs/ARCHITECTURE.md`, `docs/AUDIT.md`, and the bilingual READMEs now describe
  the release pipeline instead of the escript one.
