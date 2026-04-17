# Register — aliases, help entries, and alias token expansion.

# Single unified map. Root aliases use plain key, scoped use "parent:short".
declare -A ALIASES=()
declare -a HELP_ENTRIES=()
declare -a HELP_MODULE_ORDER=()
declare -A HELP_MODULE_SEEN=()
declare -A HELP_MODULE_ORIGIN=()
declare -A COMPLETERS=()
declare -A _CMDR_MODULE_FILES=()
declare -A _CMDR_MODULE_EXPLICIT=()
declare -A HELP_MODULE_HIDDEN=()
declare -A _CMDR_MODULE_LOCKED=()
_CMDR_MODULE_ORIGIN="global"

# Set by the loader before sourcing each main.sh so that cmdr::register::lock
# can resolve a bare module name (no ::) relative to its parent namespace.
# e.g. when sourcing tools/docker/main.sh this is "tools"; top-level is "".
_CMDR_LOADING_PREFIX=""

# Scaffold type → directory of the module that registered it.
# Populated by cmdr::register::make; used by cmdr::make to locate
# module-local scaffolds directories.
declare -A _CMDR_MAKE_MODULE_DIRS=()

# Root-level commands: name → bash function to invoke.
# Locking and hiding reuse the existing _CMDR_MODULE_LOCKED / HELP_MODULE_HIDDEN
# maps, so cmdr::register::lock and cmdr::register::hide work for root commands
# with no extra API.
declare -A _CMDR_ROOT_COMMANDS=()

# Root command implementation files for lazy loading.
# Populated automatically by cmdr::register::command when a <name>.sh file
# exists alongside the calling main.sh. Kept separate from _CMDR_MODULE_FILES
# so the multi-token module dispatcher never sees these as modules.
declare -A _CMDR_ROOT_COMMAND_FILES=()

# cmdr::register::alias <target> <short> [parent_module]
#
# Registers a short token that expands to <target> during dispatch.
# Works for both module aliases (e.g. "docker" → "d") and bare command
# aliases (e.g. "start" → "s").
#
# When <target> is already registered as a module in _CMDR_MODULE_FILES,
# the lock guard is applied: if the module was locked by an earlier search
# path, this registration is silently skipped (prevents overrides).
#
# Optional <parent_module> scopes the alias so the same letter can mean
# different things under different parents (e.g. "tools" under "laravel" → "l").
cmdr::register::alias() {
    local target="$1"
    local short="$2"
    local parent="${3:-}"
    if [[ -n "${_CMDR_MODULE_FILES[$target]+_}" && -n "${_CMDR_MODULE_LOCKED[$target]+_}" \
          && "${_CMDR_MODULE_LOCKED[$target]}" != "${_CMDR_MODULE_ORIGIN:-global}" ]]; then
        cmdr::output::fail "cmdr: cannot register alias '${short}' → '${target}': module '${target}' is locked"
    fi
    if [[ -n "$parent" ]]; then
        ALIASES["${parent}:${short}"]="$target"
    elif [[ "$target" == *::* ]]; then
        local _auto_parent="${target%::*}"
        local _auto_target="${target##*::}"
        ALIASES["${_auto_parent}:${short}"]="$_auto_target"
    else
        ALIASES["$short"]="$target"
    fi
}

# cmdr::register::lock <module>
# Prevents any later search path from overriding this module's implementation,
# aliases, or help entries. Records the current origin so that registrations
# from the same origin are still allowed after the lock is set.
#
# Name resolution: if <module> is a bare name (no ::) and _CMDR_LOADING_PREFIX
# is set, the name is resolved relative to that prefix — so a submodule's
# main.sh can just write cmdr::register::lock showcase rather than the full
# parent::showcase. Names that already contain :: are treated as absolute.
#
# Ancestor locking: every parent prefix of the resolved name is also locked so
# that replacing a parent module cannot bypass a locked submodule.
cmdr::register::lock() {
    local name="$1"

    # Resolve bare name relative to the current loading context.
    local full
    if [[ "$name" != *::* && -n "${_CMDR_LOADING_PREFIX:-}" ]]; then
        full="${_CMDR_LOADING_PREFIX}::${name}"
    else
        full="$name"
    fi

    # Lock the resolved key and every ancestor prefix.
    local prefix="" rest="$full" part
    while [[ -n "$rest" ]]; do
        if [[ "$rest" == *::* ]]; then
            part="${rest%%::*}"
            rest="${rest#*::}"
        else
            part="$rest"
            rest=""
        fi
        prefix="${prefix:+${prefix}::}${part}"
        _CMDR_MODULE_LOCKED["$prefix"]="${_CMDR_MODULE_ORIGIN:-global}"
    done
}

