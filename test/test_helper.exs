Application.put_env(:elixir, :ansi_enabled, true)
# Belt-and-braces: ExUnit's stdout/stderr setup can also flip :no_color
# (see `mix test --no-color` and the smoke_case subprocess). Wipe it
# on startup so the very first test sees the same environment as the
# rest of the suite, regardless of how the runner was invoked.
System.delete_env("NO_COLOR")
Application.delete_env(:alaja, :no_color)
Application.delete_env(:alaja, :__conf_loaded__)

ExUnit.start()
