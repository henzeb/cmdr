# Configuration

cmdr is configured through plain Bash variable files named `.config`. These are sourced at startup and control the runtime behaviour of cmdr and its modules.

## Initializing a project

Run `cmdr init` at the root of your project to create `.cmdr/.config` with the default configuration values:

```bash
cmdr config
```

To initialize your global config at `~/.cmdr/.config` instead:

```bash
cmdr config --global
```

Use `--force` to overwrite an existing file in either case:

```bash
cmdr config --force
cmdr config --global --force
```

---

## Config file locations

Config files are loaded in this order, with later files taking precedence:

| Location | Scope | When to use |
|---|---|---|
| `.config` (inside the cmdr package) | Shipped defaults | Baseline values, do not edit |
| `.cmdr/.config` (project root) | Project-local | Settings shared by the whole team |
| `~/.cmdr/.config` (home directory) | Global | Personal preferences, applies to all projects |

The project-local and global config files are optional. Create them only when you need to change a value.

Config is loaded **after** all modules are registered, so module `main.sh` files can reference config variables that will be set later at runtime.

## Using global flags

### `--root`

Overrides the project root directory. cmdr normally detects the root by walking up from the current working directory until it finds a `composer.json` or `.git`. If neither is found, the current directory is used.

A common use case is creating a shell alias per project, so you can run its commands from anywhere. Run this inside the project directory:

```bash
cmdr alias
```

This prompts you for an alias name, then writes an alias to your shell config (`~/.bashrc`, `~/.zshrc`, or `~/.config/fish/completions/cmdr.fish`) that hard-codes `--root` for the current project. You can also pass the name directly:

```bash
cmdr alias myapp
```

After reloading your shell you can invoke the project's commands from any directory:

```bash
myapp docker start
myapp artisan migrate
```

If `cmdr` is already available as a global command, `cmdr alias` will ask you to confirm before writing the alias.

To see all cmdr project aliases currently in your shell config:

```bash
cmdr aliases
```

To remove an alias:

```bash
cmdr unalias myapp
```

This deletes the matching `alias` line from your RC file. Reload your shell to apply the change.

You can also set `CMDR_ROOT` as an environment variable when you prefer not to use an alias:

```bash
export CMDR_ROOT=/path/to/project
cmdr docker start
```

### `--env`

Loads an additional environment-specific config file on top of the normal config stack. After loading `.cmdr/.config` and `~/.cmdr/.config`, cmdr will also source `.cmdr/.config.<env>` and `~/.cmdr/.config.<env>` if they exist:

```bash
cmdr --env production deploy
```

Both the project-local and global variants are loaded in that order, so you can split env overrides between team-shared values (`.cmdr/.config.production`) and personal ones (`~/.cmdr/.config.production`).

Use this to maintain separate settings per environment without duplicating the full config file:

```
.cmdr/
  .config             ← base config (committed)
  .config.production  ← production overrides (committed)
  .config.staging     ← staging overrides (committed)
```

---

## Available config variables

### `CMDR_TAG`

The label printed in brackets before every output message. Default: `CMDR`.

```bash
CMDR_TAG=CMDR
```

Example output with the default tag:

```
[CMDR]: Starting containers...
```

Change it to match your project name:

```bash
CMDR_TAG=MYAPP
```

### `CMDR_TIMESTAMP`

Whether to include a timestamp in output messages. Disabled by default.

```bash
CMDR_TIMESTAMP=false
```

Set to `true` to enable:

```bash
CMDR_TIMESTAMP=true
```

### `CMDR_TIMESTAMP_FORMAT`

The format string passed to `date` when timestamps are enabled. Uses `strftime` syntax.

```bash
CMDR_TIMESTAMP_FORMAT=%Y-%m-%d %H:%M:%S
```

---

## Example

A project-local `.cmdr/.config` that sets a custom tag and enables timestamps:

```bash
CMDR_TAG=ACME
CMDR_TIMESTAMP=true
CMDR_TIMESTAMP_FORMAT=%H:%M:%S
```

Output would then look like:

```
[ACME]: 14:32:01 Starting containers...
```
