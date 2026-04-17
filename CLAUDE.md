## Project Overview

**cmdr** is a modular command runner framework written in Bash. Entry point: `bin/cmdr` (Bash 4.3+). No build step. No automated tests.

Source layout:
- `src/core/` — core framework (always loaded)
- `src/modules/` — shipped modules
- `src/rules/` — shipped validation rules
- `scaffolds/` — scaffold templates for `cmdr make`
- `docs/` — reference documentation

## File Conventions

**No shebangs in `.sh` files.** All scripts are sourced, never executed directly. Only `bin/cmdr` has a shebang. All `.sh` files share the same shell process — no subprocess isolation.

---

## Architecture

### Design constraints

- **Pure Bash only.** No external tools beyond what ships with a standard Bash environment. No Python, Node, etc.
- **Cross-platform: Git Bash (Windows), Linux, macOS.** Avoid OS-specific commands or GNU-only flags.

### Startup order

Version guard → resolve `_CMDR_SELF_DIR` → source `src/core/cmdr.sh` → pre-scan `--env`/`--root` → load shipped config → source all `main.sh` files from the three search paths → load config overrides → parse global flags → dispatch.

Config is loaded **after** modules are sourced, so `main.sh` files can reference config variables set later.

### Core components (`src/core/`)

| File | Purpose |
|------|---------|
| `cmdr.sh` | Bootstrapper; sources core files; registers lazy modules |
| `output.sh` | Colored logging: `info`, `warning`, `error`, `fail`, `success` |
| `register.sh` | All `cmdr::register::*` functions; global registry arrays |
| `args.sh` | Declarative argument/option parsing (`cmdr::args::*`) |
| `help.sh` | Help page rendering |
| `loader.sh` | Module discovery, config loading, lazy init (`cmdr::use`) |
| `prescan.sh` | Early argv scan for `--env`/`--root` (`cmdr::complete::prescan`) — runs before config loading |
| `dispatch.sh` | Command routing (`cmdr::dispatch`) — called by `bin/cmdr` after flag parsing |
| `self.sh` | Re-invocation helpers (`cmdr::self::*`) |
| `input.sh` | Interactive prompts — lazy module `cmdr::input` |
| `complete.sh` | Tab-completion engine — lazy module `cmdr::complete` |
| `composer.sh` | Composer package detection — lazy module `cmdr::composer` |
| `validator.sh` | Validation rules — lazy module `cmdr::validator` |
| `make.sh` | Scaffold generation — lazy module `cmdr::make` |

### Output functions and exit behaviour

`cmdr::output::success`, `cmdr::output::fail`, and `cmdr::output::error` all call `exit` — they terminate the process immediately. Only call them as the **last statement** of a command handler. Never use them inside loops or before code that must still run; use `cmdr::output::info` instead for mid-flow messages.

### Naming conventions

- Core API: `cmdr::<namespace>::<verb>` (e.g. `cmdr::register::lock`, `cmdr::args::get`)
- Module commands: `<module>::<subcommand>` (e.g. `docker::start`)
- Private helpers: `_cmdr_<namespace>_<name>` — never call these from module code

---

## Validation rules

Use existing rules from `src/rules/` — do not define custom `cmdr::validator::rule::*` functions inline. If something is required, use `required`. Input functions like `cmdr::input::multiselect` set the variable to `""` when nothing is selected, so `required` works correctly with them.

## Demo (`src/modules/demo/`)

The demo covers interactive input and output — not modules, aliases, or argument parsing. When adding a new `cmdr::input::*` or `cmdr::output::*` form, add a matching section to `src/modules/demo/demo.sh` so it appears as a selectable option in `cmdr demo`.

---

## Documentation

`docs/` is the authoritative reference for how things work and how to build things in cmdr. Read it before implementing a feature; check it when something is unclear.

- Every new feature needs a docs update. Use the `/docs` skill.
- Every change that affects existing behaviour needs the relevant docs updated too. Use the `/docs` skill.
