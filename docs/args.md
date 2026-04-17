# Arguments & Options

Arguments are positional values and options are named flags or values, both passed to a command. Declare them in `main.sh` using `cmdr::args::define` and retrieve them inside the command function in `<name>.sh`.

## Declaring arguments

Use `cmdr::args::define` with Laravel-style signature blocks. Argument blocks and option blocks can appear in any order in the call:

```bash
cmdr::args::define deploy::run \
    "{env : Target environment}" \
    "{tag? : Image tag to deploy}" \
    "{--force|-f : Skip confirmation prompts}" \
    "{--retries|-r=3 : Number of retry attempts}" \
    "{--output|-o= : Write log to this file}"
```

Each block is a string wrapped in `{ }`. A description can be appended after ` : `.

### Argument blocks

| Syntax | Type | Description |
|---|---|---|
| `{name}` | Required | Must be provided; dispatcher exits with an error message if missing |
| `{name?}` | Optional | May be omitted, resolves to `""` |
| `{name=default}` | Optional with default | Resolves to `default` when not provided |
| `{name*}` | Variadic | Consumes all remaining positional values |

Arguments are positional — they are matched to values in the order they are declared. A variadic argument must be last.

### Option blocks

| Syntax | Type | Description |
|---|---|---|
| `{--flag}` | Boolean flag | `"1"` when present, `""` when absent |
| `{--name=}` | String option | Value must be supplied by the caller |
| `{--name=default}` | String option with default | Resolves to `default` when not provided |

Options are not positional — they can appear anywhere on the command line and are always prefixed with `--`.

### Short aliases

Append `|-s` to any option block to register a single-character short alias:

```bash
"{--force|-f : Skip confirmation prompts}"    # boolean with -f
"{--tag|-t= : Docker image tag to deploy}"    # string with -t
"{--retries|-r=3 : Number of retry attempts}" # string+default with -r
```

The short alias inherits the type and default of the long option.

---

## Retrieving values

### Positional arguments

Inside a command function, use `cmdr::args::get`:

```bash
deploy::run() {
    local env; env=$(cmdr::args::get env)
    local tag; tag=$(cmdr::args::get tag)
}
```

### Named options

Inside a command function, use `cmdr::args::get_option`:

```bash
deploy::run() {
    local force;   force=$(cmdr::args::get_option force)
    local retries; retries=$(cmdr::args::get_option retries)
    local output;  output=$(cmdr::args::get_option output)
}
```

### Resolution order

Both `cmdr::args::get` and `cmdr::args::get_option` resolve values in the same order:

1. Value provided by the user on the command line
2. Default registered in the signature block
3. Empty string

An optional fallback can be passed as a second argument and takes effect only when neither a user value nor a registered default is present:

```bash
name=$(cmdr::args::get name "Stranger")
retries=$(cmdr::args::get_option retries 1)
```

---

## Passing values on the command line

Both styles are accepted for string options:

```bash
cmdr deploy run --tag=v1.2.3
cmdr deploy run --tag v1.2.3
cmdr deploy run -t=v1.2.3
cmdr deploy run -t v1.2.3
```

Boolean flags do not take a value:

```bash
cmdr deploy run --force
cmdr deploy run -f
```

## Passthrough arguments

Arguments after `--` are not parsed as positionals or options. They are collected into `_CMDR_PASSTHROUGH` and can be forwarded to another command:

```bash
greet::hello() {
    some_external_tool "${_CMDR_PASSTHROUGH[@]+"${_CMDR_PASSTHROUGH[@]}"}"
}
```

When no `--` separator is used but the number of provided positionals exceeds the number of declared argument slots, all positionals are automatically routed to `_CMDR_PASSTHROUGH`. This allows callers to omit `--` when forwarding a subcommand:

```bash
# Both are equivalent:
cmdr greet hello -- echo hi
cmdr greet hello echo hi
```

## Using global options

Global options are cmdr-level flags declared in `bin/cmdr` that apply to every invocation. They are parsed and stripped before any module or command receives the arguments.

The shipped global options are:

| Flag | Short | Description |
|------|-------|-------------|
| `--env=<name>` | `-e` | Load `.config.<name>` on top of the base config |
| `--root=<path>` | `-r` | Override the project root directory |

Read a global option from anywhere inside a module or command:

```bash
local env;  env=$(cmdr::args::get_global env)
local root; root=$(cmdr::args::get_global root)
```

Like `cmdr::args::get_option`, an optional fallback can be passed:

```bash
env=$(cmdr::args::get_global env production)
```

Resolution order: parsed value → registered default → fallback argument → `""`.

See [Configuration](configuration.md) for details on how `--env` and `--root` affect config loading.

## The `--help` flag

`--help` is handled by the dispatcher before the command function runs. Passing it anywhere in the arguments shows the help page for that command:

```bash
cmdr deploy run --help
```

You do not need to handle `--help` in your command function.
