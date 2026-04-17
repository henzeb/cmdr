# Directory Structure

cmdr uses two directory locations for customization: a project-local `.cmdr/` directory and a global `~/.cmdr/` directory. Understanding what goes where determines how modules are discovered and which config values apply.

## The project directory

A project that uses cmdr can have a `.cmdr/` directory at its root (next to `composer.json` or `.git`). Everything in it is optional.

```
<project>/
└── .cmdr/
    ├── .config               ← project-local config overrides
    ├── .config.<env>         ← environment-specific overrides (e.g. .config.production)
    ├── <module>/             ← module (nested layout)
    │   ├── main.sh           ← registration
    │   ├── <module>.sh       ← implementations
    │   ├── rules/            ← module-local validation rules (optional)
    │   │   └── *.sh
    │   └── <submodule>/      ← submodule (nested layout)
    │       ├── main.sh       ← submodule registration
    │       └── <submodule>.sh← submodule implementations
    ├── <module>.sh           ← module (flat layout)
    ├── scaffolds/
    │   └── <type>/           ← project-local scaffold templates
    │       └── ...
    └── rules/
        └── *.sh              ← project-local custom validation rules
```

Modules placed here extend or override shipped modules. They are loaded last and have the highest priority. Use `cmdr::register::lock` inside a shipped module's `main.sh` to prevent a project from overriding it.

Run `cmdr init` from the project root to create `.cmdr/.config` with the default values.

## The global directory

The global directory at `~/.cmdr/` follows the same layout as the project directory. Modules here are available in every project and are loaded before project-local modules.

```
~/.cmdr/
├── .config                   ← global config overrides
├── .config.<env>             ← global environment-specific overrides
├── <module>/                 ← module (nested layout)
│   ├── main.sh               ← registration
│   ├── <module>.sh           ← implementations
│   ├── rules/                ← module-local validation rules (optional)
│   │   └── *.sh
│   └── <submodule>/          ← submodule (nested layout)
│       ├── main.sh           ← submodule registration
│       └── <submodule>.sh    ← submodule implementations
├── <module>.sh               ← module (flat layout)
├── scaffolds/
│   └── <type>/               ← global scaffold templates
│       └── ...
└── rules/
    └── *.sh                  ← global custom validation rules
```

Run `cmdr init --global` to create `~/.cmdr/.config` with the default values.

---

## Load order

The three locations are always loaded in the same order, from lowest to highest priority:

```
src/modules/     shipped modules   (origin: global)
~/.cmdr/         global modules    (origin: user)
<project>/.cmdr/ project modules   (origin: project)
```

Config files follow the same precedence:

```
.config                        shipped defaults
<project>/.cmdr/.config        project overrides
~/.cmdr/.config                global overrides
<project>/.cmdr/.config.<env>  project environment overrides  (when --env is set)
~/.cmdr/.config.<env>          global environment overrides   (when --env is set)
```

See [Configuration](configuration.md) for details on config variables and the `--env` flag.
