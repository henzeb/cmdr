# Loader — project-root detection, module sourcing, and module initialisation.
# Requires $_CMDR_SELF_DIR to be set by the calling binary before this file is sourced.

# ---------------------------------------------------------------------------
# Project root detection — walks up from CWD to find composer.json or .git
# ---------------------------------------------------------------------------
cmdr::loader::find_project_root() {
    if [[ -n "${CMDR_ROOT:-}" ]]; then
        echo "${CMDR_ROOT}"
        return 0
    fi
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        [[ -f "$dir/composer.json" || -d "$dir/.git" ]] && { echo "$dir"; return 0; }
        dir="$(dirname "$dir")"
    done
    echo "$PWD"
}

# ---------------------------------------------------------------------------
# Source all module files from all three search paths.
#
# Search order — later paths override earlier (user > project > vendor):
#   1. $_CMDR_SELF_DIR/scripts/   shipped with this package
#   2. <project-root>/.cmdr/      project-local overrides / additions
#   3. ~/.cmdr/                   user-global overrides / additions
#
# Each directory supports two layouts:
#   docker.sh          → module "docker"
#   docker/script.sh   → module "docker"
#
# Module files must be lightweight at source time: only cmdr::register:: calls
# and an init_<module>() function definition. All actual command
# implementations live inside init_<module>() and are loaded on first use.
# ---------------------------------------------------------------------------
cmdr::loader::source_config_defaults() {
    if [[ -f "$_CMDR_SELF_DIR/../.config" ]]; then
        source "$_CMDR_SELF_DIR/../.config"
    fi
}

cmdr::loader::source_config_overrides() {
    local root
    root="$(cmdr::loader::find_project_root)"

    if [[ -f "$root/.cmdr/.config" ]]; then
        source "$root/.cmdr/.config"
    fi
    if [[ -f "${HOME}/.cmdr/.config" ]]; then
        source "${HOME}/.cmdr/.config"
    fi
}

cmdr::loader::source_config_env() {
    local env="$1"
    local root
    root="$(cmdr::loader::find_project_root)"

    if [[ -f "$root/.cmdr/.config.${env}" ]]; then
        source "$root/.cmdr/.config.${env}"
    fi
    if [[ -f "${HOME}/.cmdr/.config.${env}" ]]; then
        source "${HOME}/.cmdr/.config.${env}"
    fi
}

cmdr::loader::source_modules() {
    local -a search_paths=()
    local -a search_origins=()
    local root
    root="$(cmdr::loader::find_project_root)"

    search_paths+=("$_CMDR_SELF_DIR/../src/modules")
    search_origins+=("global")

    if [[ -d "${HOME}/.cmdr" ]]; then
        search_paths+=("${HOME}/.cmdr")
        search_origins+=("user")
    fi

    if [[ -d "$root/.cmdr" ]]; then
        search_paths+=("$root/.cmdr")
        search_origins+=("project")
    fi

    local dir f sub name i
    for i in "${!search_paths[@]}"; do
        dir="${search_paths[$i]}"
        _CMDR_MODULE_ORIGIN="${search_origins[$i]}"
        [[ -d "$dir" ]] || continue

        # Flat layout: docker.sh → module "docker"
        for f in "$dir"/*.sh; do
            [[ -f "$f" ]] || continue
            name="$(basename "$f" .sh)"
            [[ "$name" == "tools" ]] && continue
            # shellcheck source=/dev/null
            source "$f"
        done

        # Nested layout: docker/main.sh → module "docker"
        for sub in "$dir"/*/; do
            [[ -d "$sub" ]] || continue
            [[ -f "${sub}main.sh" ]] || continue
            name="$(basename "${sub%/}")"
            _cmdr_loader_source_with_prefix "" "${sub}main.sh"
            _cmdr_loader_auto_register "${sub%/}" "$name"
        done
    done

    _CMDR_MODULE_ORIGIN="global"
}

