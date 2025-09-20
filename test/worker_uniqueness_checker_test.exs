defmodule Ant.WorkerUniquenessCheckerTest do
  use ExUnit.Case
  use MnesiaTesting

  alias Ant.WorkerUniquenessChecker

  defmodule TestWorker do
    use Ant.Worker, unique: [args: [:email]]

    def perform(_worker), do: :ok
  end

  test "returns :ok when unique_config is empty" do
    # Create worker with empty unique config
    worker = %{TestWorker.build(%{email: "test@example.com"}) | opts: [unique: []]}

    assert WorkerUniquenessChecker.call(worker) == :ok
  end

  test "returns :ok when no unique args specified" do
    worker = %{TestWorker.build(%{email: "test@example.com"}) | opts: [unique: [statuses: :all]]}

    assert WorkerUniquenessChecker.call(worker) == :ok
  end

  test "returns :ok when no duplicates exist" do
    worker = TestWorker.build(%{email: "test@example.com"})

    assert WorkerUniquenessChecker.call(worker) == :ok
  end

  test "returns {:error, :already_exists} when duplicate exists" do
    {:ok, _existing_worker} =
      %{email: "test@example.com"}
      |> TestWorker.build()
      |> Ant.Workers.create_worker()

    new_worker = TestWorker.build(%{email: "test@example.com"})

    assert WorkerUniquenessChecker.call(new_worker) == {:error, :already_exists}
  end

  for status <- [:enqueued, :running, :scheduled, :retrying] do
    test "returns error when worker with #{status} is present and statuses configuration is missing" do
      {:ok, existing_worker} =
        %{email: "test@example.com"}
        |> TestWorker.build()
        |> Ant.Workers.create_worker()

      {:ok, _} = Ant.Workers.update_worker(existing_worker.id, %{status: unquote(status)})

      new_worker = TestWorker.build(%{email: "test@example.com"})

      assert WorkerUniquenessChecker.call(new_worker) == {:error, :already_exists}
    end
  end

  test "respects status configuration" do
    {:ok, existing_worker} =
      %{email: "test@example.com"}
      |> TestWorker.build()
      |> Ant.Workers.create_worker()

    {:ok, _} = Ant.Workers.update_worker(existing_worker.id, %{status: :completed})

    # Should allow duplicate with default statuses (doesn't check completed)
    new_worker = TestWorker.build(%{email: "test@example.com"})

    assert WorkerUniquenessChecker.call(new_worker) == :ok

    # Should prevent duplicate with :all statuses (checks completed)
    new_worker_all_statuses = %{
      TestWorker.build(%{email: "test@example.com"})
      | opts: [unique: [args: [:email], statuses: :all]]
    }

    assert WorkerUniquenessChecker.call(new_worker_all_statuses) ==
             {:error, :already_exists}
  end

  test "handles missing unique attributes" do
    {:ok, _existing_worker} =
      %{email: "test@example.com"}
      |> TestWorker.build()
      |> Ant.Workers.create_worker()

    new_worker = TestWorker.build(%{other_field: "value"})

    # Should allow since email attribute is missing
    assert WorkerUniquenessChecker.call(new_worker) == :ok
  end
end
