# cmdr

[![Latest Version](https://img.shields.io/packagist/v/henzeb/cmdr.svg)](https://packagist.org/packages/henzeb/cmdr)
[![Total Downloads](https://img.shields.io/packagist/dt/henzeb/cmdr.svg)](https://packagist.org/packages/henzeb/cmdr)
[![License](https://img.shields.io/packagist/l/henzeb/cmdr.svg)](https://packagist.org/packages/henzeb/cmdr)

A pure Bash framework for crafting beautiful, reusable commands.

Every project accumulates scripts for mundane tasks — spinning up local environments, managing Kubernetes clusters, or running a test suite in a loop to catch flaky tests. They work, but they sprawl. New team members have no idea what exists, what arguments a script expects, or what it will actually do. The answer is usually a wall of `--help` text nobody wrote, or a wiki page nobody updated.

Tools like [bashly](https://bashly.dev/) and [bash-it](https://github.com/Bash-it/bash-it) solve adjacent problems: bashly generates CLI apps from YAML but requires a build step and a Ruby runtime; bash-it is a personal shell framework for customizing your own environment, not for sharing commands with a team. Neither gives you a way to distribute a consistent set of commands through your project's own dependencies.

cmdr does. Install it per-project via Composer, add your functionality in the project's `.cmdr` directory and your whole team gets the same commands after `composer install` — with argument parsing, validation, interactive prompts, tab completion, and help pages built in. No build step. No runtime beyond Bash.

---

## Features

- **Modules** — organize commands into namespaced modules; add, override, or extend them per-project or globally
- **No build step** — pure Bash, sourced directly; requires Bash 4.3+
- **Declarative args & options** — define positional arguments and flags with types, defaults, and descriptions
- **Validation** — 30+ built-in rules with support for custom rules and named groups
- **Interactive input** — built-in prompts (text, confirm, select, multiselect) with validation support
- **Shell completion** — tab completion for Bash, Zsh, and Fish
- **Hooks** — event-driven extension points for modules
- **Scaffold generator** — `cmdr make module` bootstraps a new module from a template
- **Composer-distributed** — install globally or per-project like any other package

---

## Installation

**Requirements:** Bash 4.3+. macOS ships with Bash 3.2 — install a modern version via Homebrew (`brew install bash`). Composer is required to install cmdr.

**Global** (available system-wide):

```bash
composer global require henze/cmdr
```

Make sure Composer's global `bin` directory is on your `PATH`. Run `composer global config bin-dir --absolute` to find the path, then add it to your shell config.

**Per-project** (shared with your team as a Composer dependency):

```bash
composer require --dev henze/cmdr
./vendor/bin/cmdr alias   # optional: creates a shell alias for this project
```

See [docs/installation.md](docs/installation.md) for full PATH setup instructions and how to combine both approaches.

---

## Usage

```bash
cmdr help                          # list all available commands
cmdr <module> help                 # list commands in a module
cmdr <module> <subcommand>         # run a command
cmdr <module> <subcommand> --help  # show command help
```

---

## Documentation

- [Installation](docs/installation.md)
  - [Requirements](docs/installation.md#requirements)
  - [Installing globally](docs/installation.md#installing-globally)
  - [Installing per project](docs/installation.md#installing-per-project)
  - [Combining both](docs/installation.md#combining-both)
- [Configuration](docs/configuration.md)
  - [Config file locations](docs/configuration.md#config-file-locations)
  - [Using global flags](docs/configuration.md#using-global-flags)
  - [Available config variables](docs/configuration.md#available-config-variables)
- [Directory Structure](docs/structure.md)
  - [The project directory](docs/structure.md#the-project-directory)
  - [The global directory](docs/structure.md#the-global-directory)
  - [Load order](docs/structure.md#load-order)
- [Modules](docs/modules.md)
  - [Choosing a layout](docs/modules.md#choosing-a-layout)
  - [Search paths](docs/modules.md#search-paths)
  - [Creating a module](docs/modules.md#creating-a-module)
  - [Adding submodules](docs/modules.md#adding-submodules)
  - [Declaring dependencies with cmdr::use](docs/modules.md#declaring-dependencies-with-cmdrus)
  - [Conditional loading](docs/modules.md#conditional-loading)
  - [Registering aliases](docs/modules.md#registering-aliases)
  - [Locking and hiding](docs/modules.md#locking-and-hiding)
  - [Registering root commands](docs/modules.md#registering-root-commands)
  - [Native help](docs/modules.md#native-help)
  - [Finding the project root](docs/modules.md#finding-the-project-root)
  - [Dynamic tab completion](docs/modules.md#dynamic-tab-completion)
  - [Distributing a module as a Composer package](docs/modules.md#distributing-a-module-as-a-composer-package)
- [Hooks](docs/hooks.md)
  - [Registering a listener](docs/hooks.md#registering-a-listener)
  - [Implementing listeners](docs/hooks.md#implementing-listeners--hookssh)
  - [Firing a hook](docs/hooks.md#firing-a-hook)
  - [Discovering hook files](docs/hooks.md#discovering-hook-files)
  - [Naming hooks](docs/hooks.md#naming-hooks)
  - [Handling return values](docs/hooks.md#handling-return-values)
  - [Bootstrap hooks](docs/hooks.md#bootstrap-hooks)
- [Arguments & Options](docs/args.md)
  - [Declaring arguments](docs/args.md#declaring-arguments)
  - [Retrieving values](docs/args.md#retrieving-values)
  - [Passthrough arguments](docs/args.md#passthrough-arguments)
  - [Using global options](docs/args.md#using-global-options)
- [Output](docs/output.md)
  - [Output helpers](docs/output.md#output-helpers)
  - [Configuring output](docs/output.md#configuring-output)
- [Input](docs/input.md)
  - [Prompt helpers](docs/input.md#prompt-helpers)
  - [The description argument](docs/input.md#the-description-argument)
  - [Using input with validation](docs/input.md#using-input-with-validation)
- [Shell Completion](docs/completion.md)
  - [Installing completion](docs/completion.md#installing-completion)
  - [What gets completed](docs/completion.md#what-gets-completed)
  - [Registering dynamic completers](docs/completion.md#registering-dynamic-completers)
- [Validation](docs/validation.md)
  - [Creating named validator groups](docs/validation.md#creating-named-validator-groups)
  - [Validating interactive input](docs/validation.md#validating-interactive-input)
  - [Built-in rules](docs/validation.md#built-in-rules)
  - [Writing custom rules](docs/validation.md#writing-custom-rules)
  - [Overriding error messages](docs/validation.md#overriding-error-messages)
- [Composer utilities](docs/composer.md)
  - [Checking for a package](docs/composer.md#checking-for-a-package)
  - [Inspecting versions](docs/composer.md#inspecting-versions)
- [JSON utilities](docs/json.md)
  - [Extracting a value](docs/json.md#extracting-a-value)
- [Shell helpers](docs/shell.md)
  - [Writing to the shell config](docs/shell.md#writing-to-the-shell-config)
  - [Checking the environment](docs/shell.md#checking-the-environment)
- [Callers](docs/callers.md)
  - [Re-invoking cmdr](docs/callers.md#re-invoking-cmdr)
  - [Resolving external commands](docs/callers.md#resolving-external-commands)
  - [Registering candidates](docs/callers.md#registering-candidates)
- [Scaffolding](docs/make.md)
  - [Scaffolding a module](docs/make.md#scaffolding-a-module)
  - [Generated files](docs/make.md#generated-files)
  - [Registering a custom scaffold type](docs/make.md#registering-a-custom-scaffold-type)
  - [Using the scaffold API](docs/make.md#using-the-scaffold-api)
  - [Placeholder substitution](docs/make.md#placeholder-substitution)
- Shipped modules
  - [init](docs/modules/init.md)
  - [docker](docs/modules/docker.md)
