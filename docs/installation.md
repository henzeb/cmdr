# Installation

## Requirements

- **Bash 4.3 or higher** — required for associative arrays (`declare -A`) and namerefs (`local -n`).

  macOS ships with Bash 3.2. Install a modern version via Homebrew:

  ```bash
  brew install bash
  ```

- **Composer** — cmdr is distributed as a Composer package.

## Two ways to use cmdr

cmdr can be installed **globally** as a personal command runner available in every terminal session, or **per project** so a team shares a consistent set of commands through the project's own dependencies. The two approaches can also be combined.

---

### Installing globally

In a global setup, cmdr is available in every terminal session regardless of which project you are working in. Your personal modules and additions go in `~/.cmdr/`.

**1. Install via Composer:**

```bash
composer global require henze/cmdr
```

**2. Make sure Composer's global `bin` directory is on your PATH.**

bash — add to `~/.bashrc`:

```bash
export PATH="$HOME/.composer/vendor/bin:$PATH"
```

zsh — add to `~/.zshrc`:

```bash
export PATH="$HOME/.composer/vendor/bin:$PATH"
```

fish — add to `~/.config/fish/config.fish`:

```fish
fish_add_path $HOME/.composer/vendor/bin
```

> The exact path may be `~/.config/composer/vendor/bin` depending on your system. Run `composer global config bin-dir --absolute` to confirm.

**3. Verify:**

```bash
cmdr help
```

Your personal modules live in `~/.cmdr/`. Anything placed there is available in every project.

---

### Installing per project

In a per-project setup, cmdr is a dependency of the project itself. Every team member gets the same version with the same modules after running `composer install` — no global setup required.

**1. Add cmdr to your project:**

Decide whether cmdr belongs in your production dependencies or only in development. For most projects, it is a development tool:

```bash
composer require --dev henze/cmdr
```

If your production environment also relies on cmdr to run commands, install it as a regular dependency instead:

```bash
composer require henze/cmdr
```

**2. Run it via the Composer bin directory:**

```bash
./vendor/bin/cmdr help
```

**3. Optionally alias it for convenience** — run this inside the project directory:

```bash
./vendor/bin/cmdr alias
```

This writes a permanent alias to your shell config that points back to this project. See [Configuration → `--root`](configuration.md#root) for details.

Project-local modules go in `.cmdr/` at the root of your project (next to `composer.json`). They are loaded automatically and extend the shipped modules — adding new commands or overriding individual commands within an existing module.

---

### Combining both

When both a global install and a per-project install are active, cmdr loads modules from all locations. They are sourced in this order:

1. Shipped modules (inside the cmdr package itself)
2. Global modules (`~/.cmdr/`)
3. Project-local modules (`.cmdr/` at the project root)

Each layer extends what came before. New commands are added, and individual commands from earlier layers can be overridden by redefining them in a later layer.
