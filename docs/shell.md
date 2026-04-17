# Shell helpers

cmdr provides helpers for writing to the user's shell config file and checking the environment. Load them with:

```bash
cmdr::use cmdr::shell
```

The correct RC file is detected automatically from `$SHELL`: `~/.bashrc` (Linux bash), `~/.bash_profile` (macOS bash), `~/.zshrc` (zsh), or `~/.config/fish/completions/cmdr.fish` (fish).

---

## Writing to the shell config

### `cmdr::shell::write`

Appends a line to the user's RC file if it is not already present. Fails if the shell is not supported.

```bash
cmdr::shell::write 'export EDITOR=vim'
```

On success it prints an info message telling the user to reload their shell. If the line already exists, the optional second argument is printed instead and the function returns without writing:

```bash
cmdr::shell::write 'export EDITOR=vim' "EDITOR is already set in your shell config."
```

### `cmdr::shell::remove_line`

Removes all lines that contain the given pattern (fixed-string match) from the user's RC file. No-ops silently if no matching lines exist. Fails if the shell is not supported.

```bash
cmdr::shell::remove_line 'export EDITOR=vim'
```

---

## Checking the environment

### `cmdr::shell::line_exists`

Returns `0` if the given string is present anywhere in the RC file, `1` otherwise. Uses a fixed-string match.

```bash
if cmdr::shell::line_exists 'export EDITOR=vim'; then
    cmdr::output::info "Already configured."
fi
```

### `cmdr::shell::command_exists`

Returns `0` if the given command is callable in the current environment, `1` otherwise. Uses `command -v` — no PATH parsing needed.

```bash
if cmdr::shell::command_exists docker; then
    cmdr::output::info "Docker is available."
fi
```
