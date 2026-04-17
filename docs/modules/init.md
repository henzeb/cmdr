# init

Scaffolds a `.cmdr/.config` file in the current project or globally in `~/.cmdr/`.

```
cmdr init [--force|-f] [--global|-g]
```

| Option | Description |
|--------|-------------|
| `--force`, `-f` | Overwrite an existing config file |
| `--global`, `-g` | Write to `~/.cmdr/` instead of the project |

If the config file already exists and `--force` is not passed, cmdr merges any missing parameters from the shipped template into the existing file rather than overwriting it.

---

## Post-init prompts

When run interactively, `cmdr init` asks two follow-up questions after writing the config file.

**Install shell completion?**
Delegates to `cmdr completion install`, which appends `source <(cmdr completion <shell>)` to your RC file. If completion is already installed the prompt is skipped and a message is shown instead.

**Create a global shell alias?**
Appends an `alias <name>=/path/to/cmdr` entry to your RC file so you can invoke cmdr by name from any directory. Defaults to `cmdr`. Validated with the `shell_alias` rule — re-prompts if an alias with that name already exists in the RC file.

This prompt is skipped when:
- cmdr is already reachable on `$PATH` as itself (global installation)
- The shell is fish (fish uses completion files, not RC aliases)
- An alias was already written by a previous `cmdr init` run

If you declined either prompt, you can run them independently:
```bash
cmdr completion install   # install completion at any time
```

---

## Hooks

| Hook | When |
|------|------|
| `cmdr.initializing` | Before initialization |
| `cmdr.initialized` | After initialization — only fired when the config was created or updated |
