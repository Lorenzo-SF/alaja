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
    allow_unknown_flags = Keyword.get(opts, :allow_unknown_flags, false)
    global_opts = Keyword.get(opts, :global_opts, true)
    catch_all = Keyword.get(opts, :catch_all)
    command_help = Keyword.get(opts, :command_help, true)

    quote do
      # Both arities are imported: `flag/3` and `argument/3` carry a
      # default for their options, but `import only:` does not make a
      # shorter call site legal, so `flag :name, :string` would not
      # resolve without listing `flag: 2` as well.
      import Alaja.CLI.Definition,
        only: [command: 3, subcommand: 3, flag: 3, flag: 2, argument: 3, argument: 2, run: 1]

      Module.register_attribute(__MODULE__, :commands, accumulate: true)
      Module.register_attribute(__MODULE__, :otp_app, accumulate: false)
      Module.register_attribute(__MODULE__, :allow_unknown_flags, accumulate: false)
      Module.register_attribute(__MODULE__, :global_opts, accumulate: false)
      Module.register_attribute(__MODULE__, :catch_all, accumulate: false)
      Module.register_attribute(__MODULE__, :command_help, accumulate: false)
      @subcommand_children []
      @subcommand_depth 0
      @otp_app unquote(otp_app)
      @allow_unknown_flags unquote(allow_unknown_flags)
      @global_opts unquote(global_opts)
      @catch_all unquote(catch_all)
      @command_help unquote(command_help)
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

  @doc """
  Defines a CLI flag within a command.

  ## Matching

  A flag matches on its **exact** long name or its exact short letter,
  never on a prefix: `--out` must not satisfy a declared `:output`, or
  `-e` a declared `:env`. Whatever follows `=` is not part of the name,
  so `--name=value` matches `--name`.

  A flag declared as `:auth_type` answers to both `--auth_type` and
  `--auth-type`. CLI convention is dashed, DSL identifiers are
  underscored, and a host should not have to spell both.

  ## Options

    * `:default` - valor por defecto
    * `:required` - obliga a pasarlo
    * `:values` - valores permitidos
    * `:short` - letra corta
    * `:repeatable` - acumula en lista
    * `:env` - variable de entorno de fallback
    * `:min` / `:max` - rango numerico
    * `:conflicts_with` - flags excluyentes
    * `:requires` - flags obligatorios si este se pasa
    * `:dashed` - `false` desactiva la variante con guiones
    * `:aliases` - nombres largos adicionales, sin `--`
    * `:help` - texto de ayuda para el help del comando
  """
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
                               requires: unquote(Keyword.get(opts, :requires, [])),
                               dashed: unquote(Keyword.get(opts, :dashed, true)),
                               aliases: unquote(Keyword.get(opts, :aliases, [])),
                               help: unquote(Keyword.get(opts, :help))
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

    generated_code(halt_block(halt_on_error))
  end

  @doc false
  @spec generated_code(Macro.t()) :: Macro.t()
  def generated_code(halt_block) do
    quote do
      unquote(accessors_block())

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
        Alaja.CLI.Definition.dispatch(
          @commands |> Enum.reverse(),
          args,
          @allow_unknown_flags,
          @catch_all
        )
      end

      defp dispatch_main(args) do
        # Ensure both :alaja (for the rendering stack) and the host
        # OTP application (the one declared with `use Alaja.CLI.Definition,
        # otp_app: :my_app`) are up before any command runs. Without
        # this, releases that ship with `include_erts: false`
        # report "could not lookup Ecto repo" or similar because their
        # supervisor tree never started.
        unquote(startup_block())

        # Top-level commands that have been migrated to raise
        # `Alaja.CLI.ActionError` (and any future typed exceptions) need
        # their error rendered to stderr and the process exited with
        # status 1. Without this, the exception would propagate as an
        # Elixir crash dump — confusing for end users.
        # `<command> --help` prints that one command's help. Handled here,
        # before global extraction, because `GlobalOpts.parse/1` would
        # strip `--help` and the command would then run without it -
        # usually failing on a missing required flag.
        #
        # `command_help: false` is for hosts whose commands render their
        # own richer help from inside their handler (Alaja's own CLI does
        # exactly that, with per-command examples and descriptions).
        unquote(help_exit_block())

        dispatch_args(args)
      end

      unquote(dispatch_block(halt_block))
    end
  end

  # Read-only accessors for the `use` options, so a host can branch on how
  # the DSL was configured instead of hardcoding the assumptions.
  defp accessors_block do
    quote do
      @doc false
      def __commands__ do
        @commands |> Enum.reverse()
      end

      @doc false
      def __otp_app__, do: @otp_app

      @doc false
      def __allow_unknown_flags__, do: @allow_unknown_flags

      @doc false
      def __global_opts__, do: @global_opts

      @doc false
      def __catch_all__, do: @catch_all

      @doc false
      def __command_help__, do: @command_help
    end
  end

  # The actual dispatch, with the host's error translation.
  #
  # `Alaja.CLI.Exit` carries the host's own exit code, so a host that
  # distinguishes failure kinds (Acho: 10 unresolved variable, 20
  # network, 40 assertion) gets them out of the box. `ActionError` keeps
  # its historical meaning: exit 1.
  #
  # Global options are deliberately NOT stripped here: every handler
  # reads the ones it wants from the raw args, so a host that declares
  # `--box` for its own purpose can set `global_opts: false` and keep the
  # token for itself. See `__global_opts__/0`.
  defp dispatch_block(halt_block) do
    quote do
      defp dispatch_args(args) do
        result =
          try do
            Alaja.CLI.Definition.run_dispatch(
              __commands__(),
              args,
              __otp_app__(),
              __allow_unknown_flags__(),
              __catch_all__()
            )
          rescue
            e in Alaja.CLI.Exit ->
              IO.puts(:stderr, "Error: #{Exception.message(e)}")
              exit({:shutdown, e.exit_code})

            e in Alaja.CLI.ActionError ->
              IO.puts(:stderr, "Error: #{Exception.message(e)}")
              exit({:shutdown, 1})
          end

        unquote(halt_block)

        result
      end
    end
  end

  # Ensures the rendering stack and the host application are up, and syncs
  # the `--no-color` flag into the Application env BEFORE any command (or
  # help renderer) asks `Alaja.Config.color_enabled?/0`. Without the sync
  # the flag would only reach the printer level and leave `Alaja.Theme`
  # reporting colour as enabled. Priority: CLI flag > NO_COLOR env > IO.ANSI.
  defp startup_block do
    quote do
      Application.ensure_all_started(:alaja)
      Application.ensure_all_started(__otp_app__())
      Alaja.CLI.NoColor.sync(args)
    end
  end

  # `<command> --help` prints that one command's help and returns without
  # running it.
  #
  # `:error` from `render_command_help_for/3` means the first token names
  # no declared command, so the host's `catch_all` handler may still own
  # it: a stored entity name, or a hot call that starts straight with
  # flags. That case falls through to the normal dispatch.
  #
  # `command_help: false` is for hosts whose commands render their own
  # richer help from inside their handler (Alaja's own CLI does exactly
  # that, with per-command examples and descriptions).
  defp help_exit_block do
    quote do
      help_exit =
        if __command_help__() do
          Alaja.CLI.Definition.help_requested_and_rendered?(
            __commands__(),
            __otp_app__(),
            args
          )
        else
          false
        end

      if help_exit, do: :ok
    end
  end

  # Builds the optional halt-on-error block for `halt_on_error: true`
  # releases. Extracted from `__before_compile__/1` to keep its
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
  @spec run_dispatch([map()], [String.t()], atom(), boolean(), {module(), atom()} | nil) :: term()
  def run_dispatch(commands, args, otp_app, allow_unknown_flags \\ false, catch_all \\ nil) do
    case args do
      # Top-level help: `alaja`, `alaja --help`, `alaja -h`, and `alaja
      # help` all render the full help instead of trying to dispatch to a
      # command. `alaja` alone runs the startup showcase first on TTYs;
      # the full help is only rendered afterwards if the user asks for it.
      [] ->
        dispatch_empty(commands, otp_app)

      ["--help" | _] ->
        render_full_help(commands, otp_app)

      ["-h" | _] ->
        render_full_help(commands, otp_app)

      ["help"] ->
        render_full_help(commands, otp_app)

      ["--version" | _] ->
        render_version(otp_app)

      ["-v" | _] ->
        render_version(otp_app)

      _ ->
        dispatch(commands, args, [], allow_unknown_flags, catch_all)
    end
  end

  # `["cmd", "--help"]` asks for the help of that single command;
  # `["--help"]` alone is the top-level help, handled above.
  @doc false
  @spec command_help([String.t()]) :: :ok | {:help, [String.t()]}
  def command_help([first | _] = args) do
    if String.starts_with?(first, "-") do
      :ok
    else
      if command_help_requested?(args), do: {:help, args}, else: :ok
    end
  end

  def command_help(_args), do: :ok

  @doc """
  Devuelve `true` cuando los args piden el help de un comando concreto y
  ese help se ha renderizado. `false` cuando el comando no existe (para
  que un host con `catch_all` siga su camino) o cuando no se pidió help.
  """
  @spec help_requested_and_rendered?([map()], atom(), [String.t()]) :: boolean()
  def help_requested_and_rendered?(commands, otp_app, args) do
    case command_help(args) do
      :ok -> false
      {:help, help_args} -> render_command_help_for(commands, otp_app, help_args) == :ok
    end
  end

  @doc """
  `alaja <command> --help` renders the help of that command instead of
  failing with "missing required flag".
  """
  @spec command_help_requested?([String.t()]) :: boolean()
  def command_help_requested?(args), do: Enum.any?(args, &(&1 in ["--help", "-h"]))

  @doc "Elimina `--help` / `-h` de una lista de argumentos."
  @spec strip_help_flag([String.t()]) :: [String.t()]
  def strip_help_flag(args), do: Enum.reject(args, &(&1 in ["--help", "-h"]))

  @doc """
  Renders the help of the command named by the first element of `args`,
  descending into subcommand groups when needed.

  Returns `{:error, :unknown_command}` when the first element names no
  declared command, so the caller can fall back to its own dispatch -
  which is how a host with a `catch_all` handler claims a token that is
  not a command at all.
  """
  @spec render_command_help_for([map()], atom(), [String.t()]) :: :ok | {:error, :unknown_command}
  def render_command_help_for(commands, otp_app, [name | rest]) do
    if String.starts_with?(name, "-") do
      :ok
    else
      render_named_help(commands, otp_app, name, rest)
    end
  end

  def render_command_help_for(_commands, _otp_app, _args), do: :ok

  defp render_named_help(commands, otp_app, name, rest) do
    case find_command(commands, name) do
      nil -> {:error, :unknown_command}
      cmd -> render_found_help(cmd, otp_app, rest)
    end
  end

  defp render_found_help(%{subcommands: subs} = cmd, otp_app, rest) when map_size(subs) > 0 do
    case rest do
      [sub | tail] -> render_sub_help(subs, cmd, sub, tail, otp_app)
      _ -> render_group_help(cmd)
    end
  end

  defp render_found_help(cmd, otp_app, _rest), do: render_command_help(cmd, otp_app)

  defp render_sub_help(subs, cmd, sub, tail, otp_app) do
    case Map.get(subs, sub) do
      nil -> render_group_help(cmd)
      sub_cmd -> maybe_render_command_help(sub_cmd, tail, otp_app)
    end
  end

  # A command that also has a handler: the help flag has already been
  # stripped before its flags are parsed.
  defp maybe_render_command_help(cmd, rest, otp_app) do
    if command_help_requested?(rest) do
      render_command_help(cmd, otp_app)
      true
    else
      false
    end
  end

  defp render_group_help(%{subcommands: subs} = cmd) do
    names = subs |> Map.keys() |> Enum.sort()

    Alaja.CLI.HelpFormatter.render(
      title: cmd.name,
      subtitle: cmd.description,
      usage: ["#{cmd.name} [#{Enum.join(names, " | ")}]"],
      options: [],
      globals: false,
      global_opts: %Alaja.CLI.GlobalOpts{}
    )

    :ok
  end

  defp render_command_help(cmd, otp_app) do
    Alaja.CLI.HelpFormatter.render(
      title: "#{otp_app} #{cmd.name}",
      subtitle: cmd.description,
      usage: usage_lines(otp_app, cmd),
      options: option_rows(cmd),
      globals: false,
      global_opts: %Alaja.CLI.GlobalOpts{}
    )

    :ok
  end

  defp usage_lines(otp_app, cmd) do
    ["#{otp_app} #{cmd.name}"]
    |> Kernel.++(Enum.map(cmd.flags, &flag_token/1))
    |> Kernel.++(Enum.map(cmd.arguments, &argument_token/1))
  end

  defp flag_token(%{type: :boolean} = flag) do
    if flag.short, do: "  --#{flag.name}/-#{flag.short}", else: "  --#{flag.name}"
  end

  defp flag_token(%{required: true, short: short} = flag) when not is_nil(short) do
    "  --#{flag.name}/-#{short} <#{type_label(flag.type)}>"
  end

  defp flag_token(%{required: true} = flag) do
    "  --#{flag.name} <#{type_label(flag.type)}>"
  end

  defp flag_token(%{short: short} = flag) when not is_nil(short) do
    "  [--#{flag.name}/-#{short} <#{type_label(flag.type)}>]"
  end

  defp flag_token(flag), do: "  [--#{flag.name} <#{type_label(flag.type)}>]"

  defp argument_token(%{name: name, required: true}), do: "  <#{name}>"
  defp argument_token(%{name: name}), do: "  [<#{name}>]"

  defp option_rows(cmd) do
    Enum.map(cmd.flags, fn flag ->
      name = if flag.short, do: "#{display_name(flag)}/-#{flag.short}", else: display_name(flag)
      {name, option_type(flag), flag.default, flag.help || ""}
    end) ++
      Enum.map(cmd.arguments, fn arg ->
        {"<#{arg.name}>", to_string(arg.type), arg.default, ""}
      end)
  end

  # `--auth-type` rather than `--auth_type`, plus any alias.
  defp display_name(flag) do
    case accepted_long_names(flag) do
      [] -> "--#{flag.name}"
      [first | rest] -> Enum.join([first | rest], ", ")
    end
  end

  defp option_type(%{type: :boolean}), do: :flag
  defp option_type(%{required: true} = flag), do: "#{type_label(flag.type)} (required)"
  defp option_type(flag), do: type_label(flag.type)

  defp type_label(:string), do: "value"
  defp type_label(:integer), do: "N"
  defp type_label(:float), do: "N"
  defp type_label(:atom), do: "atom"
  defp type_label(:path), do: "path"
  defp type_label(:url), do: "url"
  defp type_label(:color_list), do: "color"
  defp type_label(:keep), do: "value"
  defp type_label(type), do: to_string(type)

  defp dispatch_empty(commands, otp_app) do
    # The alaja welcome showcase (pulsar animation + interactive prompt)
    # is alaja-specific and only makes sense when alaja itself is the
    # host. For external apps that consume `Alaja.CLI.Definition` via
    # the DSL, skip it entirely and render the host's command summary.
    if otp_app == :alaja and Alaja.CLI.Showcase.enabled?() do
      case Alaja.CLI.Showcase.run() do
        :help -> render_full_help(commands, otp_app)
        _ -> :ok
      end
    else
      render_full_help(commands, otp_app)
    end
  end

  defp render_full_help(commands, otp_app) do
    # Print the available commands list as well, formatted like a
    # one-screen reference, so callers see what's available without
    # having to dig into the formatted tables.
    descriptions =
      commands
      |> Enum.map(fn %{name: name, description: desc} -> {name, desc} end)

    if otp_app == :alaja do
      # Internal alaja CLI: render the full alaja reference (typed
      # messages, display commands, cookbook, theme, action, ...).
      if Alaja.CLI.HelpTabs.interactive?() do
        # On a TTY the full help renders as tabs; the command list is
        # embedded in the Commands tab.
        Alaja.CLI.Help.full(descriptions)
      else
        Alaja.CLI.Help.full()
        Alaja.CLI.Help.summary(descriptions)
      end
    else
      # External host (arrea, delfos, elpaso, zaguan, candil, botica,
      # apero, pote, trebejo, ...): never render alaja's own reference.
      # Only the host's command list is shown, branded with the host's
      # application name and version.
      render_host_help(descriptions, otp_app)
    end

    :ok
  end

  defp render_host_help(descriptions, otp_app) do
    app_title = otp_app |> Atom.to_string() |> String.capitalize()
    vsn = app_version(otp_app)
    app_name = to_string(otp_app)

    Alaja.Components.Header.print(app_title,
      subtitle: "v#{vsn} · Complete command reference",
      size: :medium,
      color: {0, 180, 216},
      subtitle_color: {150, 150, 160}
    )

    IO.puts("")

    rows = Enum.map(descriptions, fn {cmd, desc} -> [cmd, desc] end)

    Alaja.Components.Table.print(
      headers: ["Command", "Description"],
      rows: rows,
      table_border: :rounded,
      border_color: {0, 180, 216},
      headers_color: :cyan,
      headers_effects: [:bold],
      padding: 1
    )

    IO.puts("")

    IO.puts("Run '#{app_name} <command> --help' for the full option list of a specific command.")

    :ok
  end

  # Reads the host application's own version from its Application spec,
  # so an external host's `--version` reports its own semver, not alaja's.
  defp app_version(otp_app) do
    case Application.spec(otp_app, :vsn) do
      nil -> "0.0.0"
      vsn -> to_string(vsn)
    end
  end

  defp render_version(otp_app) do
    vsn = app_version(otp_app)
    IO.puts("#{otp_app} #{vsn}")
    :ok
  end

  @doc false
  @spec dispatch([map()], [String.t()], boolean()) :: {:error, atom()} | term()
  def dispatch(commands, args, allow_unknown_flags \\ false) do
    dispatch(commands, args, [], allow_unknown_flags, nil)
  end

  @doc """
  Dispatch with an explicit `catch_all` handler, for hosts and tests that
  drive the dispatcher directly.
  """
  @spec dispatch([map()], [String.t()], boolean(), {module(), atom()} | nil) ::
          {:error, atom()} | term()
  def dispatch(commands, args, allow_unknown_flags, catch_all) do
    dispatch(commands, args, [], allow_unknown_flags, catch_all)
  end

  defp dispatch(commands, [name | rest], parent_flags, allow_unknown_flags, catch_all) do
    case find_command(commands, name) do
      nil ->
        run_catch_all(catch_all, name, rest, commands)

      %{subcommands: subs} = cmd when map_size(subs) > 0 ->
        dispatch_with_subcommands(cmd, rest, parent_flags, allow_unknown_flags)

      cmd ->
        case parse_flags(cmd.flags, rest, allow_unknown_flags) do
          {:ok, flags, remaining} ->
            execute(cmd, flags, remaining, parent_flags)

          {:error, msg} ->
            IO.puts(:stderr, msg)
            exit({:shutdown, 1})
        end
    end
  end

  defp dispatch(commands, [], _parent_flags, _allow_unknown_flags, catch_all) do
    case catch_all do
      nil -> ErrorHandler.no_command(commands)
      {mod, fun} -> apply(mod, fun, [%{name: nil, _args: []}])
    end
  end

  # A host with a `catch_all` handler owns the "no such command" path. A
  # first token that is not a declared command may still be a valid
  # target: the name of a stored entity, or nothing at all when the
  # invocation starts straight with flags (a hot call). The handler
  # receives `%{name: token | nil, _args: [token | rest]}` and decides.
  defp run_catch_all(nil, name, _rest, commands) do
    ErrorHandler.unknown_command(name, commands)
  end

  defp run_catch_all({mod, fun}, name, rest, _commands) do
    apply(mod, fun, [%{name: name, _args: [name | rest]}])
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

  defp dispatch_with_subcommands(
         %{subcommands: subs} = cmd,
         rest,
         parent_flags,
         allow_unknown_flags
       ) do
    case parse_flags(cmd.flags, rest, allow_unknown_flags) do
      {:ok, flags, remaining} ->
        if command_help_requested?(remaining) and remaining == [] do
          render_group_help(cmd)
        else
          handle_remaining(subs, cmd, flags, remaining, parent_flags, allow_unknown_flags)
        end

      {:error, msg} ->
        IO.puts(:stderr, msg)
        exit({:shutdown, 1})
    end
  end

  defp handle_remaining(_subs, cmd, flags, [], parent_flags, _allow_unknown_flags) do
    execute(cmd, flags, [], parent_flags)
  end

  defp handle_remaining(subs, cmd, flags, [sub | rest], parent_flags, allow_unknown_flags) do
    if subcommand_exists?(subs, sub) do
      dispatch(Map.values(subs), [sub | rest], parent_flags ++ flags, allow_unknown_flags, nil)
    else
      execute(cmd, flags, [sub | rest], parent_flags)
    end
  end

  defp subcommand_exists?(subs, sub) when is_map(subs), do: Map.has_key?(subs, sub)
  defp subcommand_exists?(subs, sub), do: Enum.any?(subs, &(elem(&1, 0) == sub))

  # ─── Flag parsing ─────────────────────────────────────────────────────

  # Los posicionales no cortan el parseo: `promote <hash> --name=x` es
  # tan válido como `promote --name=x <hash>`, que es como lo escribe
  # cualquiera cuando el hash va primero. Un token que no casa con
  # ningún flag y no parece un flag se apila como posicional y el
  # parseo **sigue**.
  defp parse_flags(flags, args, allow_unknown_flags, acc \\ [], loose \\ [])
  # `loose` se acumula por delante, así que se invierte al volver a
  # pegarlo: `secrets list t` tiene que llegar como ["list", "t"] y no
  # al revés, que es como se asignan a los `argument` declarados.
  defp parse_flags([], args, _allow_unknown_flags, acc, loose),
    do: {:ok, acc, args ++ Enum.reverse(loose)}

  defp parse_flags(flags, args, allow_unknown_flags, acc, loose) do
    matched = match_flag(flags, args)
    parse_matched_flag(matched, flags, args, allow_unknown_flags, acc, loose)
  end

  # Cuando `match_flag/2` devuelve nil, el token es un posicional, un
  # flag global (que los handlers leen de los args crudos) o un flag
  # desconocido.
  #
  # Un posicional se apila y el parseo sigue: `acho <call> --payload=x`
  # es la forma más escrita del mundo. Un flag desconocido **sí** corta,
  # porque tragárselo convertiría un error de tipeo en un "no pasó nada"
  # silencioso: `arrea run --comand "x"` dejaría de decir "quiso decir
  # --command?".
  defp parse_matched_flag(nil, flags, [arg | rest] = args, allow_unknown_flags, acc, loose)
       when is_binary(arg) do
    if String.starts_with?(arg, "-") do
      case reject_unknown_flag(flags, arg, allow_unknown_flags) do
        :ok -> {:ok, acc, args}
        {:error, _} = err -> err
      end
    else
      parse_flags(flags, rest, allow_unknown_flags, acc, [arg | loose])
    end
  end

  defp parse_matched_flag(nil, _flags, args, _allow_unknown_flags, acc, loose),
    do: {:ok, acc, args ++ Enum.reverse(loose)}

  defp parse_matched_flag(
         %{type: :boolean, repeatable: true} = flag,
         flags,
         [arg | rest],
         allow_unknown_flags,
         acc,
         loose
       ) do
    value_already = arg =~ "=true" or arg =~ "=false"
    value = if value_already, do: String.contains?(arg, "=true"), else: true
    parse_flags(flags -- [flag], rest, allow_unknown_flags, [{flag.name, value} | acc], loose)
  end

  defp parse_matched_flag(
         %{type: :boolean} = flag,
         flags,
         [arg | rest],
         allow_unknown_flags,
         acc,
         loose
       ) do
    value_already = arg =~ "=true" or arg =~ "=false"
    value = if value_already, do: String.contains?(arg, "=true"), else: true
    parse_flags(flags -- [flag], rest, allow_unknown_flags, [{flag.name, value} | acc], loose)
  end

  defp parse_matched_flag(%{type: :boolean} = flag, _flags, [], allow_unknown_flags, acc, loose) do
    parse_flags([flag], [], allow_unknown_flags, [{flag.name, true} | acc], loose)
  end

  defp parse_matched_flag(
         %{repeatable: true} = flag,
         flags,
         [arg | rest],
         allow_unknown_flags,
         acc,
         loose
       ) do
    {value, remaining} = parse_flag_value(arg, rest)
    parsed = cast_flag_value(flag.type, value, flag.default)
    parse_flags(flags, remaining, allow_unknown_flags, [{flag.name, parsed} | acc], loose)
  end

  defp parse_matched_flag(%{} = flag, flags, [arg | rest], allow_unknown_flags, acc, loose) do
    {value, remaining} = parse_flag_value(arg, rest)
    parsed = cast_flag_value(flag.type, value, flag.default)

    parse_flags(
      flags -- [flag],
      remaining,
      allow_unknown_flags,
      [{flag.name, parsed} | acc],
      loose
    )
  end

  defp parse_matched_flag(%{} = _flag, _flags, [], _allow_unknown_flags, acc, loose),
    do: {:ok, acc, Enum.reverse(loose)}

  defp match_flag(_flags, []), do: nil

  defp match_flag(flags, [arg | _]) do
    Enum.find(flags, &flag_matches?(&1, arg))
  end

  # A flag matches on its **exact** name, never on a prefix, and whatever
  # follows `=` is not part of the name. A prefix match would let `--out`
  # satisfy a declared `:output`, and `-e` a declared `:env`, silently
  # stealing the value from the flag the user actually meant.
  defp flag_matches?(flag, arg) do
    {bare, _value} = split_value(arg)

    long_matches?(flag, bare) or short_matches?(flag, arg)
  end

  defp long_matches?(flag, bare) do
    String.starts_with?(bare, "--") and bare in accepted_long_names(flag)
  end

  defp short_matches?(%{short: nil}, _arg), do: false

  defp short_matches?(flag, arg) do
    not String.starts_with?(arg, "--") and
      String.starts_with?(arg, "-") and
      String.contains?(arg, "-#{flag.short}")
  end

  @doc """
  Los nombres largos, con `--`, con los que responde un flag.
  """
  @spec accepted_long_names(map()) :: [String.t()]
  def accepted_long_names(flag) do
    dashed? = Map.get(flag, :dashed, true)
    aliases = Map.get(flag, :aliases, []) || []
    underscored = Atom.to_string(flag.name)
    dashed = String.replace(underscored, "_", "-")

    base = if underscored == dashed, do: [underscored], else: [underscored, dashed]
    base = if dashed?, do: base, else: Enum.reject(base, &(&1 == dashed))

    Enum.map(base ++ aliases, &("--" <> &1))
  end

  defp split_value(arg) do
    case String.split(arg, "=", parts: 2) do
      [name] -> {name, nil}
      [name, value] -> {name, value}
    end
  end

  # Detect a flag-like argument that no known flag matches. We
  # only flag strings that look like flags (`-x`, `--xxx`, with or
  # without `=value`). Anything else is a positional and passes
  # through to `parse_arguments` as before.
  #
  # When `allow_unknown_flags` is true, unknown flags are passed
  # through to `opts[:_args]` instead of being rejected. This is
  # useful for CLIs that accept dynamic flags (e.g. `acho new-env
  # --url=... --user=...`).
  defp reject_unknown_flag(_flags, _arg, true), do: :ok

  defp reject_unknown_flag(flags, arg, _allow_unknown_flags) do
    cond do
      arg in ["--", "-"] ->
        :ok

      String.starts_with?(arg, "-") ->
        bare = arg |> String.trim_leading("-") |> String.split("=") |> hd()
        names = Enum.map(flags, & &1.name)
        {:error, unknown_flag_message(arg, bare, names)}

      true ->
        :ok
    end
  end

  defp unknown_flag_message(arg, bare, names) do
    suggestions = suggest_bare(bare, names)
    base = "Error: unknown flag '#{arg}'"

    if suggestions == [] do
      base
    else
      base <> "\n  Did you mean? " <> Enum.map_join(suggestions, ", ", &"--#{&1}")
    end
  end

  # Suggest similar flag names from the current command's flag set.
  # Same Jaro distance heuristic as `Alaja.CLI.ErrorHandler.suggest/2`.
  # `names` here is a list of flag atoms, so we coerce each one to a
  # binary before scoring against `bare`.
  defp suggest_bare(bare, names) do
    bare_lc = String.downcase(bare)

    names
    |> Enum.map(&to_string/1)
    |> Enum.filter(fn name ->
      String.jaro_distance(bare_lc, String.downcase(name)) > 0.6
    end)
    |> Enum.sort_by(fn name ->
      -String.jaro_distance(bare_lc, String.downcase(name))
    end)
    |> Enum.take(3)
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
            {:error, "Error: missing required flags: #{Enum.map_join(missing, ", ", &"--#{&1}")}"}
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

  # Two checks: (1) a flag declared `required: true` must have a
  # non-nil value present in `flag_values`; (2) a flag declared
  # `requires: [:a, :b]` must have every named sibling also present.
  #
  # `Map.has_key?/2` returns true even when the value is `nil`
  # (which is what we get when the user did not pass the flag at
  # all and there's no default), so we explicitly check for non-nil
  # in case (1).
  defp find_missing_required(flags, flag_values) do
    Enum.flat_map(flags, fn f ->
      cross_requires =
        if Map.has_key?(flag_values, f.name) and f.requires != [] do
          Enum.filter(f.requires, &(not Map.has_key?(flag_values, &1)))
        else
          []
        end

      direct_required =
        if f.required and
             (not Map.has_key?(flag_values, f.name) or
                Map.get(flag_values, f.name) == nil) do
          [f.name]
        else
          []
        end

      cross_requires ++ direct_required
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
