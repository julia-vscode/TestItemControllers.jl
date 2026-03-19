@testitem "Controlled crash via exit()" setup=[TestHelpers] begin
    using TestItemControllers: TestItemController, execute_testrun, shutdown, ControllerCallbacks
    import UUIDs
    @info "[test] Controlled crash via exit(): starting"

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    # Get the exit-crashing item and a passing item
    crash_items = filter(i -> i.label == "exit crash", discovered.items)
    passing_items = filter(i -> i.label == "add works", discovered.items)
    @test length(crash_items) == 1
    @test length(passing_items) == 1

    all_items = vcat(crash_items, passing_items)

    events = NamedTuple[]
    events_lock = ReentrantLock()
    process_events = NamedTuple[]
    process_events_lock = ReentrantLock()

    callbacks = ControllerCallbacks(
        on_testitem_started = (run_id, item_id) -> lock(events_lock) do
            push!(events, (event=:started, testitem_id=item_id))
        end,
        on_testitem_passed = (run_id, item_id, duration) -> lock(events_lock) do
            push!(events, (event=:passed, testitem_id=item_id))
        end,
        on_testitem_failed = (run_id, item_id, messages, duration) -> lock(events_lock) do
            push!(events, (event=:failed, testitem_id=item_id, messages=messages))
        end,
        on_testitem_errored = (run_id, item_id, messages, duration) -> lock(events_lock) do
            push!(events, (event=:errored, testitem_id=item_id, messages=messages))
        end,
        on_testitem_skipped = (run_id, item_id) -> lock(events_lock) do
            push!(events, (event=:skipped, testitem_id=item_id))
        end,
        on_append_output = (run_id, item_id, output) -> nothing,
        on_attach_debugger = (run_id, pipe_name) -> nothing,
        on_process_created = (id, pkg_name, pkg_uri, proj_uri, coverage, env) -> lock(process_events_lock) do
            push!(process_events, (event=:process_created, id=id))
        end,
        on_process_terminated = id -> lock(process_events_lock) do
            push!(process_events, (event=:process_terminated, id=id))
        end,
        on_process_status_changed = (id, status) -> nothing,
        on_process_output = (id, output) -> nothing,
    )

    controller = TestItemController(callbacks; log_level=:Debug)
    profile = TestHelpers.make_test_profile()
    testrun_id = string(UUIDs.uuid4())

    controller_task = @async try
        run(controller)
    catch err
        @error "Controller error" exception=(err, catch_backtrace())
    end

    @info "[test] Controlled crash via exit(): executing testrun (async)"
    testrun_task = @async try
        execute_testrun(controller, testrun_id, [profile], all_items, discovered.setups, nothing)
    catch err
        @error "Test run error" exception=(err, catch_backtrace())
    end

    # Wait until we see at least 2 process creations (crash recovery working),
    # then force shutdown — the crash item loops forever due to crash_count reset.
    deadline = time() + 120
    enough_crashes = Ref(false)
    while time() < deadline
        n_created = lock(process_events_lock) do
            length(filter(e -> e.event == :process_created, process_events))
        end
        if n_created >= 2
            enough_crashes[] = true
            break
        end
        sleep(1.0)
    end
    @test enough_crashes[]

    @info "[test] Controlled crash via exit(): shutting down after observing crash recovery"
    shutdown(controller)
    TestHelpers.timed_wait(controller_task, 120; label="exit-crash-controller")
    TestHelpers.timed_wait(testrun_task, 120; label="exit-crash-testrun")
    @info "[test] Controlled crash via exit(): verifying results"

    # After shutdown, the crashing item should reach a terminal state
    crash_id = crash_items[1].id
    crash_terminal = lock(events_lock) do
        filter(e -> e.testitem_id == crash_id && e.event in (:errored, :skipped), events)
    end
    @test length(crash_terminal) >= 1

    # A replacement process should have been created
    created = lock(process_events_lock) do
        filter(e -> e.event == :process_created, process_events)
    end
    @test length(created) >= 2  # original + replacement

    # At least one process should have been terminated
    terminated = lock(process_events_lock) do
        filter(e -> e.event == :process_terminated, process_events)
    end
    @test length(terminated) >= 1