# ---------------------------------------------------------------------------
# Auto-register the implementation file for a nested module if not already
# registered, and recursively discover submodule directories.
#
# Called after sourcing <module>/main.sh. Does two things:
#   1. If <name>.sh exists in <dir> and the module is not yet registered in
#      _CMDR_MODULE_FILES (and is not a root command), register it for lazy
#      loading automatically.
#   2. Scan subdirectories for submodule main.sh files. If a submodule was
#      not already registered by an explicit cmdr::register::module call in
#      the parent's main.sh, source its main.sh here, then recurse.
#
# Arguments:
#   $1  dir    — directory of the module (where main.sh lives), no trailing /
#   $2  module — full module key, e.g. "demo" or "demo::showcase"
# ---------------------------------------------------------------------------
_cmdr_loader_register_impl_file() {
    local _dir="$1" _module="$2"
    local _name="${_module##*::}"
    local _impl="${_dir}/${_name}.sh"
    local _cur_origin="${_CMDR_MODULE_ORIGIN:-global}"
    [[ -f "$_impl" ]] || return 0
    [[ -n "${_CMDR_ROOT_COMMANDS[$_module]+_}" ]] && return 0
    if [[ -n "${_CMDR_MODULE_LOCKED[$_module]+_}" \
          && "${_CMDR_MODULE_LOCKED[$_module]}" != "$_cur_origin" ]]; then
        return 0
    fi
    [[ "${_CMDR_MODULE_EXPLICIT[$_module]:-}" == "$_cur_origin" ]] && return 0
    _CMDR_MODULE_FILES["$_module"]="$_impl"
}

# ---------------------------------------------------------------------------
# _cmdr_loader_source_with_prefix <prefix> <file>
#
# Sources <file> with _CMDR_LOADING_PREFIX set to <prefix>, restoring the
# previous value on return. Centralises the save/set/source/restore pattern
# so callers cannot accidentally skip the restore step.
# ---------------------------------------------------------------------------
_cmdr_loader_source_with_prefix() {
    local _prev_prefix="${_CMDR_LOADING_PREFIX:-}"
    _CMDR_LOADING_PREFIX="$1"
    # shellcheck source=/dev/null
    source "$2"
    _CMDR_LOADING_PREFIX="$_prev_prefix"
}

_cmdr_loader_auto_register() {
    local dir="$1"
    local module="$2"

    _cmdr_loader_register_impl_file "$dir" "$module"

    # Recurse into subdirectories that contain a main.sh.
    local sub subname submodule
    for sub in "${dir}"/*/; do
        [[ -d "$sub" ]] || continue
        [[ -f "${sub}main.sh" ]] || continue
        subname="$(basename "${sub%/}")"
        submodule="${module}::${subname}"

        # Source main.sh only if not already registered by an explicit
        # cmdr::register::module call in the parent's main.sh (which would
        # have sourced it already).
        if [[ -z "${_CMDR_MODULE_FILES[$submodule]+_}" ]]; then
            _cmdr_loader_source_with_prefix "$module" "${sub}main.sh"
        fi

        _cmdr_loader_auto_register "${sub%/}" "$submodule"
    done
}

# ---------------------------------------------------------------------------
# Source modules, hooks, rules, and scaffolds declared by installed Composer
# vendor packages. Each package opts in via extra.cmdr in its composer.json:
#
#   "extra": {
#       "cmdr": {
#           "modules":   { "<name>": "<path>" },
#           "hooks":     [ "<path-to-hooks.sh>" ],
#           "rules":     [ "<path-to-rules-dir-or-.sh>" ],
#           "scaffolds": [ "<path-to-scaffolds-dir>" ]
#       }
#   }
#
# Paths are relative to the package root. For modules, <path> may be a
# directory (auto-discovers main.sh) or an explicit .sh file. Vendor packages
# are loaded before the global/user/project search paths, so project modules
# always take precedence.
# ---------------------------------------------------------------------------
_cmdr_loader_vendor_module() {
    local _pkg_dir="$1" _name="$2" _path="$3"
    local _main_sh _impl_dir
    if [[ "$_path" == *.sh ]]; then
        _main_sh="${_pkg_dir}/${_path}"
        _impl_dir="$(dirname "$_main_sh")"
    else
        _main_sh="${_pkg_dir}/${_path}/main.sh"
        _impl_dir="${_pkg_dir}/${_path}"
    fi
    [[ -f "$_main_sh" ]] || return 0
    _cmdr_loader_source_with_prefix "$_name" "$_main_sh"
    _cmdr_loader_auto_register "$_impl_dir" "$_name"
}

_cmdr_loader_vendor_scaffold_dir() {
    local _base="$1"
    [[ -d "$_base" ]] || return 0
    local _sub_dir _sub_type
    for _sub_dir in "$_base"/*/; do
        [[ -d "$_sub_dir" ]] || continue
        _sub_type="$(basename "${_sub_dir%/}")"
        [[ -n "${_CMDR_MAKE_MODULE_DIRS[$_sub_type]+_}" ]] && continue
        _CMDR_MAKE_MODULE_DIRS["$_sub_type"]="${_sub_dir%/}"
        [[ -f "${_sub_dir}make.sh" ]] && \
            _CMDR_MODULE_FILES["make::${_sub_type}"]="${_sub_dir}make.sh"
        local _prev_make_origin="$_CMDR_MODULE_ORIGIN"
        _CMDR_MODULE_ORIGIN="global"
        cmdr::register::help make "$_sub_type" "Scaffold a new ${_sub_type}"
        cmdr::args::define "make::${_sub_type}" \
            "{name? : Name to scaffold}" \
            "{--global|-g : Scaffold into the user directory (~/.cmdr/)}"
        _CMDR_MODULE_ORIGIN="$_prev_make_origin"
    done
}