# cmdr::register::module <module> [<path>]
#
# Registers an implementation file for <module>, resolved relative to the calling
# file's directory. Stores the path in _CMDR_MODULE_FILES for lazy loading.
#
# Path resolution rules:
#   no path given          → <caller_dir>/<last_segment>.sh
#   path ends in .sh       → <caller_dir>/<path>
#   path is a directory    → <caller_dir>/<path>/<last_segment>.sh
#
# If the resolved file lives in a subdirectory and that subdirectory contains a
# main.sh, it is sourced immediately so the submodule can register itself.
cmdr::register::module() {
    local module="$1"
    local path="${2:-}"
    local caller_dir
    caller_dir="$(dirname "${BASH_SOURCE[1]}")"

    local last_segment="${module##*::}"
    local impl_file sub_dir=""

    if [[ -z "$path" ]]; then
        impl_file="${caller_dir}/${last_segment}.sh"
    elif [[ "$path" == *.sh ]]; then
        impl_file="${caller_dir}/${path}"
        local file_dir
        file_dir="$(dirname "${impl_file}")"
        [[ "$file_dir" != "$caller_dir" ]] && sub_dir="$file_dir"
    else
        impl_file="${caller_dir}/${path}/${last_segment}.sh"
        sub_dir="${caller_dir}/${path}"
    fi

    if [[ ! -f "$impl_file" ]]; then
        cmdr::output::error "cmdr: cmdr::register::module: file not found: $impl_file"
        return 1
    fi

    if [[ -n "${_CMDR_MODULE_LOCKED[$module]+_}" \
          && "${_CMDR_MODULE_LOCKED[$module]}" != "${_CMDR_MODULE_ORIGIN:-global}" ]]; then
        cmdr::output::fail "cmdr: cannot register module '${module}': it is locked"
    fi

    _CMDR_MODULE_FILES["$module"]="$impl_file"
    _CMDR_MODULE_EXPLICIT["$module"]="${_CMDR_MODULE_ORIGIN:-global}"

    if [[ -n "$sub_dir" && -f "${sub_dir}/main.sh" ]]; then
        # shellcheck source=/dev/null
        source "${sub_dir}/main.sh"
    fi
}

