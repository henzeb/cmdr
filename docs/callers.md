# Callers

cmdr provides two mechanisms for invoking external commands from module code: **self re-invocation** for running cmdr itself as a child process, and **`cmdr::call`** for resolving and running external executables through a configurable candidate list.

## Re-invoking cmdr

When a module command needs to invoke cmdr as a subprocess, use these helpers instead of calling `cmdr` directly. They resolve the running cmdr binary by its real path, so the correct installation is always used regardless of where or how the user calls cmdr.

```bash
cmdr::self::execute <args>...
cmdr::self::execute_or_fail <args>...
```

Both helpers pass stdin, stdout, and stderr through unchanged, so interactive prompts work normally.

| Helper | Behaviour on failure |
|--------|----------------------|
| `cmdr::self::execute` | Returns cmdr's exit code; caller decides what to do |
| `cmdr::self::execute_or_fail` | Exits the current process with cmdr's exit code |

```bash
my_module::deploy() {
    cmdr::self::execute_or_fail build --env production
    cmdr::self::execute notify "Deploy complete"
}
```

---

## Resolving external commands

`cmdr::call` lets modules invoke external tools (e.g. `php`, `composer`, a project-local binary) without hard-coding their paths. The actual executable is resolved at runtime from a registered candidate list, so project config or user config can point cmdr at the right binary for the environment.

```bash
cmdr::call <name> [args...]
```

Resolution order for `<name>`:

1. If candidates are registered (via `cmdr::register::call`), they are tried in order — the last-registered candidates are tried first (prepend semantics).
2. If no candidates are registered, `<name>` is looked up in `PATH` as a fallback.
3. If nothing resolves, an error is printed and exit code `127` is returned.

```bash
my_module::test() {
    cmdr::call phpunit --testsuite unit
}
```

## Registering candidates

Use `cmdr::register::call` to register one or more candidates for a name. Call it from a module's `main.sh` or from a `.config` file.

```bash
cmdr::register::call <name> <candidate>...
```

**Candidate forms:**

| Form | Resolution |
|------|------------|
| Bare name (no `/`) | Looked up via `PATH` using `command -v` |
| Multi-word (contains a space) | First word looked up via `PATH`; the full command is probed with no arguments to confirm availability |
| Relative path (contains `/`) | Resolved relative to the detected project root |
| Absolute path | Checked directly with `-x` |

Each call to `cmdr::register::call` **prepends** its candidates, so later registrations (e.g. from user or project config) take priority over earlier ones (e.g. from a shipped module).

```bash
# Shipped module registers a default
cmdr::register::call phpunit vendor/bin/phpunit phpunit

# Project config overrides with a wrapper script
cmdr::register::call phpunit bin/phpunit
```

When `cmdr::call phpunit` runs, `bin/phpunit` (relative to the project root) is tried first, then `vendor/bin/phpunit`, then `phpunit` on PATH.

## Combining both

`cmdr::call` and `cmdr::self::execute` can be combined freely:

```bash
my_module::ci() {
    cmdr::call composer install --no-interaction
    cmdr::self::execute_or_fail test
    cmdr::self::execute_or_fail lint
}
```
