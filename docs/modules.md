# Modules

Modules are the building blocks of cmdr. Group related commands under a common name — the module is loaded lazily and only when one of its commands is actually invoked.

## Choosing a layout

Structure your module in one of two ways inside any of the [search path directories](#search-paths).

### Nested layout (preferred)

A directory with a `main.sh` for registration and a `<name>.sh` for implementation:

```
greet/
  main.sh    ← registration, sourced at startup
  greet.sh   ← command implementations, sourced on first use
```

`main.sh` must stay lightweight — it runs on every cmdr invocation. It should only contain `cmdr::register::*` calls and argument definitions. No heavy logic, no external commands.

### Flat layout

A single `<name>.sh` directly in a search path directory. Suitable for simple overrides or small additions:

```
.cmdr/
  greet.sh    ← registration + implementation in one file
```

---

## Search paths

Modules are discovered from these locations, sourced in this order:

| Priority | Location | Scope |
|---|---|---|
| 1 (lowest) | `src/modules/` inside the cmdr package | Shipped modules |
| 2 | `vendor/` packages declaring `extra.cmdr` | Composer-distributed modules |
| 3 | `~/.cmdr/` | Global additions |
| 4 (highest) | `.cmdr/` at the project root | Project-local additions |

Each layer extends what came before. A later layer can add new commands to an existing module or override individual commands by redefining their function. Use `cmdr::register::lock` in a `main.sh` to prevent any later layer from overriding that module.

---

## Creating a module

### 1. Registration — `main.sh`

```bash
# Short alias: "cmdr g ..." instead of "cmdr greet ..."
cmdr::register::alias greet g

# Help text shown in "cmdr help" and "cmdr greet help"
cmdr::register::help greet hello   "Print a greeting"
cmdr::register::help greet goodbye "Print a farewell"

# Argument and option definitions (see docs/args.md)
cmdr::args::define greet::hello \
    "{name=World : Name to greet}" \
    "{--shout|-s : Print in uppercase}"
```

`greet.sh` alongside `main.sh` is detected and registered for lazy loading automatically. No `cmdr::register::module` call is needed for the standard layout.

### 2. Implementation — `greet.sh`

```bash
greet::hello() {
    local name; name=$(cmdr::args::get name)
    local shout; shout=$(cmdr::args::get_option shout)

    local msg="Hello, ${name}!"
    [[ -n "$shout" ]] && msg="${msg^^}"
    cmdr::output::info "$msg"
}

greet::goodbye() {
    cmdr::output::info "Goodbye!"
}
```

Commands are plain Bash functions following the pattern `<module>::<subcommand>`.

---

## Adding submodules

Add a subdirectory containing a `main.sh` and the loader sources it automatically, registering it as `<parent>::<subdir>`. No registration call is needed in the parent.

```
greet/
  main.sh
  greet.sh
  formal/
    main.sh    ← auto-detected and sourced as "greet::formal"
    formal.sh  ← auto-registered for lazy loading
```

Use `cmdr::register::module` explicitly only when the submodule lives at a non-default path:

```bash
# In greet/main.sh — only needed for non-default paths:
cmdr::register::module greet::formal ./some-other-dir
```

Submodule commands follow the same naming pattern: `greet::formal::hello`.

---

## Declaring dependencies with `cmdr::use`

Module implementations are sourced on first use. If your module depends on another being initialised first, declare it explicitly at the top of the implementation file:

```bash
cmdr::use greet
```

This is also how you access core components that are registered lazily, such as `cmdr::input` or `cmdr::composer`:

```bash
cmdr::use cmdr::input
cmdr::use cmdr::composer
```

### Sourcing local files

Pass a path containing `/` to source a file relative to the calling file's directory:

```bash
cmdr::use ./lib/helpers.sh
cmdr::use ./partials/output.sh
```

### Loading validator rules

When your module calls `cmdr::use cmdr::validator`, all `.sh` files inside a `rules/` subdirectory of that module are sourced automatically. Rule functions follow the naming convention `cmdr::validator::rule::<name>` — no registration call needed. See [Validation](validation.md#custom-rules) for details.

---

## Conditional loading

You can bail out of registration entirely based on runtime conditions. A common pattern is checking for the presence of a Composer package before registering commands that depend on it:

```bash
# In mymod/main.sh
cmdr::use cmdr::composer
cmdr::composer::has vendor/package || return 0

# Only reached when vendor/package is installed
cmdr::register::alias mymod m
cmdr::register::help mymod run "Run something"
```

## Registering aliases

`cmdr::register::alias` registers a short token that expands to the full module or subcommand name during dispatch.

```bash
# Root-level alias: "cmdr g" → "cmdr greet"
cmdr::register::alias greet g

# Scoped alias: "cmdr greet f" → "cmdr greet formal"
# The same letter can mean different things under different parents.
cmdr::register::alias formal f greet
```

## Locking and hiding

Use `cmdr::register::lock` to prevent any higher-priority search path from overriding a module. Use `cmdr::register::hide` to exclude it from the root help listing (module-scoped help still works normally).

```bash
cmdr::register::lock greet    # cannot be overridden by user or project layers
cmdr::register::hide greet    # excluded from "cmdr help" listing
```

**Bare name resolution.** Inside a submodule's `main.sh` the loader sets the parent namespace as context, so you can write just the local segment — no need to spell out the full `::` path:

```bash
# In greet/formal/main.sh — locks greet::formal (not a module called "formal"):
cmdr::register::lock formal
```

**Ancestor locking.** Locking a submodule automatically locks every parent prefix as well, so the parent cannot be replaced in a way that bypasses the submodule's lock:

```bash
cmdr::register::lock greet::formal   # also locks greet
cmdr::register::lock formal          # in greet/formal/main.sh: also locks greet
```

Both functions accept a module name, a submodule name, or a root command name.

## Registering root commands

A root command is callable directly as `cmdr <name>` without belonging to a module namespace. Register it with `cmdr::register::command`:

```bash
# In main.sh:
cmdr::register::command deploy mymod::deploy "Deploy the application"
cmdr::register::lock deploy

cmdr::args::define deploy \
    "{env : Target environment}" \
    "{--dry-run|-n : Print commands without executing}"
```

If a `deploy.sh` file exists alongside `main.sh`, it is registered automatically for lazy loading. See [Arguments & Options](args.md) for argument declaration syntax.

## Native help

By default, `--help` and `help` are intercepted by cmdr and display the generated help page. Call `cmdr::register::native_help` when a command handles its own `--help` flag and the generated page would be misleading or incomplete.

```bash
cmdr::register::native_help deploy
```

With native help registered, `cmdr deploy --help` passes `--help` through to `deploy::run` as a regular argument instead of triggering cmdr's help page.

---

## Finding the project root

`cmdr::loader::find_project_root` echoes the absolute path to the detected project root. Use it when a command needs to resolve paths relative to the project:

```bash
my_module::build() {
    local root
    root="$(cmdr::loader::find_project_root)"
    cmdr::output::info "Building in ${root}"
}
```

Resolution order: `$CMDR_ROOT` env var → `--root` flag → walk up from `$PWD` looking for `composer.json` or `.git` → fall back to `$PWD`.

---

## Dynamic tab completion

Register a completer function for any command. It is called when the user presses Tab after that command and should print one candidate per line:

```bash
cmdr::register::completer greet::hello _greet_hello_complete

_greet_hello_complete() {
    echo "Alice"
    echo "Bob"
    echo "World"
}
```

See [Shell Completion](completion.md) for setup instructions.

---

## Distributing a module as a Composer package

Any Composer package can ship cmdr modules, hooks, rules, and scaffolds. Declare what the package provides under `extra.cmdr` in its `composer.json`:

```json
{
    "extra": {
        "cmdr": {
            "modules": {
                "deploy":  "src/cmdr",
                "release": "src/cmdr/release/main.sh"
            },
            "hooks":     ["src/cmdr/hooks.sh"],
            "rules":     ["src/cmdr/rules"],
            "scaffolds": ["src/cmdr/scaffolds"]
        }
    }
}
```

All paths are relative to the package root.

### `modules`

An object where each key is the module name and the value is the path to either a directory (containing `main.sh`) or an explicit `.sh` file. The module name becomes `_CMDR_LOADING_PREFIX` during sourcing, so bare `cmdr::register::lock` and auto-registration work the same as in a `.cmdr/` module.

### `hooks`

An array of paths to `hooks.sh` files. Each file is sourced when cmdr first loads its hook registry.

### `rules`

An array of paths to rule directories or individual `.sh` files. Each entry is sourced when the validator initialises, between the shipped rules and the user/project rules.

### `scaffolds`

An array of paths to scaffold root directories. Each subdirectory inside such a directory is registered as a `cmdr make <name>` scaffold type. Place a `make.sh` alongside the templates to customise the scaffolding behaviour (see [Scaffolding](make.md)).

### Priority and overriding

Vendor modules load at priority 2 — higher than shipped cmdr modules but lower than your own `~/.cmdr/` or `.cmdr/` directories. To lock a module name so it cannot be replaced, call `cmdr::register::lock` in its `main.sh`, just as you would for any other module.
