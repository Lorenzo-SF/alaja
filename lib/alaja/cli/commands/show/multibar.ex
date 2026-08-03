defmodule Alaja.CLI.Commands.Show.Multibar do
  @moduledoc """
  `alaja multibar` — Multi-task progress tracker with parallel bars.

  Displays multiple progress bars simultaneously, each tracking an
  independent task with states: running, success, error, wait, info.
  """

  @help_data [
    title: "Alaja Multibar",
    subtitle: "Multi-task progress tracker with parallel bars",
    size: :small
  ]

  alias Alaja.CLI.Commands.Show.Multibar.{Data, Renderer}
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.Parser
  alias Alaja.Components.MultiBar

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
          bar_color: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
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
    border = Data.parse_border(Keyword.get(opts, :border, "rounded"))
    bar_width = Keyword.get(opts, :bar_width, @default_bar_width)
    bar_color = Parser.parse_color_opt(Keyword.get(opts, :bar_color))

    multibar_opts =
      [
        tasks: tasks,
        title: title,
        table_border: border,
        bar_width: bar_width,
        bar_color: bar_color
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

  @spec help() :: keyword()
  def help, do: @help_data
end
