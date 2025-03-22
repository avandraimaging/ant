defmodule Ant.WorkersTest do
  use Ant.TestCase
  use MnesiaTesting
  alias Ant.Workers

  defmodule TestWorker do
    use Ant.Worker

    def perform(_worker), do: :ok
  end

  describe "list_workers/2" do
    test "returns all workers when no limit is specified" do
      workers = create_test_workers(5)

      assert {:ok, result} = Workers.list_workers(%{})
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)
    end

    test "returns limited number of workers when limit is specified" do
      create_test_workers(5)

      assert {:ok, result} = Workers.list_workers(%{}, limit: 3)
      assert length(result) == 3
    end

    test "returns filtered and limited workers" do
      create_test_workers(5, status: :failed)
      create_test_workers(3, status: :completed)

      assert {:ok, result} = Workers.list_workers(%{status: :failed}, limit: 2)
      assert length(result) == 2
      assert Enum.all?(result, &(&1.status == :failed))
    end

    test "handles invalid limit values gracefully" do
      workers = create_test_workers(5)

      assert {:ok, result} = Workers.list_workers(%{}, limit: -1)
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)

      assert {:ok, result} = Workers.list_workers(%{}, limit: 0)
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)

      assert {:ok, result} = Workers.list_workers(%{}, limit: "invalid")
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)
    end
  end

  describe "list_workers/1" do
    test "returns all workers when no limit is specified" do
      workers = create_test_workers(5)

      assert {:ok, result} = Workers.list_workers()
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)
    end

    test "returns limited number of workers when limit is specified" do
      create_test_workers(5)

      assert {:ok, result} = Workers.list_workers(limit: 3)
      assert length(result) == 3
    end

    test "handles invalid limit values gracefully" do
      workers = create_test_workers(5)

      assert {:ok, result} = Workers.list_workers(limit: -1)
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)

      assert {:ok, result} = Workers.list_workers(limit: 0)
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)

      assert {:ok, result} = Workers.list_workers(limit: "invalid")
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)
    end
  end

  describe "list_retrying_workers/3" do
    test "returns all retrying workers when no limit is specified" do
      workers = create_test_workers(5, status: :retrying)

      assert {:ok, result} = Workers.list_retrying_workers(%{})
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)
    end

    test "returns limited number of retrying workers when limit is specified" do
      create_test_workers(5, status: :retrying)

      assert {:ok, result} = Workers.list_retrying_workers(%{}, DateTime.utc_now(), limit: 3)
      assert length(result) == 3
    end

    test "handles invalid limit values gracefully" do
      workers = create_test_workers(5, status: :retrying)

      assert {:ok, result} = Workers.list_retrying_workers(%{}, DateTime.utc_now(), limit: -1)
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)

      assert {:ok, result} = Workers.list_retrying_workers(%{}, DateTime.utc_now(), limit: 0)
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)

      assert {:ok, result} =
               Workers.list_retrying_workers(%{}, DateTime.utc_now(), limit: "invalid")

      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)
    end
  end

  describe "list_scheduled_workers/3" do
    test "returns all scheduled workers when no limit is specified" do
      workers = create_test_workers(5, status: :scheduled)

      assert {:ok, result} = Workers.list_scheduled_workers(%{})
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)
    end

    test "returns limited number of scheduled workers when limit is specified" do
      create_test_workers(5, status: :scheduled)

      assert {:ok, result} = Workers.list_scheduled_workers(%{}, DateTime.utc_now(), limit: 3)
      assert length(result) == 3
    end

    test "handles invalid limit values gracefully" do
      workers = create_test_workers(5, status: :scheduled)

      assert {:ok, result} = Workers.list_scheduled_workers(%{}, DateTime.utc_now(), limit: -1)
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)

      assert {:ok, result} = Workers.list_scheduled_workers(%{}, DateTime.utc_now(), limit: 0)
      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)

      assert {:ok, result} =
               Workers.list_scheduled_workers(%{}, DateTime.utc_now(), limit: "invalid")

      assert length(result) == 5
      assert_lists_contain_same(result, workers, equals_by: :id)
    end
  end

  defp create_test_workers(count, opts \\ []) do
    status = Keyword.get(opts, :status, :enqueued)

    Enum.map(1..count, fn i ->
      {:ok, worker} =
        %{id: i}
        |> TestWorker.build()
        |> Workers.create_worker()

      {:ok, worker} = Workers.update_worker(worker.id, %{status: status})
      worker
    end)
  end
end
