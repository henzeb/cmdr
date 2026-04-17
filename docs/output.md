# Output

cmdr provides output helpers for printing messages, tracking progress, and displaying task lists. All helpers use ANSI colors when writing to a real terminal.

## Output helpers

Each helper prints a styled line with a bold tag and a colored message. The tag is controlled by `CMDR_TAG` (see [Configuring output](#configuring-output)).

### `cmdr::output::info`

Prints an informational message to **stdout**.

```bash
cmdr::output::info "Containers started successfully."
```

```
   cmdr  Containers started successfully.
```

### `cmdr::output::warning`

Prints a warning to **stderr** with a yellow `⚠` icon and yellow message text.

```bash
cmdr::output::warning "No .env file found, using defaults."
```

```
 ⚠  cmdr  No .env file found, using defaults.
```

### `cmdr::output::error`

Prints an error to **stderr** in bright red. Execution continues.

```bash
cmdr::output::error "Migration failed."
```

```
 ✖  cmdr  Migration failed.
```

### `cmdr::output::fail`

Prints an error to **stderr** in bright red and exits. The exit code defaults to `1`; pass a second argument to use a different code.

```bash
cmdr::output::fail "Required dependency not found."
cmdr::output::fail "Unsupported platform." 2
```

### `cmdr::output::success`

Prints a success message to **stdout** with a bright green `✔` icon.

```bash
cmdr::output::success "Deployment complete."
```

```
 ✔  cmdr  Deployment complete.
```

---

## Progress bar

`cmdr::output::progressbar` renders a single-line, in-place progress bar on the terminal. It is a no-op when stdout is not a TTY (e.g. piped output).

### `cmdr::output::progressbar`

Initialises the bar and prints it at the current cursor position.

```bash
cmdr::output::progressbar <label> <total>
```

```bash
cmdr::output::progressbar "Building" 50
```

Output:

```
   cmdr  Building  ░░░░░░░░░░░░░░░░░░░░  0%  (0/50)
```

### `cmdr::output::progressbar::advance`

Advances the bar by `n` steps (default `1`). An optional step label is shown after the percentage; when omitted, the current/total counter is shown instead.

```bash
cmdr::output::progressbar::advance [n] [label]
```

```bash
cmdr::output::progressbar::advance          # advance 1, show counter
cmdr::output::progressbar::advance 5        # advance 5, show counter
cmdr::output::progressbar::advance 1 "Compiling auth.sh…"  # advance 1, show label
```

The step count is clamped at the total — advancing past 100% is safe.

### `cmdr::output::progressbar::clear`

Erases the bar line from the terminal and resets all internal state. Always call this when the operation is done so subsequent output starts on a clean line.

```bash
cmdr::output::progressbar::clear
```

### Example

```bash
local files=("a.sh" "b.sh" "c.sh")
cmdr::output::progressbar "Compiling" "${#files[@]}"
for f in "${files[@]}"; do
    compile "$f"
    cmdr::output::progressbar::advance 1 "$f"
done
cmdr::output::progressbar::clear
cmdr::output::success "Compilation complete."
```

---

## Task list

`cmdr::output::tasks::*` renders a grouped, multi-line, in-place task list. It is a no-op when stdout is not a TTY. State is always updated even in non-TTY contexts.

### `cmdr::output::tasks::add`

Registers a task in a named group and redraws the list. New tasks start with `pending` status. Groups are displayed in the order their first task is added; tasks within a group are displayed in insertion order.

```bash
cmdr::output::tasks::add <group> <label> <description>
```

```bash
cmdr::output::tasks::add "deploy" "Build frontend" "Compile assets"
cmdr::output::tasks::add "deploy" "Run tests"      "Integration tests"
```

### Status functions

Each function updates the task's status and redraws the list. The `<label>` must match the label passed to `::add`. Calling with an unknown label is a silent no-op.

```bash
cmdr::output::tasks::processing <group> <label>   # cyan spinner + elapsed time
cmdr::output::tasks::done       <group> <label>   # bright green ✔
cmdr::output::tasks::failed     <group> <label>   # bright red ✖
cmdr::output::tasks::canceled   <group> <label>   # yellow ⊘
```

A task marked `processing` displays a dim elapsed time counter (e.g. `5s`) next to its description. The counter updates on every redraw — including `::tick` calls and any other state change — so it advances without manual intervention.

### `cmdr::output::tasks::tick`

Advances the spinner one frame and redraws. Call this in a loop while work is in progress to animate the spinner on `processing` tasks.

```bash
cmdr::output::tasks::tick
```

```bash
cmdr::output::tasks::processing "deploy" "Build frontend"
while doing_work; do
    sleep 0.1
    cmdr::output::tasks::tick
done
cmdr::output::tasks::done "deploy" "Build frontend"
```

### `cmdr::output::tasks::clear`

Erases the entire task list block from the terminal and resets all internal state. Always call this when done so subsequent output starts on a clean line.

```bash
cmdr::output::tasks::clear
```

### Ctrl+C handling

While a task list is active, pressing Ctrl+C automatically marks the `processing` task as `failed` and all `pending` tasks as `canceled`, redraws the final state, then exits. The previous INT trap (if any) is restored before exit so normal signal handling resumes.

### Hooks

Two hooks fire per group when tasks are canceled — either via `cmdr::output::tasks::canceled` or Ctrl+C.

| Hook | When |
|------|------|
| `cmdr.task.<group>.cancel` | Before tasks are marked |
| `cmdr.task.<group>.canceled` | After tasks are marked and redrawn |

Both hooks receive the group name as `$1` and the label of the task that was `processing` at the time as `$2` (empty string if no task was in progress).

```bash
# hooks.sh
cmdr::register::hook cmdr.task.deploy.cancel    mymodule::on_deploy_cancel
cmdr::register::hook cmdr.task.deploy.canceled  mymodule::on_deploy_canceled
```

```bash
mymodule::on_deploy_canceled() {
    local group="$1" active_task="$2"
    cmdr::output::warning "Canceled during: ${active_task:-none}"
}
```

### Status reference

| Status       | Symbol | Color        |
|--------------|--------|--------------|
| `pending`    | `○`    | dim          |
| `processing` | `⠸`    | cyan         |
| `done`       | `✔`    | bright green |
| `failed`     | `✖`    | bright red   |
| `canceled`   | `⊘`    | yellow       |

### Example

```bash
cmdr::output::tasks::add "build" "Compile"  "Transpile TypeScript"
cmdr::output::tasks::add "build" "Lint"     "ESLint check"
cmdr::output::tasks::add "build" "Bundle"   "Webpack production build"

for step in "Compile" "Lint" "Bundle"; do
    cmdr::output::tasks::processing "build" "$step"
    run_step "$step"
    if (( $? == 0 )); then
        cmdr::output::tasks::done   "build" "$step"
    else
        cmdr::output::tasks::failed "build" "$step"
        cmdr::output::tasks::clear
        cmdr::output::fail "Build failed at: $step"
    fi
done

cmdr::output::tasks::clear
cmdr::output::success "Build complete."
```

---

## Configuring output

### `CMDR_TAG`

The tag printed before every message. Default: `CMDR`.

```bash
CMDR_TAG=ACME
```

Output:

```
   acme  Containers started successfully.
```

Set it in `.cmdr/.config` or `~/.cmdr/.config` (see [Configuration](configuration.md)).

---

## Common utilities

### `cmdr::common::elapsed`

Formats a duration in whole seconds into a human-readable string and prints it to **stdout**.

```bash
cmdr::common::elapsed <seconds>
```

| Input | Output |
|-------|--------|
| `0` | `0.1s` |
| `45` | `45s` |
| `90` | `1m 30s` |
| `3661` | `1h 1m` |

```bash
local start=$SECONDS
do_work
cmdr::output::info "Done in $(cmdr::common::elapsed $(( SECONDS - start )))"
```
