# ---------------------------------------------------------------------------
# make::module — custom handler for cmdr make module
#
# Overrides the default handler registered in main.sh with extra prompts for
# lock and hide, then uses cmdr::make::copy for explicit file placement.
# ---------------------------------------------------------------------------
make::module() {
    cmdr::use cmdr::input
    cmdr::use cmdr::validator

    cmdr::validator::create _make_module_name "required|regex:^[a-z]+$"

    local name
    name=$(cmdr::args::get name)

    if [[ -z "$name" ]]; then
        cmdr::validator::validate _make_module_name \
            cmdr::input::text name "Module name:" "" "Lowercase letters only"
    else
        cmdr::validator::validate _make_module_name "$name" || \
            cmdr::output::fail "Invalid module name '${name}': use lowercase letters only."
    fi

    local locked=0 hidden=0

    if cmdr::input::confirm "Lock this module?" "n" "Prevent project and user overrides"; then
        locked=1
    fi

    if cmdr::input::confirm "Hide from global help?" "n" "Exclude from the root help listing"; then
        hidden=1
    fi

    local global_flag
    global_flag=$(cmdr::args::get_option global)

    local target_dir
    if [[ -n "$global_flag" ]]; then
        target_dir="${HOME}/.cmdr/${name}"
    else
        local _root
        _root="$(cmdr::loader::find_project_root)"
        local _cmdr_dir="${_root}/.cmdr"

        if [[ ! -d "$_cmdr_dir" ]]; then
            cmdr::output::info "No .cmdr/ directory found — running init..."
            cmdr::self::execute_or_fail config
        fi

        target_dir="${_cmdr_dir}/${name}"
    fi

    if [[ -d "$target_dir" ]]; then
        cmdr::output::fail "Module '${name}' already exists at ${target_dir}"
    fi

    local NAME="$name"
    local LOCK="" HIDE=""
    [[ "$locked" -eq 1 ]] && LOCK="cmdr::register::lock ${name}"
    [[ "$hidden" -eq 1 ]] && HIDE="cmdr::register::hide ${name}"

    mkdir -p "$target_dir"
    cmdr::make::copy module/main.sh "${target_dir}/main.sh"
    cmdr::make::copy module/module.sh "${target_dir}/${name}.sh"

    cmdr::output::info "Scaffolded module '${name}' at ${target_dir}"
}
