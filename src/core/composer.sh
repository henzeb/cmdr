# Composer utilities — package detection and version comparison via the Composer CLI.

# Register default search order for the composer binary.
# Users may prepend their own path by calling cmdr::call::register composer <path>
# from a module or config file.
cmdr::register::call composer "vendor/bin/composer" "composer.phar" "composer"
cmdr::register::call php "php"

# cmdr::composer::has <vendor/package>
# Returns 0 if the package is installed, 1 otherwise.
cmdr::composer::has() {
    local package="$1"
    local root
    root="$(cmdr::loader::find_project_root)"
    cmdr::call composer --working-dir="${root}" show "${package}" &>/dev/null
}

# cmdr::composer::version <vendor/package>
# Echoes the installed version string to stdout (leading 'v' stripped).
# Returns 1 if the package is not installed or the version cannot be determined.
cmdr::composer::version() {
    local package="$1"
    local root version
    root="$(cmdr::loader::find_project_root)"
    version="$(cmdr::call composer --working-dir="${root}" show "${package}" 2>/dev/null \
        | awk '/^versions[[:space:]]/{print $NF}')"
    version="${version#v}"
    [[ -n "$version" ]] || return 1
    echo "$version"
}

# cmdr::composer::compare <vendor/package> <op> <version>
# Compares the installed package version against <version> using PHP's version_compare.
# <op> must be one of: = != < <= > >=
# Returns 0 if the comparison holds, 1 otherwise.
cmdr::composer::compare() {
    local package="$1"
    local op="$2"
    local version="$3"
    local installed
    installed="$(cmdr::composer::version "${package}")" || return 1
    cmdr::call php -r "exit(version_compare('${installed}', '${version}', '${op}') ? 0 : 1);"
}
