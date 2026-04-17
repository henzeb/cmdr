# Composer utilities

cmdr ships a lazy module with helpers for inspecting installed Composer packages. Load it before use:

```bash
cmdr::use cmdr::composer
```

---

## Checking for a package

### `cmdr::composer::has`

Returns `0` if the given package is installed in the project, `1` otherwise. The most common use is guarding module registration so commands only appear when their dependency is present:

```bash
# In main.sh
cmdr::use cmdr::composer
cmdr::composer::has vendor/package || return 0

# Only reached when vendor/package is installed
cmdr::register::help mymod run "Run something"
```

---

## Inspecting versions

### `cmdr::composer::version`

Echoes the installed version string for a package (leading `v` stripped). Returns `1` if the package is not installed or the version cannot be determined.

```bash
local ver
ver="$(cmdr::composer::version laravel/framework)"
cmdr::output::info "Laravel version: ${ver}"
```

### `cmdr::composer::compare`

Compares the installed version of a package against a given version using PHP's `version_compare`. The operator must be one of `=` `!=` `<` `<=` `>` `>=`.

```bash
if cmdr::composer::compare laravel/framework ">=" "11.0.0"; then
    cmdr::output::info "Laravel 11+ detected."
fi
```

Returns `1` if the package is not installed or the comparison does not hold.
