defmodule Mix.Tasks.CheckOban do
  @moduledoc """
  Check Oban job status and diagnostics.

  Usage: mix check_oban [queue_name]
  """
  use Mix.Task

  @shortdoc "Check Oban job status"

  def run([]) do
    run(["all"])
  end

  def run([queue_name]) do
    Mix.Task.run("app.start")

    import Ecto.Query
    alias Emailgator.Repo

    IO.puts("\n=== Oban Job Status ===")

    queues = if queue_name == "all", do: ["poll", "import", "archive", "unsubscribe"], else: [queue_name]

    Enum.each(queues, fn queue ->
      IO.puts("\n--- Queue: #{queue} ---")

      # Count by state
      counts = Repo.all(
        from j in Oban.Job,
        where: j.queue == ^queue,
        select: {fragment("?", j.state), count(j.id)},
        group_by: j.state
      )

      IO.puts("Jobs by state:")
      Enum.each(counts, fn {state, count} ->
        IO.puts("  #{state}: #{count}")
      end)

      # Show recent jobs
      recent = Repo.all(
        from j in Oban.Job,
        where: j.queue == ^queue,
        order_by: [desc: j.inserted_at],
        limit: 5,
        select: %{
          id: j.id,
          state: j.state,
          attempt: j.attempt,
          inserted_at: j.inserted_at,
          scheduled_at: j.scheduled_at,
          errors: fragment("array_length(?, 1)", j.errors)
        }
      )

      if length(recent) > 0 do
        IO.puts("\nRecent jobs:")
        Enum.each(recent, fn job ->
          IO.puts("  ID: #{job.id}, State: #{job.state}, Attempt: #{job.attempt}, Errors: #{job.errors}")
          IO.puts("    Inserted: #{inspect(job.inserted_at)}, Scheduled: #{inspect(job.scheduled_at)}")
        end)
      end
    end)

    IO.puts("\n=== Oban Plugins ===")
    plugins = Oban.config() |> Keyword.get(:plugins, [])
    Enum.each(plugins, fn plugin ->
      IO.puts("  #{inspect(plugin)}")
    end)

    IO.puts("\n=== Oban Queues Configuration ===")
    queues_config = Oban.config() |> Keyword.get(:queues, [])
    Enum.each(queues_config, fn {queue, concurrency} ->
      IO.puts("  #{queue}: #{concurrency} concurrent workers")
    end)
  end
end
