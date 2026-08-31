Implemented fixes for breadcrumbs color parsing and separator handling, corrected gradient direction logic, improved theme table rendering alignment, and updated relevant component and command modules.

- Breadcrumbs CLI now uses `Color.parse_list_or_nil` for color options.
- Breadcrumbs component now correctly resolves separator color from list or defaults.
- Gradient component no longer reverses color steps.
- Theme comparison table now pads swatches to correct column width.
