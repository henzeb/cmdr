# Command dispatch — routes parsed arguments to the correct module or command.

# ---------------------------------------------------------------------------
# Ensure the function for a registered root command is loaded.
# Usage: _cmdr_dispatch_load_root_fn <name>
# After calling, retrieve the fn via: fn="${_CMDR_ROOT_COMMANDS[$name]}"
# ---------------------------------------------------------------------------
_cmdr_dispatch_load_root_fn() {
    local _name="$1" _fn _rc_module
    _fn="${_CMDR_ROOT_COMMANDS[$_name]}"
    if ! declare -f "$_fn" > /dev/null 2>&1; then
        if [[ -n "${_CMDR_ROOT_COMMAND_FILES[$_name]+_}" ]]; then
            # shellcheck source=/dev/null
            source "${_CMDR_ROOT_COMMAND_FILES[$_name]}"
        else
            _rc_module="${_fn%%::*}"
            [[ "$_rc_module" != "$_fn" ]] && cmdr::loader::init_module "$_rc_module"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Handle --help flag dispatch.
# Usage: _cmdr_dispatch_help_flag <parts_nameref>
# <parts_nameref> is the name of an array of expanded tokens (--help excluded).
# ---------------------------------------------------------------------------
_cmdr_dispatch_help_flag() {
    local -n _parts_ref="$1"
    local MODULE _pi _parent fn

    if [[ ${#_parts_ref[@]} -eq 0 || ( ${#_parts_ref[@]} -eq 1 && "${_parts_ref[0]}" == "help" ) ]]; then
        cmdr::loader::init_all
        cmdr::help::show
        return
    fi

    MODULE="${_parts_ref[0]:-}"
    for (( _pi=1; _pi<${#_parts_ref[@]}; _pi++ )); do MODULE="${MODULE}::${_parts_ref[$_pi]}"; done
    cmdr::loader::init_module "$MODULE"

    # If MODULE is not a known module, check for a registered root command.
    if [[ ${#_parts_ref[@]} -eq 1 && -z "${HELP_MODULE_SEEN[$MODULE]+_}" ]]; then
        if [[ -n "${_CMDR_ROOT_COMMANDS[$MODULE]+_}" ]]; then
            _cmdr_dispatch_load_root_fn "$MODULE"
        fi
    fi

    # For multi-token paths (e.g. "docker up --help"), verify the resolved
    # command actually exists before showing help.
    if [[ ${#_parts_ref[@]} -gt 1 ]] && \
       [[ -z "${HELP_MODULE_SEEN[$MODULE]+_}" ]] && \
       ! declare -f "$MODULE" > /dev/null 2>&1; then
        cmdr::output::error "Unknown command: ${_parts_ref[*]}"
        _parent="${_parts_ref[0]}"
        cmdr::loader::init_module "$_parent"
        if [[ -n "${HELP_MODULE_SEEN[$_parent]+_}" ]]; then
            cmdr::help::show "$_parent"
        else
            cmdr::loader::init_all
            cmdr::help::show
        fi
        exit 1
    fi

    if [[ -n "${_CMDR_NATIVE_HELP[$MODULE]+_}" ]] && declare -f "$MODULE" > /dev/null 2>&1; then
        "$MODULE" --help
    else
        cmdr::help::show "$MODULE"
    fi
}

# ---------------------------------------------------------------------------
# Handle single-token dispatch.
# Usage: _cmdr_dispatch_single <expanded_cmd> <raw_token>
# ---------------------------------------------------------------------------
_cmdr_dispatch_single() {
    local CMD="$1" _raw="$2"
    local fn _rc_module

    # "help" on its own shows the global help page
    if [[ "$CMD" == "help" ]]; then
        cmdr::loader::init_all
        cmdr::help::show
        exit 0
    fi

    # If CMD names a registered module, init it and show its help
    cmdr::loader::init_module "$CMD"
    if [[ -n "${HELP_MODULE_SEEN[$CMD]+_}" ]]; then
        cmdr::help::show "$CMD"
        exit 0
    fi

    # Check registered root commands.
    if [[ -n "${_CMDR_ROOT_COMMANDS[$CMD]+_}" ]]; then
        _cmdr_dispatch_load_root_fn "$CMD"
        fn="${_CMDR_ROOT_COMMANDS[$CMD]}"
        cmdr::args::parse "$CMD"
        [[ -n "${_CMDR_OPTS[help]+_}" ]] && { cmdr::help::show "$CMD"; exit 0; }
        "$fn"
    else
        cmdr::output::error "Unknown command: $_raw"
        cmdr::help::show
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Handle multi-token dispatch.
# Usage: _cmdr_dispatch_multi <arg>...
# ---------------------------------------------------------------------------
_cmdr_dispatch_multi() {
    local -a ARGS=("$@")
    local N=${#ARGS[@]}
    local matched=0 i _k
    local -a EPARTS REMAINING
    local CANDIDATE MODULE fn _first

    # Expand all tokens once and precompute prefix strings upfront.
    # e.g. ["d", "a", "migrate"] → EPARTS=["docker","artisan","migrate"]
    #   CANDIDATES[0]="docker"  CANDIDATES[1]="docker::artisan"  CANDIDATES[2]="docker::artisan::migrate"
    EPARTS=()
    cmdr::args::expand EPARTS "${ARGS[@]}"
    MODULE="${EPARTS[0]}"

    local -a CANDIDATES=()
    local _c=""
    for (( _k=0; _k<N; _k++ )); do
        [[ -n "$_c" ]] && _c="${_c}::${EPARTS[$_k]}" || _c="${EPARTS[$_k]}"
        CANDIDATES+=("$_c")
    done

    # Try longest exact prefix match first (longest → shortest, min 2 tokens).
    # cmdr:: internal functions are excluded by an explicit guard.
    for (( i=N-1; i>=1; i-- )); do
        CANDIDATE="${CANDIDATES[$i]}"

        # Never dispatch into the cmdr:: internal namespace
        [[ "$CANDIDATE" == cmdr::* ]] && continue

        # Proceed if the function is already defined, or if the module has a
        # registered implementation file that may define it
        if declare -f "$CANDIDATE" > /dev/null 2>&1 || \
           [[ -n "${_CMDR_MODULE_FILES[$MODULE]+_}" ]]; then
            cmdr::loader::init_module "$CANDIDATE"
            if declare -f "$CANDIDATE" > /dev/null 2>&1; then
                REMAINING=("${ARGS[@]:$((i+1))}")
                cmdr::args::parse "$CANDIDATE" "${REMAINING[@]+"${REMAINING[@]}"}"
                if [[ -n "${_CMDR_OPTS[help]+_}" ]]; then
                    [[ -n "${_CMDR_NATIVE_HELP[$CANDIDATE]+_}" ]] \
                        && { "$CANDIDATE" "${REMAINING[@]+"${REMAINING[@]}"}"; exit $?; }
                    cmdr::help::show "$CANDIDATE"
                    exit 0
                fi
                "$CANDIDATE" "${REMAINING[@]+"${REMAINING[@]}"}"
                matched=1
                break
            fi
        fi
    done

    if [[ "$matched" -eq 0 ]]; then
        local MODULE_KEY="${CANDIDATES[$((N-1))]}"
        cmdr::loader::init_module "$MODULE_KEY"
        if [[ -n "${HELP_MODULE_SEEN[$MODULE_KEY]+_}" ]]; then
            cmdr::help::show "$MODULE_KEY"
            exit 0
        fi
        # Check if the first expanded token is a root command. If so, dispatch
        # it with all remaining tokens as its arguments. The multi-token loop
        # above already ruled out any subcommand interpretation.
        if [[ -n "${_CMDR_ROOT_COMMANDS[$MODULE]+_}" ]]; then
            _cmdr_dispatch_load_root_fn "$MODULE"
            fn="${_CMDR_ROOT_COMMANDS[$MODULE]}"
            REMAINING=("${ARGS[@]:1}")
            cmdr::args::parse "$MODULE" "${REMAINING[@]+"${REMAINING[@]}"}"
            [[ -n "${_CMDR_OPTS[help]+_}" ]] && { cmdr::help::show "$MODULE"; exit 0; }
            "$fn" "${REMAINING[@]+"${REMAINING[@]}"}"
            exit 0
        fi
        cmdr::output::error "Unknown command: ${ARGS[*]}"
        _first="${EPARTS[0]}"
        cmdr::loader::init_module "$_first"
        if [[ -n "${HELP_MODULE_SEEN[$_first]+_}" ]]; then
            cmdr::help::show "$_first"
        else
            cmdr::loader::init_all
            cmdr::help::show
        fi
        exit 1
    fi
}

cmdr::dispatch() {
    # ---------------------------------------------------------------------------
    # Shell completion query — called by generated completion scripts.
    # Usage: cmdr --_complete <cword> [word...]
    # Writes one candidate per line and exits; never reaches normal dispatch.
    # ---------------------------------------------------------------------------
    if [[ "${1:-}" == "--_complete" ]]; then
        shift
        cmdr::use cmdr::complete
        cmdr::complete::query "$@"
        exit 0
    fi

    # ---------------------------------------------------------------------------
    # Dispatch
    # ---------------------------------------------------------------------------
    if [[ $# -eq 0 ]]; then
        cmdr::loader::init_all
        cmdr::help::show
        exit 0
    fi

    local -a ARGS=("$@")
    local N=${#ARGS[@]}

    # --help flag anywhere: cmdr [<module>...] --help  (e.g. "cmdr docker --help")
    local _help_flag=0 _a
    for _a in "${ARGS[@]}"; do [[ "$_a" == "--help" ]] && { _help_flag=1; break; }; done
    if [[ "$_help_flag" -eq 1 ]]; then
        local -a PARTS=()
        for _a in "${ARGS[@]}"; do
            [[ "$_a" == "--help" ]] && continue
            PARTS+=("$(cmdr::register::expand_token "$_a")")
        done
        _cmdr_dispatch_help_flag PARTS
        exit 0
    fi

    # Module-scoped help: cmdr <module> help  (e.g. "cmdr docker help")
    if [[ "$N" -ge 2 ]] && [[ "$(cmdr::register::expand_token "${ARGS[$((N-1))]}")" == "help" ]]; then
        local -a PARTS=()
        local j _pi MODULE
        for (( j=0; j<N-1; j++ )); do PARTS+=("$(cmdr::register::expand_token "${ARGS[$j]}")"); done
        MODULE="${PARTS[0]:-}"
        for (( _pi=1; _pi<${#PARTS[@]}; _pi++ )); do MODULE="${MODULE}::${PARTS[$_pi]}"; done
        cmdr::loader::init_module "$MODULE"
        if [[ -n "${_CMDR_NATIVE_HELP[$MODULE]+_}" ]] && declare -f "$MODULE" > /dev/null 2>&1; then
            "$MODULE" --help
        else
            cmdr::help::show "$MODULE"
        fi
        exit 0
    fi

    if [[ "$N" -eq 1 ]]; then
        _cmdr_dispatch_single "$(cmdr::register::expand_token "${ARGS[0]}" "")" "${ARGS[0]}"
    else
        _cmdr_dispatch_multi "${ARGS[@]}"
    fi
}
