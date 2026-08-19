defmodule Alaja.CLI.Definition do
  # credo:disable-for-this-file Credo.Check.Design.AliasUsage
  @moduledoc """
  Declarative DSL for defining CLI commands.

  ## Usage

      defmodule MyApp.CLI do
        use Alaja.CLI.Definition, otp_app: :my_app

        command "deploy", "Deploy to production" do
          flag :env, :string, default: "staging", values: ~w(staging production)
          flag :force, :boolean, default: false

          run fn opts ->
            IO.puts("Deploying to " <> opts.env)
            if opts.force, do: IO.puts("Forced mode!")
          end
        end

        subcommand "config", "Manage configuration" do
          command "get", "Read a value" do
            argument :key, :string, required: true
            run fn opts -> IO.inspect(opts.key) end
          end
        end
      end

  ## Structure

  The DSL generates a command map with the following shape:

      %{
        name: "deploy",
        description: "Deploy to production",
        flags: [...],
        arguments: [...],
        subcommands: %{},
        run: function
      }
  """

  @valid_flag_types [:string, :integer, :float, :boolean, :atom, :path, :url, :color_list, :keep]
  @valid_arg_types [:string, :integer, :float, :boolean, :atom, :path, :url, :color_list, :keep]

  @type flag_type ::
          :string | :integer | :float | :boolean | :atom | :path | :url | :color_list | :keep
  @type arg_type ::
          :string | :integer | :float | :boolean | :atom | :path | :url | :color_list | :keep

  @doc false
  @spec __using__(Keyword.t()) :: Macro.t()
  defmacro __using__(opts) do
    otp_app = Keyword.get(opts, :otp_app)

    quote do
      import Alaja.CLI.Definition, only: [command: 3, subcommand: 3, flag: 3, argument: 3, run: 1]
      Module.register_attribute(__MODULE__, :commands, accumulate: true)
      Module.register_attribute(__MODULE__, :otp_app, accumulate: false)
      @subcommand_children []
      @subcommand_depth 0
      @otp_app unquote(otp_app)
      @halt_on_error Keyword.get(unquote(opts), :halt_on_error, false)
      @before_compile Alaja.CLI.Definition
    end
  end

  # ─── DSL macros ─────────────────────────────────────────────────────

  @doc "Defines a CLI command with a name, description, and block."
  @spec command(String.t(), String.t(), do: Macro.t()) :: Macro.t()
  defmacro command(name, description, do: block) do
    quote do
      @current_command %{
        name: unquote(name),
        description: unquote(description),
        flags: [],
        arguments: [],
        subcommands: %{}
      }
      unquote(block)

      if @subcommand_depth > 0 do
        @subcommand_children [@current_command | @subcommand_children]
      else
        @commands @current_command
      end
    end
  end

  defmacro command(name, description, opts) when is_list(opts) do
    run_handler = Keyword.get(opts, :run)

    quote do
      @current_command %{
        name: unquote(name),
        description: unquote(description),
        flags: [],
        arguments: [],
        subcommands: %{},
        run: unquote(run_handler)
      }

      if @subcommand_depth > 0 do
        @subcommand_children [@current_command | @subcommand_children]
      else
        @commands @current_command
      end
    end
  end

  @doc "Defines a CLI subcommand group."
  @spec subcommand(String.t(), String.t(), do: Macro.t()) :: Macro.t()
  defmacro subcommand(name, description, do: block) do
    quote do
      @subcommand_depth @subcommand_depth + 1

      unquote(block)

      @subcommand_depth @subcommand_depth - 1
      children = @subcommand_children |> Enum.reverse()
      @subcommand_children []

      parent = %{
        name: unquote(name),
        description: unquote(description),
        flags: [],
        arguments: [],
        subcommands: Map.new(children, &{&1.name, &1}),
        run: nil
      }

      @commands parent
    end
  end

  @doc "Defines a CLI flag within a command."
  @spec flag(atom(), flag_type(), Keyword.t()) :: Macro.t()
  defmacro flag(name, type, opts \\ []) do
    unless type in @valid_flag_types do
      raise ArgumentError,
            "invalid flag type: #{inspect(type)}. " <>
              "Valid types: #{inspect(@valid_flag_types)}. " <>
              "Flag: #{name}"
    end

    quote do
      @current_command update_in(@current_command.flags, fn flags ->
                         flags ++
                           [
                             %{
                               name: unquote(name),
                               type: unquote(type),
                               default: unquote(Keyword.get(opts, :default)),
                               required: unquote(Keyword.get(opts, :required, false)),
                               values: unquote(Keyword.get(opts, :values)),
                               short: unquote(Keyword.get(opts, :short)),
                               repeatable: unquote(Keyword.get(opts, :repeatable, false)),
                               env: unquote(Keyword.get(opts, :env)),
                               min: unquote(Keyword.get(opts, :min)),
                               max: unquote(Keyword.get(opts, :max)),
                               conflicts_with: unquote(Keyword.get(opts, :conflicts_with, [])),
                               requires: unquote(Keyword.get(opts, :requires, []))
                             }
                           ]
                       end)
    end
  end

  @doc "Defines a positional argument within a command."
  @spec argument(atom(), arg_type(), Keyword.t()) :: Macro.t()
  defmacro argument(name, type, opts \\ []) do
    unless type in @valid_arg_types do
      raise ArgumentError,
            "invalid argument type: #{inspect(type)}. " <>
              "Valid types: #{inspect(@valid_arg_types)}. " <>
              "Argument: #{name}"
    end

    quote do
      @current_command update_in(@current_command.arguments, fn args ->
                         args ++
                           [
                             %{
                               name: unquote(name),
                               type: unquote(type),
                               required: unquote(Keyword.get(opts, :required, false)),
                               default: unquote(Keyword.get(opts, :default))
                             }
                           ]
                       end)
    end
  end

  @doc """
  Defines the handler for a command.

  Accepts a `{module, function_name}` tuple. The handler will be called
  with a single argument: the parsed opts map, which includes `:_args`
  (the raw positional arguments).

  ## Example

      command "deploy", "Deploy to production" do
        flag :env, :string, default: "staging"
        run {MyApp.Deploy, :run}
      end
  """
  @spec run({module(), atom()}) :: Macro.t()
  defmacro run({_mod, _fun} = tuple) do
    quote do
      @current_command Map.put(@current_command, :run, unquote(tuple))
    end
  end

  # ─── Compilation ──────────────────────────────────────────────────────

  @doc false
  @spec __before_compile__(Macro.Env.t()) :: Macro.t()
  defmacro __before_compile__(env) do
    halt_on_error = Module.get_attribute(env.module, :halt_on_error) || false
    halt_block = halt_block(halt_on_error)

    quote do
      @doc false
      def __commands__ do
        @commands |> Enum.reverse()
      end

      @doc false
      def __otp_app__ do
        @otp_app
      end

      @doc "Runs the CLI with the given arguments."
      def main(args) do
        dispatch_main(args)
      end

      @doc """
      Runs a single command without re-starting the application stack.

      This is the in-process execution path used by `alaja action` for
      batch execution. It assumes the application is already running, so
      it skips `Application.ensure_all_started/1`. Use `main/1` for the
      top-level entry point and `exec/1` for child invocations.

      ## Example

          Alaja.CLI.exec(["message", "--text", "Hello"])
      """
      @spec exec([String.t()]) :: term()
      def exec(args) do
        Alaja.CLI.Definition.dispatch(@commands |> Enum.reverse(), args)
      end

      defp dispatch_main(args) do
        # Ensure both :alaja (for the rendering stack) and the host
        # OTP application (the one declared with `use Alaja.CLI.Definition,
        # otp_app: :my_app`) are up before any command runs. Without
        # this, escript releases that ship with `include_erts: false`
        # report "could not lookup Ecto repo" or similar because their
        # supervisor tree never started.
        Application.ensure_all_started(:alaja)
        Application.ensure_all_started(__otp_app__())

        # Sync the CLI flag --no-color into the Application env BEFORE
        # any command (or help renderer) asks Alaja.Config.color_enabled?/0.
        # Without this the flag would only reach the printer level and
        # leave Alaja.Config (and therefore Alaja.Theme.color/1) reporting
        # colour as enabled. Priority stays: CLI flag > NO_COLOR env > IO.ANSI.
        Alaja.CLI.NoColor.sync(args)

        # Top-level commands that have been migrated to raise
        # `Alaja.CLI.ActionError` (and any future typed exceptions) need
        # their error rendered to stderr and the process exited with
        # status 1. Without this, the exception would propagate as an
        # Elixir crash dump — confusing for end users.
        result =
          try do
            Alaja.CLI.Definition.run_dispatch(__commands__(), args)
          rescue
            e in Alaja.CLI.ActionError ->
              IO.puts(:stderr, "Error: #{Exception.message(e)}")
              exit({:shutdown, 1})
          end

        unquote(halt_block)

        result
      end
    end
  end

  # Builds the optional halt-on-error block for `halt_on_error: true`
  # escripts. Extracted from `__before_compile__/1` to keep its
  # cyclomatic complexity within the credo limit.
  defp halt_block(true) do
    quote do
      if match?({:error, _}, result) do
        System.halt(1)
      end
    end
  end

  defp halt_block(false), do: nil

  # ─── Runtime dispatch ─────────────────────────────────────────────────

  alias Alaja.CLI.ErrorHandler
  alias Alaja.CLI.Parser

  @doc false
  @spec run_dispatch([map()], [String.t()]) :: term()
  def run_dispatch(commands, args) do
    case args do
      # Top-level help: `alaja`, `alaja --help`, `alaja -h`, and `alaja
      # help` all render the full help instead of trying to dispatch to a
      # command. `alaja` alone runs the startup showcase first on TTYs;
      # the full help is only rendered afterwards if the user asks for it.
      [] ->
        dispatch_empty(commands)

      ["--help" | _] ->
        render_full_help(commands)

      ["-h" | _] ->
        render_full_help(commands)

      ["help"] ->
        render_full_help(commands)

      ["--version" | _] ->
        render_version()

      ["-v" | _] ->
        render_version()

      _ ->
        dispatch(commands, args)
    end
  end

  defp dispatch_empty(commands) do
    if Alaja.CLI.Showcase.enabled?() do
      case Alaja.CLI.Showcase.run() do
        :help -> render_full_help(commands)
        _ -> :ok
      end
    else
      render_full_help(commands)
    end
  end

  defp render_full_help(commands) do
    # Print the available commands list as well, formatted like a
    # one-screen reference, so callers see what's available without
    # having to dig into the formatted tables.
    descriptions =
      commands
      |> Enum.map(fn %{name: name, description: desc} -> {name, desc} end)

    if Alaja.CLI.HelpTabs.interactive?() do
      # On a TTY the full help renders as tabs; the command list is
      # embedded in the Commands tab.
      Alaja.CLI.Help.full(descriptions)
    else
      Alaja.CLI.Help.full()
      Alaja.CLI.Help.summary(descriptions)
    end

    :ok
  end

  defp render_version do
    vsn = Application.spec(:alaja, :vsn) |> to_string()
    IO.puts("alaja #{vsn}")
    :ok
  end

  @doc false
  @spec dispatch([map()], [String.t()]) :: {:error, atom()} | term()
  def dispatch(commands, args) do
    dispatch(commands, args, [])
  end

  defp dispatch(commands, [name | rest], parent_flags) do
    case find_command(commands, name) do
      nil ->
        ErrorHandler.unknown_command(name, commands)

      %{subcommands: subs} = cmd when map_size(subs) > 0 ->
        dispatch_with_subcommands(cmd, rest, parent_flags)

      cmd ->
        with {:ok, flags, remaining} <- parse_flags(cmd.flags, rest) do
          execute(cmd, flags, remaining, parent_flags)
        end
    end
  end

  defp dispatch(commands, [], _parent_flags) do
    ErrorHandler.no_command(commands)
  end

  defp find_command(commands, name) when is_list(commands) do
    Enum.find(commands, &(&1.name == name))
  end

  defp find_command(commands, name) when is_map(commands) do
    Map.get(commands, name) || find_command_by_atom(commands, name)
  end

  defp find_command_by_atom(commands, name) do
    case Alaja.Helpers.safe_string_to_atom(name) do
      {:ok, atom} -> Map.get(commands, atom)
      {:error, _} -> nil
    end
  end

  defp dispatch_with_subcommands(%{subcommands: subs} = cmd, rest, parent_flags) do
    with {:ok, flags, remaining} <- parse_flags(cmd.flags, rest) do
      handle_remaining(subs, cmd, flags, remaining, parent_flags)
    end
  end

  defp handle_remaining(_subs, cmd, flags, [], parent_flags) do
    execute(cmd, flags, [], parent_flags)
  end

  defp handle_remaining(subs, cmd, flags, [sub | rest], parent_flags) do
    if subcommand_exists?(subs, sub) do
      dispatch(Map.values(subs), [sub | rest], parent_flags ++ flags)
    else
      execute(cmd, flags, [sub | rest], parent_flags)
    end
  end

  defp subcommand_exists?(subs, sub) when is_map(subs), do: Map.has_key?(subs, sub)
  defp subcommand_exists?(subs, sub), do: Enum.any?(subs, &(elem(&1, 0) == sub))

  # ─── Flag parsing ─────────────────────────────────────────────────────

  defp parse_flags(flags, args, acc \\ [])
  defp parse_flags([], args, acc), do: {:ok, acc, args}

  defp parse_flags(flags, args, acc) do
    matched = match_flag(flags, args)
    parse_matched_flag(matched, flags, args, acc)
  end

  defp parse_matched_flag(nil, _flags, args, acc), do: {:ok, acc, args}

  defp parse_matched_flag(%{type: :boolean, repeatable: true} = flag, flags, [arg | rest], acc) do
    value_already = arg =~ "=true" or arg =~ "=false"
    value = if value_already, do: String.contains?(arg, "=true"), else: true
    next = if value_already, do: rest, else: rest
    parse_flags(flags -- [flag], next, [{flag.name, value} | acc])
  end

  defp parse_matched_flag(%{type: :boolean} = flag, flags, [arg | rest], acc) do
    value_already = arg =~ "=true" or arg =~ "=false"
    value = if value_already, do: String.contains?(arg, "=true"), else: true
    next = if value_already, do: rest, else: rest
    parse_flags(flags -- [flag], next, [{flag.name, value} | acc])
  end

  defp parse_matched_flag(%{type: :boolean} = flag, _flags, [], acc) do
    parse_flags([flag], [], [{flag.name, true} | acc])
  end

  defp parse_matched_flag(%{repeatable: true} = flag, flags, [arg | rest], acc) do
    {value, remaining} = parse_flag_value(arg, rest)
    parsed = cast_flag_value(flag.type, value, flag.default)
    parse_flags(flags, remaining, [{flag.name, parsed} | acc])
  end

  defp parse_matched_flag(%{} = flag, flags, [arg | rest], acc) do
    {value, remaining} = parse_flag_value(arg, rest)
    parsed = cast_flag_value(flag.type, value, flag.default)
    parse_flags(flags -- [flag], remaining, [{flag.name, parsed} | acc])
  end

  defp parse_matched_flag(%{} = _flag, _flags, [], acc) do
    {:ok, acc, []}
  end

  defp match_flag(_flags, []), do: nil

  defp match_flag(flags, [arg | _]) do
    Enum.find(flags, fn flag ->
      full = "--#{flag.name}"
      short = flag.short && "-#{flag.short}"

      String.starts_with?(arg, full) or
        (short && String.starts_with?(arg, short))
    end)
  end

  defp parse_flag_value(arg, rest) do
    cond do
      String.contains?(arg, "=") ->
        [_name, val] = String.split(arg, "=", parts: 2)
        {val, rest}

      rest != [] and not String.starts_with?(hd(rest), "-") ->
        [val | rem] = rest
        {val, rem}

      true ->
        {nil, rest}
    end
  end

  defp cast_flag_value(:string, nil, default), do: default
  defp cast_flag_value(:string, val, _default), do: val

  defp cast_flag_value(:integer, nil, default), do: default

  defp cast_flag_value(:integer, val, default) do
    case Integer.parse(to_string(val)) do
      {n, ""} -> n
      _ -> default
    end
  end

  defp cast_flag_value(:float, nil, default), do: default

  defp cast_flag_value(:float, val, default) do
    case Float.parse(to_string(val)) do
      {f, ""} -> f
      _ -> default
    end
  end

  defp cast_flag_value(:boolean, nil, default), do: default
  defp cast_flag_value(:boolean, val, _default), do: val in [true, "true", "1"]

  defp cast_flag_value(:atom, nil, default), do: default

  defp cast_flag_value(:atom, val, _default) do
    case Alaja.Helpers.safe_string_to_atom(val) do
      {:ok, atom} -> atom
      {:error, _} -> val
    end
  end

  # Path: expand `~` and relative components. Falls back to the literal
  # value if Path.expand/1 raises (e.g. HOME unset).
  defp cast_flag_value(:path, nil, default), do: default

  defp cast_flag_value(:path, val, _default) do
    Path.expand(val)
  rescue
    _ -> val
  end

  # URL: accept only http/https URIs. Anything else (mailto, file, no
  # scheme) is rejected silently and the default is used.
  defp cast_flag_value(:url, nil, default), do: default

  defp cast_flag_value(:url, val, default) do
    case URI.parse(val) do
      %URI{scheme: scheme} when scheme in ["http", "https"] -> val
      _ -> default
    end
  end

  # color_list: `red;blue;#FF6B6B` -> [{r,g,b}, ...]. On parse error,
  # fall back to the default rather than crashing.
  defp cast_flag_value(:color_list, nil, default), do: default

  defp cast_flag_value(:color_list, val, default) do
    case Parser.parse_color_list(val) do
      {:ok, colors} -> colors
      _ -> default
    end
  end

  # ─── Execution ────────────────────────────────────────────────────────

  defp execute(cmd, flags, positional, parent_flags) do
    all_flags = parent_flags ++ flags
    flag_values = build_flag_values(cmd.flags, all_flags)

    # Validate required arguments
    case validate_required_args(cmd.arguments, parse_arguments(cmd.arguments, positional)) do
      {:error, missing} ->
        ErrorHandler.missing_args(cmd.name, missing)

      :ok ->
        validate_and_run(cmd, flag_values, positional)
    end
  end

  # Build a map of flag defaults + parsed values, shaded by:
  #   * repeatable: aggregate all values into a list
  #   * env: read from System.get_env/2 when the flag was not passed
  #     on the CLI (CLI flag wins over env var)
  defp build_flag_values(flags, all_flags) do
    flags
    |> Enum.map(fn f ->
      flag_values = Keyword.get_values(all_flags, f.name)

      cond do
        f.repeatable and flag_values != [] ->
          {f.name, flag_values}

        is_list(flag_values) and flag_values != [] ->
          {f.name, List.last(flag_values)}

        true ->
          {f.name, single_flag_value(f, all_flags)}
      end
    end)
    |> Map.new()
  end

  # Value for a non-repeatable flag: CLI value wins, then env var,
  # then default. Numeric ranges are validated when defined.
  defp single_flag_value(f, all_flags) do
    value =
      case Keyword.fetch(all_flags, f.name) do
        {:ok, v} -> v
        :error -> env_default(f)
      end

    validate_range(f, value)
  end

  defp validate_and_run(cmd, flag_values, positional) do
    # Validate mutual exclusion and requirements between flags.
    case validate_flags(cmd, flag_values) do
      {:error, msg} ->
        IO.puts(:stderr, msg)
        exit({:shutdown, 1})

      :ok ->
        opts =
          flag_values
          |> Map.merge(parse_arguments(cmd.arguments, positional))
          |> struct_to_map()
          |> Map.put(:_args, positional)

        run_handler(cmd, opts)
    end
  end

  defp run_handler(%{run: {mod, fun}}, opts) when is_atom(mod) and is_atom(fun) do
    apply(mod, fun, [opts])
  end

  defp run_handler(cmd, _opts) do
    ErrorHandler.no_handler(cmd.name)
  end

  # Default value for a flag: explicit default > env var > nil.
  defp env_default(%{env: nil, default: default}), do: default

  defp env_default(%{env: env, default: default}) when is_binary(env) do
    case System.get_env(env) do
      nil -> default
      val -> val
    end
  end

  defp env_default(%{default: default}), do: default

  defp validate_range(%{min: nil, max: nil}, value), do: value

  defp validate_range(%{min: min, max: nil}, value) when is_number(value) and value < min,
    do: raise(ArgumentError, "value #{value} is below minimum #{min}")

  defp validate_range(%{min: nil, max: max}, value) when is_number(value) and value > max,
    do: raise(ArgumentError, "value #{value} is above maximum #{max}")

  defp validate_range(%{min: min, max: max}, value)
       when is_number(value) and value >= min and value <= max,
       do: value

  defp validate_range(_, value), do: value

  # Validate mutual exclusion and cross-flag requirements.
  # Walks the command's flag definitions (not the parsed values) so
  # that the conflicts/requires lists are accessible.
  defp validate_flags(cmd, flag_values) do
    case find_conflict(cmd.flags, flag_values) do
      {a, b} ->
        {:error, "Error: conflicting flags: --#{a} and --#{b} cannot be used together"}

      nil ->
        # Requirements: if flag :a declares requires [:b], then :b
        # must also be present in flag_values.
        missing = find_missing_required(cmd.flags, flag_values)

        if missing == [],
          do: :ok,
          else:
            {:error,
             "Error: missing required flags: #{Enum.map_join(missing, ", ", &"--#{&1}")}"}
    end
  end

  # Mutual exclusion: if flag :a declares conflicts_with [:b], then
  # both :a and :b cannot be present in flag_values.
  defp find_conflict(flags, flag_values) do
    Enum.find_value(flags, fn f ->
      conflicting =
        if Map.has_key?(flag_values, f.name) and f.conflicts_with != [] do
          Enum.find(f.conflicts_with, &Map.has_key?(flag_values, &1))
        end

      if conflicting, do: {f.name, conflicting}
    end)
  end

  # Requirements: if flag :a declares requires [:b], then :b
  # must also be present in flag_values.
  defp find_missing_required(flags, flag_values) do
    Enum.flat_map(flags, fn f ->
      if Map.has_key?(flag_values, f.name) and f.requires != [] do
        Enum.filter(f.requires, &(not Map.has_key?(flag_values, &1)))
      else
        []
      end
    end)
  end

  defp validate_required_args(args, arg_values) do
    missing =
      args
      |> Enum.filter(& &1.required)
      |> Enum.map(& &1.name)
      |> Enum.reject(&(Map.has_key?(arg_values, &1) && Map.get(arg_values, &1) != nil))

    if missing == [], do: :ok, else: {:error, missing}
  end

  defp parse_arguments(args, positional) do
    Enum.zip(args, positional)
    |> Enum.map(fn
      {%{name: name, type: type}, value} -> {name, cast_arg_value(type, value)}
      {%{name: name} = arg, nil} -> {name, arg.default}
    end)
    |> Map.new()
  end

  defp cast_arg_value(:string, val), do: val

  defp cast_arg_value(:integer, val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> {:error, "invalid integer: #{inspect(val)}"}
    end
  end

  defp cast_arg_value(:float, val) do
    case Float.parse(val) do
      {float, ""} -> float
      _ -> {:error, "invalid float: #{inspect(val)}"}
    end
  end

  defp struct_to_map(%_{} = struct), do: Map.from_struct(struct)
  defp struct_to_map(map) when is_map(map), do: map
end
