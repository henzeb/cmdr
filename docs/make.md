# Scaffolding

cmdr includes a `make` command for generating new modules from templates. It can also be extended by other modules to scaffold their own resource types.

## Scaffolding a module

```bash
cmdr make module
```

This prompts for a module name, whether to lock it, and whether to hide it from the global help listing. The generated files are placed in `.cmdr/<name>/` inside the current project (or `~/.cmdr/<name>/` with `--global`).

```bash
# Scaffold into the user directory
cmdr make module --global
```

The name can also be passed directly to skip the prompt:

```bash
cmdr make module deploy
```

## Generated files

Running `cmdr make module greet` produces:

```
.cmdr/
  greet/
    main.sh   ← registration (alias, help, args)
    greet.sh  ← command implementations
```

The generated files include working examples ready to edit. See [Modules](modules.md) for the full module structure.

## Registering a custom scaffold type

Any module can register its own `make` subtype using `cmdr::register::make`. This adds a `cmdr make <type>` command and wires up the scaffold directory automatically.

```bash
# In main.sh
cmdr::register::make controller "Scaffold a new controller"
```

The scaffold files live in a `scaffolds/<type>/` directory alongside `main.sh`. Every file in that directory is copied to the target, with `{{VARNAME}}` placeholders substituted from variables in the calling scope.

```bash
# In make.sh (or the lazy implementation file)
make::controller() {
    local NAME; NAME=$(cmdr::args::get name)
    # {{NAME}} in scaffold files is replaced with $NAME
    cmdr::make::generate controller ".cmdr/controllers/${NAME}"
    cmdr::output::info "Scaffolded controller '${NAME}'"
}
```

## Using the scaffold API

### `cmdr::make::generate <type> <target_dir>`

Copies all files from the scaffold directory for `<type>` to `<target_dir>`. Applies `{{VARNAME}}` substitution to both file contents and filenames. Scaffold directories are resolved in priority order: project (`.cmdr/scaffolds/<type>/`) → user (`~/.cmdr/scaffolds/<type>/`) → module directory (`scaffolds/<type>/` alongside the registering `main.sh`) → shipped.

### `cmdr::make::copy <scaffold/relative/path> <dest_file>`

Copies a single scaffold file to `<dest_file>`, applying `{{VARNAME}}` substitution. Useful when you need explicit control over where each file lands.

```bash
local NAME="greet" LOCK="" HIDE="cmdr::register::hide greet"
cmdr::make::copy module/main.sh ".cmdr/greet/main.sh"
cmdr::make::copy module/module.sh ".cmdr/greet/greet.sh"
```

## Placeholder substitution

Scaffold files use `{{VARNAME}}` placeholders. These are replaced with the value of `$VARNAME` from the calling scope at generation time. A line that consists solely of a placeholder that resolves to an empty string is removed entirely, keeping the output clean.

```bash
# scaffolds/module/main.sh
cmdr::register::module {{NAME}}
{{LOCK}}
{{HIDE}}
```

With `NAME=greet`, `LOCK=""`, `HIDE="cmdr::register::hide greet"` this produces:

```bash
cmdr::register::module greet
cmdr::register::hide greet
```