cmdr::loader::source_vendor_modules() {
    local root
    root="$(cmdr::loader::find_project_root)"
    [[ -d "${root}/vendor" ]] || return 0

    local prev_origin="${_CMDR_MODULE_ORIGIN:-global}"
    _CMDR_MODULE_ORIGIN="vendor"

    local pkg_json pkg_dir entry name path
    for pkg_json in "${root}/vendor"/*/*/composer.json; do
        [[ -f "$pkg_json" ]] || continue
        pkg_dir="${pkg_json%/composer.json}"

        # --- modules ---
        while IFS= read -r entry; do
            [[ -z "$entry" ]] && continue
            name="${entry%%:*}"; path="${entry#*:}"
            [[ -z "$name" || -z "$path" ]] && continue
            _cmdr_loader_vendor_module "$pkg_dir" "$name" "$path"
        done < <(cmdr::json::extract "$pkg_json" "extra.cmdr.modules")

        # --- hooks (sourced immediately so listeners register before cmdr.bootstrapped fires) ---
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            _cmdr_hook_source_file "${pkg_dir}/${path}"
        done < <(cmdr::json::extract "$pkg_json" "extra.cmdr.hooks")

        # --- rules (collected; sourced lazily by source_rules) ---
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            _CMDR_VENDOR_RULE_PATHS+=("${pkg_dir}/${path}")
        done < <(cmdr::json::extract "$pkg_json" "extra.cmdr.rules")

        # --- scaffolds ---
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            _cmdr_loader_vendor_scaffold_dir "${pkg_dir}/${path}"
        done < <(cmdr::json::extract "$pkg_json" "extra.cmdr.scaffolds")
    done

    _CMDR_MODULE_ORIGIN="$prev_origin"
}

