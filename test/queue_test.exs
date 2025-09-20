defmodule Ant.QueueTest do
  alias Ant.Queue

  use ExUnit.Case
  use Mimic

  defmodule TestWorker do
    use Ant.Worker

    def perform(_worker), do: :ok

    def calculate_delay(_worker), do: 0
  end

  setup do
    Mimic.copy(Ant.Workers)
    Mimic.copy(Ant.Worker)
    Mimic.copy(DynamicSupervisor)

    :ok
  end

  setup :set_mimic_global
  setup :verify_on_exit!

  test "runs pending workers on start" do
    running_worker = build_worker(:running)
    retrying_worker = build_worker(:retrying)

    expect(
      Ant.Workers,
      :list_workers,
      fn %{status: :running, queue_name: "default"} -> {:ok, [running_worker]} end
    )

    expect(
      Ant.Workers,
      :list_retrying_workers,
      fn %{queue_name: "default"}, _date_time -> {:ok, [retrying_worker]} end
    )

    expect(Ant.Workers, :update_worker, 2, fn worker_id, %{status: :running} ->
      worker = if worker_id == running_worker.id, do: running_worker, else: retrying_worker

      {:ok, %{worker | status: :running}}
    end)

    expect(DynamicSupervisor, :start_child, 2, fn Ant.WorkersSupervisor, child_spec ->
      assert {
               Ant.Worker,
               :start_link,
               [%Ant.Worker{id: worker_id, status: :running}]
             } = child_spec.start

      {:ok, :"#{worker_id}_pid"}
    end)

    test_pid = self()

    expect(Ant.Worker, :perform, 2, fn pid ->
      send(test_pid, {:worker_performed, pid})

      :ok
    end)

    {:ok, _pid} = Queue.start_link(queue: "default", config: [check_interval: 10])

    running_worker_pid = :"#{running_worker.id}_pid"
    retrying_worker_pid = :"#{retrying_worker.id}_pid"
    assert_receive({:worker_performed, ^running_worker_pid})
    assert_receive({:worker_performed, ^retrying_worker_pid})
  end

  describe "periodically checks workers" do
    test "processes only stuck workers when their count exceeds concurrency limit" do
      test_pid = self()

      expect(
        Ant.Workers,
        :list_workers,
        fn %{queue_name: "default", status: :running} ->
          {
            :ok,
            [build_worker(1, :running), build_worker(2, :running), build_worker(3, :running)]
          }
        end
      )

      expect(
        Ant.Workers,
        :list_retrying_workers,
        fn %{queue_name: "default"}, _date_time ->
          {
            :ok,
            [build_worker(4, :retrying), build_worker(5, :retrying), build_worker(6, :retrying)]
          }
        end
      )

      interval_in_ms = 5

      expect(Ant.Workers, :update_worker, 4, fn worker_id, %{status: :running} ->
        {:ok, build_worker(worker_id, :running)}
      end)

      {:ok, _pid} =
        Queue.start_link(
          queue: "default",
          config: [check_interval: interval_in_ms, concurrency: 2]
        )

      expect(DynamicSupervisor, :start_child, 4, fn Ant.WorkersSupervisor, child_spec ->
        assert {
                 Ant.Worker,
                 :start_link,
                 [%Ant.Worker{status: :running, id: id}]
               } = child_spec.start

        {:ok, :"pid_for_periodic_check_#{id}"}
      end)

      expect(Ant.Worker, :perform, 4, fn worker_pid ->
        send(test_pid, {:"#{worker_pid}_performed", :periodic_check})

        :ok
      end)

      reject(Ant.Workers, :list_workers, 1)

      assert_receive({:pid_for_periodic_check_1_performed, :periodic_check})
      assert_receive({:pid_for_periodic_check_2_performed, :periodic_check})

      # On the next recurring check

      Process.sleep(interval_in_ms * 2)

      assert_receive({:pid_for_periodic_check_3_performed, :periodic_check})
      assert_receive({:pid_for_periodic_check_4_performed, :periodic_check})
    end

    test "runs enqueued and scheduled workers if there is no stuck workers" do
      test_pid = self()

      scheduled_worker = build_worker(1, :scheduled)
      enqueued_worker = build_worker(2, :enqueued)

      expect(
        Ant.Workers,
        :list_scheduled_workers,
        fn %{queue_name: "default"}, _date_time, _opts ->
          {:ok, [scheduled_worker]}
        end
      )

      expect(
        Ant.Workers,
        :list_retrying_workers,
        fn %{queue_name: "default"}, _date_time, _opts ->
          {:ok, []}
        end
      )

      expect(
        Ant.Workers,
        :list_workers,
        fn %{queue_name: "default", status: :enqueued}, _opts ->
          {:ok, [enqueued_worker]}
        end
      )

      interval_in_ms = 5

      expect(Ant.Workers, :update_worker, 2, fn worker_id, %{status: :running} ->
        worker = if worker_id == scheduled_worker.id, do: scheduled_worker, else: enqueued_worker

        {:ok, %{worker | status: :running}}
      end)

      {:ok, _pid} = Queue.start_link(queue: "default", config: [check_interval: interval_in_ms])

      expect(DynamicSupervisor, :start_child, 2, fn Ant.WorkersSupervisor, child_spec ->
        assert {Ant.Worker, :start_link, [%Ant.Worker{id: worker_id, status: :running}]} =
                 child_spec.start

        {:ok, :"pid_for_periodic_check_#{worker_id}"}
      end)

      expect(Ant.Worker, :perform, 2, fn pid ->
        periodic_check_enqueued_worker_pid = :"pid_for_periodic_check_#{enqueued_worker.id}"
        periodic_check_scheduled_worker_pid = :"pid_for_periodic_check_#{scheduled_worker.id}"

        status =
          case pid do
            ^periodic_check_enqueued_worker_pid -> :enqueued
            ^periodic_check_scheduled_worker_pid -> :scheduled
          end

        send(test_pid, {:"#{status}_worker_performed", :periodic_check})

        :ok
      end)

      # testing periodic check

      Process.sleep(interval_in_ms * 2)

      assert_receive({:enqueued_worker_performed, :periodic_check})
      assert_receive({:scheduled_worker_performed, :periodic_check})
    end
  end

  test "can update concurrency on the fly" do
    {:ok, less} =
      Queue.start_link(queue: "less", config: [check_interval: 100, concurrency: 1])

    {:ok, more} = Queue.start_link(queue: "more", config: [check_interval: 100, concurrency: 2])

    assert :sys.get_state(less).concurrency == 1
    assert :sys.get_state(more).concurrency == 2

    :ok = Queue.set_concurrency("more", 5)

    assert :sys.get_state(less).concurrency == 1
    assert :sys.get_state(more).concurrency == 5
  end

  defp build_worker(id, status) do
    status
    |> build_worker()
    |> Map.put(:id, id)
  end

  defp build_worker(status) do
    %{initial_status: status}
    |> TestWorker.build()
    |> Map.merge(%{id: :erlang.unique_integer([:positive]), status: status})
  end
end
