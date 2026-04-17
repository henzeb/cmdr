# Shell Completion

cmdr includes built-in tab-completion support for Bash, Zsh, and Fish. Once installed, pressing Tab after `cmdr` completes module names, subcommands, options, and dynamic values registered by individual modules.

## Installing completion

The easiest way is to let cmdr detect your shell and install automatically:

```bash
cmdr completion install
```

This appends the appropriate completion script to your shell's RC file and tells you what was added.

| Shell | File |
|-------|------|
| Bash (Linux / Git Bash) | `~/.bashrc` |
| Bash (macOS) | `~/.bash_profile` |
| Zsh | `~/.zshrc` |
| Fish | `~/.config/fish/completions/cmdr.fish` |

Alternatively, install manually for a specific shell:

```bash
# Bash — add to ~/.bashrc (Linux/Git Bash) or ~/.bash_profile (macOS)
source <(cmdr completion bash)

# Zsh — add to ~/.zshrc
source <(cmdr completion zsh)

# Fish — add to ~/.config/fish/config.fish
cmdr completion fish | source
```

After installing, restart your shell or source the RC file:

```bash
source ~/.bashrc        # Linux / Git Bash
source ~/.bash_profile  # macOS
source ~/.zshrc         # Zsh
```

---

## What gets completed

### Module names and subcommands

Typing a partial module name or subcommand and pressing Tab completes it from the list of registered commands:

```
cmdr do<TAB>       → docker
cmdr docker <TAB>  → start  stop  build  ...
```

Hidden modules (registered with `cmdr::register::hide`) are excluded from completion candidates.

### The `help` keyword

`help` is always offered as a completion candidate at the root level and after any module name:

```
cmdr <TAB>         → docker  laravel  help  ...
cmdr docker <TAB>  → start  stop  help  ...
```

When `--help` is already present in the typed command, no further completions are offered. Typing `cmdr help <TAB>` offers root module names but omits `help` itself.

### Options

After a subcommand that has registered options, `--help` is always offered. For root commands (registered with `cmdr::register::command`), all declared `--options` and their `-s` short forms are also offered as candidates:

```
cmdr deploy <TAB>  → --dry-run  --env  -e  -n  --help
```

### The `--root` global flag

When the cursor is on the value position for `--root`, directory completion is delegated to the shell:

```
cmdr --root /pro<TAB>    → /projects/  (shell directory completion)
cmdr --root=/pro<TAB>    → /projects/  (inline form, same behaviour)
```

---

## Registering dynamic completers

Register a function that emits custom candidates for a specific command — useful for context-aware completions such as container names, environment names, or file paths.

```bash
# In main.sh:
cmdr::register::completer docker::start _docker_complete_services

_docker_complete_services() {
    docker ps --format '{{.Names}}'
}
```

The function is called when the user presses Tab after `cmdr docker start`. It should write one candidate per line to stdout. When a dynamic completer is registered for a command, its output replaces the default subcommand listing for that position.

## Printing the completion scripts

To inspect what gets installed, or to integrate with a custom setup:

```bash
cmdr completion bash   # print the Bash completion script
cmdr completion zsh    # print the Zsh completion script
cmdr completion fish   # print the Fish completion script
```