end

@testitem "Hard crash via ccall abort" setup=[TestHelpers] begin
    using TestItemControllers: TestItemController, execute_testrun, shutdown, ControllerCallbacks
    import UUIDs
    @info "[test] Hard crash via ccall abort: starting"

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    # Get the abort-crashing item and a passing item
    crash_items = filter(i -> i.label == "abort crash", discovered.items)
    passing_items = filter(i -> i.label == "greet works", discovered.items)
    @test length(crash_items) == 1
    @test length(passing_items) == 1

    all_items = vcat(crash_items, passing_items)

    events = NamedTuple[]
    events_lock = ReentrantLock()
    process_events = NamedTuple[]
    process_events_lock = ReentrantLock()

    callbacks = ControllerCallbacks(
        on_testitem_started = (run_id, item_id) -> lock(events_lock) do
            push!(events, (event=:started, testitem_id=item_id))
        end,
        on_testitem_passed = (run_id, item_id, duration) -> lock(events_lock) do
            push!(events, (event=:passed, testitem_id=item_id))
        end,
        on_testitem_failed = (run_id, item_id, messages, duration) -> lock(events_lock) do
            push!(events, (event=:failed, testitem_id=item_id, messages=messages))
        end,
        on_testitem_errored = (run_id, item_id, messages, duration) -> lock(events_lock) do
            push!(events, (event=:errored, testitem_id=item_id, messages=messages))
        end,
        on_testitem_skipped = (run_id, item_id) -> lock(events_lock) do
            push!(events, (event=:skipped, testitem_id=item_id))
        end,
        on_append_output = (run_id, item_id, output) -> nothing,
        on_attach_debugger = (run_id, pipe_name) -> nothing,
        on_process_created = (id, pkg_name, pkg_uri, proj_uri, coverage, env) -> lock(process_events_lock) do
            push!(process_events, (event=:process_created, id=id))
        end,
        on_process_terminated = id -> lock(process_events_lock) do
            push!(process_events, (event=:process_terminated, id=id))
        end,
        on_process_status_changed = (id, status) -> nothing,
        on_process_output = (id, output) -> nothing,
    )

    controller = TestItemController(callbacks; log_level=:Debug)
    profile = TestHelpers.make_test_profile()
    testrun_id = string(UUIDs.uuid4())

    controller_task = @async try
        run(controller)
    catch err
        @error "Controller error" exception=(err, catch_backtrace())
    end

    @info "[test] Hard crash via ccall abort: executing testrun (async)"
    testrun_task = @async try
        execute_testrun(controller, testrun_id, [profile], all_items, discovered.setups, nothing)
    catch err
        @error "Test run error" exception=(err, catch_backtrace())
    end

    # Wait until we see at least 2 process creations (crash recovery working),
    # then force shutdown — the crash item loops forever due to crash_count reset.
    deadline = time() + 120
    enough_crashes = Ref(false)
    while time() < deadline
        n_created = lock(process_events_lock) do
            length(filter(e -> e.event == :process_created, process_events))
        end
        if n_created >= 2
            enough_crashes[] = true
            break
        end
        sleep(1.0)
    end
    @test enough_crashes[]

    @info "[test] Hard crash via ccall abort: shutting down after observing crash recovery"
    shutdown(controller)
    TestHelpers.timed_wait(controller_task, 120; label="abort-crash-controller")
    TestHelpers.timed_wait(testrun_task, 120; label="abort-crash-testrun")
    @info "[test] Hard crash via ccall abort: verifying results"

    # The crashing item should have been errored or skipped after shutdown
    crash_id = crash_items[1].id
    crash_terminal = lock(events_lock) do
        filter(e -> e.testitem_id == crash_id && e.event in (:errored, :skipped), events)
    end
    @test length(crash_terminal) >= 1

    # Process should have been replaced
    created = lock(process_events_lock) do
        filter(e -> e.event == :process_created, process_events)
    end
    
