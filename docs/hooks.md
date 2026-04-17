# Hooks

Use hooks to let modules subscribe to named events. Register one or more listener functions for a hook name; fire the hook by calling `cmdr::hook::run`. Listeners receive whatever arguments you pass and are called in registration order.

## Registering a listener

Call `cmdr::register::hook` from a module's `main.sh`:

```bash
# In deploy/main.sh
cmdr::register::hook deploy.before deploy::on_before_deploy
cmdr::register::hook deploy.after  deploy::on_after_deploy
```

Multiple modules can register listeners for the same hook — all of them fire.

## Implementing listeners — `hooks.sh`

Put listener implementations in a `hooks.sh` file alongside `main.sh`. It is sourced lazily the first time any hook fires, so it can safely call into your module's full implementation:

```
deploy/
  main.sh     ← registers hook listeners
  deploy.sh   ← command implementations
  hooks.sh    ← listener implementations, sourced on first hook run
```

```bash
# deploy/hooks.sh

deploy::on_before_deploy() {
    local env="$1"
    cmdr::output::info "Preparing deploy to ${env}…"
}

deploy::on_after_deploy() {
    local env="$1"
    cmdr::output::info "Deploy to ${env} complete."
}
```

`hooks.sh` is not required. If the listener function is already defined when the hook fires (e.g. defined inline or loaded by another means), no `hooks.sh` is needed.

## Firing a hook

Call `cmdr::hook::run` from anywhere — a command implementation, another hook, or a config file:

```bash
cmdr::hook::run deploy.before "$env"
# … perform the deploy …
cmdr::hook::run deploy.after  "$env"
```

`cmdr::hook::run` does three things before calling listeners:

1. **Sources all `hooks.sh` files** from the three search paths (see below) — once per session.
2. **Inits the registering module** for each listener, so the full module implementation (`deploy.sh`) is available.
3. **Calls each listener** in registration order, forwarding any extra arguments.

If no listeners are registered for a hook name, the call is a no-op and returns `0`.

---

## Discovering hook files

`hooks.sh` files are discovered from the same three search paths as modules, in the same order:

| Priority | Location | Scope |
|---|---|---|
| 1 (lowest) | `src/modules/` | Shipped |
| 2 | `~/.cmdr/` | Global |
| 3 (highest) | `.cmdr/` at project root | Project-local |

Within each search path, `hooks.sh` is discovered at the root and inside any module or submodule directory:

```
src/modules/deploy/hooks.sh          ← shipped listeners
~/.cmdr/deploy/hooks.sh              ← user-global additions
.cmdr/deploy/hooks.sh                ← project-local additions
```

All discovered files are sourced. A project-local `hooks.sh` extends — rather than replaces — the listeners registered by shipped or global files.

## Naming hooks

Hook names are free-form strings. A `<module>.<event>` convention keeps them readable and avoids collisions:

```bash
cmdr::register::hook git.pre_commit   mymod::check_staged_files
cmdr::register::hook deploy.before    mymod::run_tests
cmdr::register::hook deploy.after     mymod::notify_team
cmdr::register::hook config.loaded    mymod::apply_defaults
```

## Handling return values

`cmdr::hook::run` calls all listeners regardless of individual return codes. A listener returning non-zero does not stop subsequent listeners from running. If you need to abort on failure, check the return value yourself and return early from the calling code.

---

## Bootstrap hooks

cmdr fires two built-in hooks around the bootstrap phase, before any command is dispatched.

| Hook | When it fires |
|---|---|
| `cmdr.bootstrapping` | Start of `cmdr::bootstrap` — before prescan, config loading, and module loading |
| `cmdr.bootstrapped` | End of `cmdr::bootstrap` — after config and modules are loaded and global flags are parsed |

Neither hook receives arguments.

### Registering bootstrap listeners

`cmdr.bootstrapping` fires before any `main.sh` has been sourced, so you cannot register a listener for it there — it would be too late. Register it in `hooks.sh` instead. `cmdr::hook::run` sources all `hooks.sh` files before calling any listeners, so a registration in `hooks.sh` is picked up even for the earliest hook.

`cmdr.bootstrapped` fires after all modules are loaded, so you can register its listeners in either `main.sh` or `hooks.sh`.

```bash
# .cmdr/deploy/hooks.sh

cmdr::register::hook cmdr.bootstrapping deploy::on_bootstrapping
cmdr::register::hook cmdr.bootstrapped  deploy::on_bootstrapped

deploy::on_bootstrapping() {
    # Modules haven't been sourced yet — only core framework functions are available
    cmdr::output::info "cmdr is starting…"
}

deploy::on_bootstrapped() {
    # All modules, config, and global flags are available here
    : "${DEPLOY_ENV:?deploy: DEPLOY_ENV must be set in .config}"
}
```
