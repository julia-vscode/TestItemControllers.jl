"""
    ControllerCallbacks

Holds all callback functions for the test item controller. Passed at construction time,
shared across all test runs.

Required callbacks (must be provided):
- Test item lifecycle: started, passed, failed, errored, skipped
- Output: append_output
- Debug: attach_debugger

Optional callbacks (default to `nothing`):
- Process lifecycle: created, terminated, status_changed, output
"""
struct ControllerCallbacks
    on_testitem_started::Function        # (testrun_id, testitem_id) -> nothing
    on_testitem_passed::Function         # (testrun_id, testitem_id, duration) -> nothing
    on_testitem_failed::Function         # (testrun_id, testitem_id, messages, duration) -> nothing
    on_testitem_errored::Function        # (testrun_id, testitem_id, messages, duration) -> nothing
    on_testitem_skipped::Function        # (testrun_id, testitem_id) -> nothing
    on_append_output::Function           # (testrun_id, testitem_id, output) -> nothing
    on_attach_debugger::Function         # (testrun_id, debug_pipe_name) -> nothing
    on_process_created::Union{Nothing,Function}         # (id, package_name, package_uri, project_uri, coverage, env) -> nothing
    on_process_terminated::Union{Nothing,Function}       # (id) -> nothing
    on_process_status_changed::Union{Nothing,Function}   # (id, status) -> nothing
    on_process_output::Union{Nothing,Function}           # (id, output) -> nothing
end

function ControllerCallbacks(;
    on_testitem_started,
    on_testitem_passed,
    on_testitem_failed,
    on_testitem_errored,
    on_testitem_skipped,
    on_append_output,
    on_attach_debugger,
    on_process_created=nothing,
    on_process_terminated=nothing,
    on_process_status_changed=nothing,
    on_process_output=nothing,
)
    return ControllerCallbacks(
        on_testitem_started,
        on_testitem_passed,
        on_testitem_failed,
        on_testitem_errored,
        on_testitem_skipped,
        on_append_output,
        on_attach_debugger,
        on_process_created,
        on_process_terminated,
        on_process_status_changed,
        on_process_output,
    )
end