# cmdr::register::help <command> <description>          (2 args → root/general group)
# cmdr::register::help <module> <command> <description> (3 args → named module group)
cmdr::register::help() {
    local module command description
    if [ $# -eq 2 ]; then
        module=""
        command="$1"
        description="$2"
    else
        module="$1"
        command="$2"
        description="$3"
    fi

    if [[ -n "$module" && -n "${_CMDR_MODULE_LOCKED[$module]+_}" \
          && "${_CMDR_MODULE_LOCKED[$module]}" != "${_CMDR_MODULE_ORIGIN:-global}" ]]; then
        cmdr::output::fail "cmdr: cannot register help for '${module}::${command}': module '${module}' is locked"
    fi

    HELP_ENTRIES+=("${module}|${command}|${description}")

    local _seen_key="${module:-__root__}"
    if [[ -z "${HELP_MODULE_SEEN[$_seen_key]+_}" ]]; then
        HELP_MODULE_ORDER+=("$module")
        HELP_MODULE_SEEN["$_seen_key"]=1
        HELP_MODULE_ORIGIN["$_seen_key"]="${_CMDR_MODULE_ORIGIN:-global}"
    fi
}

# cmdr::register::hide <module>
# Marks a module as hidden so it is excluded from the root help listing.
# Module-scoped help (cmdr <module> help) still works normally.
cmdr::register::hide() {
    HELP_MODULE_HIDDEN["$1"]=1
}

# cmdr::register::command <name> <function> [<description>]
#
# Registers a root-level command callable as "cmdr <name>".
# <function> is the bash function to invoke.
#
# Auto-loading: if a <name>.sh file exists alongside the calling main.sh it is
# registered in _CMDR_ROOT_COMMAND_FILES and sourced lazily on first dispatch.
# This is intentionally separate from _CMDR_MODULE_FILES so the multi-token
# module dispatcher never treats the command as a module.
#
# Locking and hiding use the shared cmdr::register::lock / cmdr::register::hide
# functions — pass the command <name> to either just as you would a module name.
#
# Args/options for --help and tab-completion are declared separately via
# cmdr::args::define using <name> as the command key.
# An optional <description> adds an entry to the global help listing.
cmdr::register::command() {
    local name="$1"
    local fn="$2"
    local desc="${3:-}"

    if [[ -n "${_CMDR_MODULE_LOCKED[$name]+_}" \
          && "${_CMDR_MODULE_LOCKED[$name]}" != "${_CMDR_MODULE_ORIGIN:-global}" ]]; then
        cmdr::output::fail "cmdr: cannot register root command '${name}': it is locked"
    fi

    _CMDR_ROOT_COMMANDS["$name"]="$fn"

    # Auto-detect implementation file for lazy loading
    local caller_dir
    caller_dir="$(dirname "${BASH_SOURCE[1]}")"
    local impl_file="${caller_dir}/${name}.sh"
    if [[ -f "$impl_file" ]]; then
        _CMDR_ROOT_COMMAND_FILES["$name"]="$impl_file"
    fi

    if [[ -n "$desc" ]]; then
        cmdr::register::help "$name" "$desc"
    fi
}

# cmdr::register::completer <module::cmd> <function>
# Registers a function that emits dynamic completion candidates (one per line)
# for the given command path, called when the user tabs after that command.
cmdr::register::completer() {
    local key="$1" fn="$2"
    COMPLETERS["$key"]="$fn"
}

declare -A _CMDR_NATIVE_HELP=()

# cmdr::register::native_help <cmd>
#
# Marks <cmd> as using native help: --help and help are passed through
# to the command function as regular arguments instead of triggering
# cmdr's help page.
cmdr::register::native_help() {
    _CMDR_NATIVE_HELP["$1"]=1
}

# cmdr::register::expand_token <token> [current_parent]
# Resolves a single token against the ALIASES map, respecting parent scope.
cmdr::register::expand_token() {
    local t="$1"
    local parent="${2:-}"
    if [[ -n "$parent" ]]; then
        echo "${ALIASES["${parent}:${t}"]:-${ALIASES[$t]:-$t}}"
    else
        echo "${ALIASES[$t]:-$t}"
    fi
}

# cmdr::register::make <type> [description]
#
# Registers a scaffold type as a "cmdr make <type>" subcommand.
# Defined here so it is available at startup when module main.sh files load,
# without requiring the lazy cmdr::make core to be initialised first.
#
# Registers help + args for make::<type> and creates a default handler that
# calls cmdr::make::_default_handler. To override, define make::<type>
# yourself in a lazily-loaded .sh file — it will replace the default.
cmdr::register::make() {
    local type="$1"
    local desc="${2:-Scaffold a new ${type}}"

    if [[ ! "$type" =~ ^[a-z]+$ ]]; then
        cmdr::output::warning "cmdr::register::make: invalid type '${type}': use lowercase letters only."
        return 1
    fi

    [[ -n "${_CMDR_MAKE_MODULE_DIRS[$type]+_}" ]] && return 0

    local caller_dir
    caller_dir="$(dirname "${BASH_SOURCE[1]}")"
    _CMDR_MAKE_MODULE_DIRS["$type"]="$caller_dir"

    # Auto-register <caller_dir>/make.sh as the lazy implementation for make::<type>
    if [[ -f "${caller_dir}/make.sh" ]]; then
        _CMDR_MODULE_FILES["make::${type}"]="${caller_dir}/make.sh"
    fi

    cmdr::register::help make "$type" "$desc"
    cmdr::args::define "make::${type}" \
        "{name? : Name to scaffold}" \
        "{--global|-g : Scaffold into the user directory (~/.cmdr/)}"
}


# Registry for cmdr::call — maps command names to ordered candidate lists.
# Each entry is a newline-separated list of paths/names tried in order.
declare -A _CMDR_CALL_REGISTRY=()

# cmdr::register::call <name> <candidate>...
#
# Prepends one or more candidates to the search list for <name>.
# Calling it again (e.g. from user config) prepends further, so
# the last-registered candidates are tried first.
#
# Candidate forms:
#   bare name (no /)      → resolved via PATH using `command -v`
#   relative path (has /) → resolved relative to the project root
#   absolute path         → checked directly with -x
cmdr::register::call() {
    local name="$1"; shift
    local block="" candidate
    for candidate in "$@"; do
        block+="${candidate}"$'\n'
    done
    if [[ -n "${_CMDR_CALL_REGISTRY[$name]+_}" ]]; then
        _CMDR_CALL_REGISTRY[$name]="${block}${_CMDR_CALL_REGISTRY[$name]}"
    else
        _CMDR_CALL_REGISTRY[$name]="${block%$'\n'}"
    fi
}

declare -A _CMDR_HOOKS=()
declare -A _CMDR_HOOK_FILES=()

# cmdr::register::hook <hookname> <fn>
# Registers <fn> as a listener for <hookname>. Infers the module key from the
# loading context so cmdr::hook::run can config the module before calling <fn>.
cmdr::register::hook() {
    local hookname="$1" fn="$2"
    local caller_dir caller_basename module_key=""
    caller_dir="$(dirname "${BASH_SOURCE[1]}")"
    caller_basename="$(basename "$caller_dir")"
    if [[ -n "${_CMDR_LOADING_PREFIX:-}" ]]; then
        module_key="${_CMDR_LOADING_PREFIX}::${caller_basename}"
    elif [[ -f "${caller_dir}/main.sh" ]]; then
        module_key="$caller_basename"
    fi
    local entry="${fn}|${module_key}"
    if [[ -n "${_CMDR_HOOKS[$hookname]+_}" ]]; then
        _CMDR_HOOKS[$hookname]+=$'\n'"$entry"
    else
        _CMDR_HOOKS[$hookname]="$entry"
    fi
}

cmdr::register::alias help h