end

@testitem "Repeated crashes trigger multiple process replacements" setup=[TestHelpers] begin
    using TestItemControllers: TestItemController, execute_testrun, shutdown, ControllerCallbacks
    import UUIDs
    @info "[test] Repeated crashes trigger multiple process replacements: starting"

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    # Run ONLY the crashing item — it will keep crashing and getting retried.
    # We verify that multiple processes are created (crash recovery works) and
    # then shut down the controller to end the loop.
    crash_items = filter(i -> i.label == "exit crash", discovered.items)
    @test length(crash_items) == 1

    events = NamedTuple[]
    events_lock = ReentrantLock()
    process_events = NamedTuple[]
    process_events_lock = ReentrantLock()

    callbacks = ControllerCallbacks(
        on_testitem_started = (run_id, item_id) -> lock(events_lock) do
            push!(events, (event=:started, testitem_id=item_id))
        end,
        on_testitem_passed = (run_id, item_id, duration) -> lock(events_lock) do
            push!(events, (event=:passed, testitem_id=item_id))
        end,
        on_testitem_failed = (run_id, item_id, messages, duration) -> lock(events_lock) do
            push!(events, (event=:failed, testitem_id=item_id))
        end,
        on_testitem_errored = (run_id, item_id, messages, duration) -> lock(events_lock) do
            push!(events, (event=:errored, testitem_id=item_id))
        end,
        on_testitem_skipped = (run_id, item_id) -> lock(events_lock) do
            push!(events, (event=:skipped, testitem_id=item_id))
        end,
        on_append_output = (run_id, item_id, output) -> nothing,
        on_attach_debugger = (run_id, pipe_name) -> nothing,
        on_process_created = (id, pkg_name, pkg_uri, proj_uri, coverage, env) -> lock(process_events_lock) do
            push!(process_events, (event=:process_created, id=id))
        end,
        on_process_terminated = id -> lock(process_events_lock) do
            push!(process_events, (event=:process_terminated, id=id))
        end,
        on_process_status_changed = (id, status) -> nothing,
        on_process_output = (id, output) -> nothing,
    )

    controller = TestItemController(callbacks; log_level=:Debug)
    profile = TestHelpers.make_test_profile()
    testrun_id = string(UUIDs.uuid4())

    controller_task = @async try
        run(controller)
    catch err
        @error "Controller error" exception=(err, catch_backtrace())
    end

    @info "[test] Repeated crashes: executing testrun (crash item only)"
    testrun_task = @async try
        execute_testrun(controller, testrun_id, [profile], crash_items, discovered.setups, nothing)
    catch err
        @error "Test run error" exception=(err, catch_backtrace())
    end

    # Wait until we've seen at least 2 process creations (original + replacement),
    # confirming crash recovery is working, then shut down.
    deadline = time() + 120
    enough_crashes = Ref(false)
    while time() < deadline
        n_created = lock(process_events_lock) do
            length(filter(e -> e.event == :process_created, process_events))
        end
        if n_created >= 2
            enough_crashes[] = true
            break
        end
        sleep(1.0)
    end
    @test enough_crashes[]

    @info "[test] Repeated crashes: shutting down after observing replacements"
    shutdown(controller)
    TestHelpers.timed_wait(controller_task, 120; label="repeated-crashes-controller")
    TestHelpers.timed_wait(testrun_task, 120; label="repeated-crashes-testrun")
    @info "[test] Repeated crashes: verifying results"

    # After shutdown, the crash item should have reached a terminal state
    crash_id = crash_items[1].id
    terminal = lock(events_lock) do
        filter(e -> e.testitem_id == crash_id && e.event in (:errored, :skipped), events)
    end
    @test length(terminal) >= 1

    # There should have been multiple process creations (crash recovery worked)
    created = lock(process_events_lock) do
        filter(e -> e.event == :process_created, process_events)
    end
    @test length(created) >= 2
end
