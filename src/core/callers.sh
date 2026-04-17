# Callers — self re-invocation and external-command resolution.

# ---------------------------------------------------------------------------
# Self re-invocation
# ---------------------------------------------------------------------------

# Execute cmdr with the given arguments, returning its exit code.
# Output and stdin are passed through; interactive prompts work as normal.
cmdr::self::execute() {
    "${_CMDR_SELF_DIR}/cmdr" "$@"
}

# Execute cmdr with the given arguments; exit with its exit code on failure.
cmdr::self::execute_or_fail() {
    cmdr::self::execute "$@" || exit $?
}

# ---------------------------------------------------------------------------
# cmdr::call — generic external-command resolver
# ---------------------------------------------------------------------------

# cmdr::call <name> <args>...
#
# Resolves the first available candidate registered for <name> via
# cmdr::register::call and runs it with <args>.
# Returns 127 if no candidate is found.
cmdr::call() {
    local name="$1"; shift
    local root candidate resolved
    root="$(cmdr::loader::find_project_root)"

    local candidates="${_CMDR_CALL_REGISTRY[$name]:-}"
    if [[ -z "$candidates" ]]; then
        if command -v "$name" &>/dev/null; then
            "$name" "$@"
            return $?
        fi
        cmdr::output::error "cmdr: no executable found for '${name}'"
        return 127
    fi

    local -a resolved_cmd=()
    while IFS= read -r candidate; do
        [[ -z "$candidate" ]] && continue
        if [[ "$candidate" == /* ]]; then
            # Absolute path
            if [[ -x "$candidate" ]]; then
                resolved_cmd=("$candidate"); break
            fi
        elif [[ "$candidate" == */* ]]; then
            # Relative path — resolve against project root
            resolved="${root}/${candidate}"
            if [[ -x "$resolved" ]]; then
                resolved_cmd=("$resolved"); break
            fi
        elif [[ "$candidate" == *' '* ]]; then
            # Multi-word command (e.g. "docker compose")
            local parts=($candidate)
            if command -v "${parts[0]}" &>/dev/null; then
                resolved_cmd=("${parts[@]}"); break
            fi
        else
            # Bare name — search PATH
            if command -v "$candidate" &>/dev/null; then
                resolved_cmd=("$candidate"); break
            fi
        fi
    done <<< "$candidates"

    if [[ ${#resolved_cmd[@]} -gt 0 ]]; then
        "${resolved_cmd[@]}" "$@"
        return $?
    fi

    cmdr::output::error "cmdr: no executable found for '${name}'"
    return 127
}
