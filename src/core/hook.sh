_CMDR_HOOKS_LOADED=0

# cmdr::hook::run <hookname> [args...]
# Lazy-loads all hooks.sh files and inits each listener's module, then calls
# every listener registered for <hookname> in registration order.
cmdr::hook::run() {
    local hookname="$1"; shift
    if [[ "$_CMDR_HOOKS_LOADED" -eq 0 ]]; then
        _CMDR_HOOKS_LOADED=1
        cmdr::loader::source_hooks
    fi
    [[ -z "${_CMDR_HOOKS[$hookname]+_}" ]] && return 0
    local entry fn module_key
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        fn="${entry%%|*}"
        module_key="${entry#*|}"
        [[ -n "$module_key" ]] && cmdr::loader::init_module "$module_key"
        "$fn" "$@"
    done <<< "${_CMDR_HOOKS[$hookname]}"
}
