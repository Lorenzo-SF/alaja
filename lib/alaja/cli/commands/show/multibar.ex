defmodule Alaja.CLI.Commands.Show.Multibar do
  @moduledoc """
  `alaja multibar` — Multi-task progress tracker with parallel bars.

  Displays multiple progress bars simultaneously, each tracking an
  independent task with states: running, success, error, wait, info.
  """

  alias Alaja.CLI.Color
  alias Alaja.CLI.Commands.Show.Multibar.{Data, Renderer}
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.MultiBar
  alias Alaja.Helpers

  @help_data [
    title: "Alaja Multibar",
    subtitle: "Multi-task progress tracker with parallel bars",
    usage:
      "alaja multibar --tasks 'id1:Title 1,id2:Title 2' [--title T] [--duration N] [--stdin] [--border normal|rounded|double|none] [--bar-width N] [--bar-color C] [--bar-empty-char C] [--bar-filled-char C] [--table-border normal|rounded|double|none] [--table-align left|center|right] [--status-color C]",
    description: """
    Drives multiple parallel progress bars. Without `--stdin`, runs a
    5-second demo. With `--stdin`, reads commands like
    `progress <id> <pct>` from stdin for scripting.
    """,
    options: [
      {:tasks, :string, nil, "Comma-separated list of `id:Title` pairs (required)"},
      {:title, :string, nil, "Optional title above the table"},
      {:duration, :integer, 5, "Total demo duration in seconds"},
      {:stdin, :boolean, false, "Read commands from stdin instead of demo mode"},
      {:border, :string, "rounded", "Outer box border style"},
      {:bar_width, :integer, 35, "Width of each bar in chars"},
      {:bar_color, :string, nil, "Color of the bar fill"},
      {:bar_empty_char, :string, "░", "Character for empty bar segments"},
      {:bar_filled_char, :string, "▓", "Character for filled bar segments"},
      {:table_border, :string, "normal", "Inner table border style"},
      {:table_align, :string, "left", "Column alignment in the table"},
      {:status_color, :string, nil,
       "Comma-separated per-status colors (running,success,error,wait,info)"}
    ],
    examples: [
      {"Demo (5s)", "alaja multibar --tasks 'build:Building,test:Testing,lint:Linting'"},
      {"Long demo (15s)", "alaja multibar --tasks 'a:Task A,b:Task B' --duration 15"},
      {"Custom title",
       "alaja multibar --tasks 'build:Build,test:Tests' --title \"CI pipeline\" --duration 10"},
      {"Stdin-driven", "alaja multibar --tasks 'a:Task A,b:Task B' --stdin --duration 30"},
      {"Coloured bars",
       "alaja multibar --tasks 'a:A,b:B' --bar-color green --bar-empty-char '.' --duration 8"}
    ]
  ]

  @default_duration 5
  @default_bar_width 35
  @tick_ms 200

  @doc "Runs the `alaja multibar` command — drives all bars concurrently until each finishes or its duration elapses."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, _positional, _} =
      OptionParser.parse(rest,
        switches: [
          tasks: :string,
          title: :string,
          duration: :integer,
          stdin: :boolean,
          border: :string,
          bar_width: :integer,
          bar_color: :string,
          bar_empty_char: :string,
          bar_filled_char: :string,
          table_border: :string,
          table_align: :string,
          status_color: :string
        ]
      )

    if global.help do
      help()
    else
      run_multibar(opts, global)
    end
  end

  defp run_multibar(opts, global) do
    tasks_str = Keyword.get(opts, :tasks)

    if is_nil(tasks_str) or tasks_str == "" do
      help()
    else
      case Data.parse_tasks(tasks_str) do
        {:ok, tasks} ->
          run_multibar_with_tasks(opts, global, tasks)

        {:error, msg} ->
          IO.puts(:stderr, "Error: #{msg}")
          exit({:shutdown, 1})
      end
    end
  end

  defp run_multibar_with_tasks(opts, global, tasks) do
    title = Keyword.get(opts, :title)
    duration = Keyword.get(opts, :duration, @default_duration)
    box_border = Data.parse_border(Keyword.get(opts, :border, "rounded"))
    bar_width = Keyword.get(opts, :bar_width, @default_bar_width)
    bar_color = Color.parse_or_nil(Keyword.get(opts, :bar_color))
    bar_empty_char = Keyword.get(opts, :bar_empty_char)
    bar_filled_char = Keyword.get(opts, :bar_filled_char)
    table_border = Data.parse_border(Keyword.get(opts, :table_border, "normal"))
    table_align = parse_align(Keyword.get(opts, :table_align))
    status_color = Color.parse_or_nil(Keyword.get(opts, :status_color))

    multibar_opts =
      [
        tasks: tasks,
        title: title,
        box_border: box_border,
        table_border: table_border,
        table_align: table_align,
        bar_width: bar_width,
        bar_color: bar_color,
        bar_empty_char: bar_empty_char,
        bar_filled_char: bar_filled_char,
        status_color: status_color
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    if global.stdin or Keyword.get(opts, :stdin, false) do
      run_stdin_mode(multibar_opts, global)
    else
      run_demo_mode(multibar_opts, global, duration)
    end
  end

  defp run_demo_mode(multibar_opts, _global, duration_sec) do
    duration_ms = duration_sec * 1000
    ticks = max(1, div(duration_ms, @tick_ms))
    tasks = Keyword.get(multibar_opts, :tasks, [])

    task_state_map = Map.new(tasks, fn t -> {t.id, :running} end)
    progress_map = Map.new(tasks, fn t -> {t.id, 0} end)

    case MultiBar.start_link(multibar_opts) do
      {:ok, pid} ->
        run_demo_animation(pid, ticks, multibar_opts, task_state_map, progress_map, tasks)

      {:error, reason} ->
        IO.puts(:stderr, "Error starting MultiBar: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp run_demo_animation(pid, ticks, opts, task_state_map, progress_map, tasks) do
    # credo:disable-for-next-line
    try do
      Renderer.demo_loop(pid, ticks, opts, task_state_map, progress_map)

      total = length(tasks)

      failed =
        Enum.count(tasks, fn t ->
          case Process.get({:task_state, t.id}, :running) do
            :failed -> true
            _ -> false
          end
        end)

      succeeded = total - failed

      Process.put(:demo_summary, {failed, succeeded, total})

      Process.sleep(@tick_ms * 2)
    after
      MultiBar.done(pid)

      Renderer.print_demo_summary()

      Process.delete(:demo_summary)

      Enum.each(tasks, fn t -> Process.delete({:task_state, t.id}) end)
    end
  end

  defp run_stdin_mode(multibar_opts, _global) do
    if Renderer.stdin_tty?() do
      IO.puts("Multibar stdin mode — reading commands from pipe...")
      IO.puts("Use: echo 'progress tdai 50' | alaja multibar --tasks 'tdai:TD-AI' --stdin")
      IO.puts("")
      help()
    end

    case MultiBar.start_link(multibar_opts) do
      {:ok, pid} ->
        try do
          Renderer.read_stdin_loop(pid)
        after
          MultiBar.done(pid)
        end

      {:error, reason} ->
        IO.puts(:stderr, "Error starting MultiBar: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  # parse_color/1 delegates to Alaja.CLI.Color.parse_or_nil/1

  defp parse_align(nil), do: nil
  defp parse_align(s) when is_binary(s), do: Helpers.safe_string_to_atom(s)
  defp parse_align(_), do: nil

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