# ---------------------------------------------------------------------------
# Source all rule files from all three search paths.
#
# Search order — later paths override earlier (project > user > vendor):
#   1. $_CMDR_SELF_DIR/../src/rules/   shipped rules
#   2. ~/.cmdr/rules/                  user-global rules
#   3. <project-root>/.cmdr/rules/     project-local rules
#
# Each .sh file in a rules/ directory is sourced. Files call
# Rule functions must be named cmdr::validator::rule::<name> — no registration needed.
# ---------------------------------------------------------------------------
cmdr::loader::source_rules() {
    local root
    root="$(cmdr::loader::find_project_root)"

    # Shipped rules first, then vendor (lowest → highest priority).
    local -a rule_paths=("$_CMDR_SELF_DIR/../src/rules")
    rule_paths+=("${_CMDR_VENDOR_RULE_PATHS[@]+"${_CMDR_VENDOR_RULE_PATHS[@]}"}")
    rule_paths+=("${HOME}/.cmdr/rules" "${root}/.cmdr/rules")

    local entry f
    for entry in "${rule_paths[@]}"; do
        [[ -z "$entry" ]] && continue
        if [[ -f "$entry" ]]; then
            # shellcheck source=/dev/null
            source "$entry"
        elif [[ -d "$entry" ]]; then
            for f in "$entry"/*.sh; do
                [[ -f "$f" ]] || continue
                # shellcheck source=/dev/null
                source "$f"
            done
        fi
    done
}

# ---------------------------------------------------------------------------
# Lazy module loader
#
# cmdr::loader::init_module <module>  — sources the registered implementation
#   file for each prefix segment. Safe to call multiple times; guarded by
#   _CMDR_MODULES_LOADED.
#
# cmdr::loader::init_all              — initialises every known module.
#   Used only for global help output and unknown-command fallback.
#
# cmdr::use <module>                  — public alias for init_module.
# ---------------------------------------------------------------------------
declare -A _CMDR_MODULES_LOADED=()
declare -a _CMDR_VENDOR_RULE_PATHS=()

cmdr::loader::init_module() {
    local module="$1"
    local prefix="" rest="$module" part
    while [[ -n "$rest" ]]; do
        if [[ "$rest" == *::* ]]; then
            part="${rest%%::*}"
            rest="${rest#*::}"
        else
            part="$rest"
            rest=""
        fi
        prefix="${prefix:+${prefix}::}${part}"

        [[ -n "${_CMDR_MODULES_LOADED[$prefix]+_}" ]] && continue
        _CMDR_MODULES_LOADED["$prefix"]=1

        if [[ -n "${_CMDR_MODULE_FILES[$prefix]+_}" ]]; then
            cmdr::use cmdr::make
            # shellcheck source=/dev/null
            source "${_CMDR_MODULE_FILES[$prefix]}"
        fi
    done
}

cmdr::loader::init_all() {
    local mod
    for mod in "${!_CMDR_MODULE_FILES[@]}"; do
        cmdr::loader::init_module "$mod"
    done
}

# cmdr::loader::source_hooks
# Sources every hooks.sh from all three search paths (root + one + two levels deep).
# Called lazily by cmdr::hook::run on first use; each file guarded by _CMDR_HOOK_FILES.
cmdr::loader::source_hooks() {
    local root
    root="$(cmdr::loader::find_project_root)"

    local -a search_paths=(
        "$_CMDR_SELF_DIR/../src/modules"
        "${HOME}/.cmdr"
        "${root}/.cmdr"
    )

    local dir
    for dir in "${search_paths[@]}"; do
        [[ -d "$dir" ]] || continue
        _cmdr_hook_source_file "${dir}/hooks.sh"
        for f in "$dir"/*/hooks.sh "$dir"/*/*/hooks.sh; do
            _cmdr_hook_source_file "$f"
        done
    done
}

_cmdr_hook_source_file() {
    local f="$1"
    [[ -f "$f" ]] || return 0
    [[ -n "${_CMDR_HOOK_FILES[$f]+_}" ]] && return 0
    _CMDR_HOOK_FILES["$f"]=1
    # shellcheck source=/dev/null
    source "$f"
}

cmdr::use() {
    local _caller_dir
    _caller_dir="$(dirname "${BASH_SOURCE[1]}")"

    # Relative-path form: any argument containing / is sourced relative to caller
    if [[ "$1" == */* ]]; then
        local _file="${_caller_dir}/${1}"
        [[ -f "$_file" ]] && source "$_file"
        return
    fi

    # Module loading (existing behaviour)
    cmdr::loader::init_module "$1"

    # Auto-load all .sh files from caller's rules/ dir when loading cmdr::validator
    if [[ "$1" == "cmdr::validator" && -d "${_caller_dir}/rules" ]]; then
        local _f
        for _f in "${_caller_dir}/rules/"*.sh; do
            # shellcheck source=/dev/null
            [[ -f "$_f" ]] && source "$_f"
        done
    fi
}
