defmodule Ant.WorkerUniquenessChecker do
  @moduledoc """
  Handles uniqueness checking for workers to prevent duplicate job creation.
  """

  alias Ant.Worker
  alias Ant.Workers

  @doc """
  Checks if a worker with the same unique attributes already exists.

  Returns `:ok` if no duplicate exists, or `{:error, :already_exists}` if a duplicate is found.
  """
  @spec call(Ant.Worker.t()) :: :ok | {:error, :already_exists}
  def call(worker) do
    unique_config = Keyword.get(worker.opts, :unique, [])
    unique_attributes = Keyword.get(unique_config, :args, [])
    statuses = Keyword.get(unique_config, :statuses, [:enqueued, :running, :scheduled, :retrying])

    do_check(worker, unique_attributes, statuses)
  end

  defp do_check(_worker, _unique_attributes = [], _statuses), do: :ok

  defp do_check(worker, unique_attributes, statuses) do
    with {:ok, existing_workers} <-
           Workers.list_workers(%{
             worker_module: worker.worker_module,
             queue_name: worker.queue_name
           }) do
      existing_workers
      |> Enum.find(fn existing_worker ->
        status_matches?(existing_worker.status, statuses) and
          unique_attributes_match?(existing_worker.args, worker.args, unique_attributes)
      end)
      |> case do
        %Worker{} -> {:error, :already_exists}
        _ -> :ok
      end
    end
  end

  defp status_matches?(_worker_status, :all), do: true

  defp status_matches?(worker_status, statuses) when is_list(statuses),
    do: worker_status in statuses

  defp status_matches?(worker_status, single_status) when is_atom(single_status),
    do: worker_status == single_status

  defp unique_attributes_match?(existing_worker_args, new_worker_args, unique_attrs) do
    Enum.all?(unique_attrs, fn attr ->
      existing_value = Map.get(existing_worker_args, attr)
      new_value = Map.get(new_worker_args, attr)

      # Only consider a match if both values are present and equal
      existing_value != nil and new_value != nil and existing_value == new_value
    end)
  end
end
