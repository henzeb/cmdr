# Shell RC helpers — detect the user's shell config file and write lines to it.
#
# Public API:
#   cmdr::shell::write <line> [already-present-msg]
#   cmdr::shell::remove_line <pattern>
#   cmdr::shell::line_exists <string>
#   cmdr::shell::command_exists <cmd>
#
# Private:
#   _cmdr_shell_rc_file   — echoes the RC file path for the current shell

# Echoes the path to the user's shell RC file. Empty string for unsupported shells.
_cmdr_shell_rc_file() {
    local shell="${SHELL##*/}"
    case "$shell" in
        bash)
            if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
                printf '%s' "${HOME}/.bash_profile"
            else
                printf '%s' "${HOME}/.bashrc"
            fi
            ;;
        zsh)  printf '%s' "${HOME}/.zshrc" ;;
        fish) printf '%s' "${HOME}/.config/fish/completions/cmdr.fish" ;;
        *)    ;;
    esac
}

# cmdr::shell::write <line> <already-present-msg>
#
# Appends <line> to the user's shell RC file if it is not already present.
# Uses <already-present-msg> as the info message when the line is found.
# Fails (via cmdr::output::fail) if the shell is not supported.
cmdr::shell::write() {
    local line="${1:?cmdr::shell::write requires a line}"
    local already_msg="${2:-}"

    local rc
    rc=$(_cmdr_shell_rc_file)

    if [[ -z "$rc" ]]; then
        cmdr::output::fail "Unsupported shell: ${SHELL##*/}"
        return 1
    fi

    if cmdr::shell::line_exists "$line"; then
        [[ -n "$already_msg" ]] && cmdr::output::info "$already_msg"
        return 0
    fi

    printf '\n%s\n' "$line" >> "$rc"
    cmdr::output::info "Installed. Reload with: source ${rc}"
}

# cmdr::shell::remove_line <pattern>
#
# Removes all lines from the RC file that contain <pattern> (fixed string).
# Fails if the shell is not supported. No-ops if no matching lines exist.
cmdr::shell::remove_line() {
    local pattern="${1:?cmdr::shell::remove_line requires a pattern}"

    local rc
    rc=$(_cmdr_shell_rc_file)

    if [[ -z "$rc" ]]; then
        cmdr::output::fail "Unsupported shell: ${SHELL##*/}"
        return 1
    fi

    if ! cmdr::shell::line_exists "$pattern"; then
        return 0
    fi

    local tmp
    tmp=$(mktemp)
    grep -vF "$pattern" "$rc" > "$tmp" || true
    mv "$tmp" "$rc"
}

# Returns 0 if <line> is already present in the RC file, 1 otherwise.
cmdr::shell::line_exists() {
    local line="$1"
    local rc
    rc=$(_cmdr_shell_rc_file)
    grep -qF "$line" "$rc" 2>/dev/null
}

# Returns 0 if <cmd> is callable in the current environment, 1 otherwise.
cmdr::shell::command_exists() {
    local cmd="$1"
    command -v "$cmd" > /dev/null 2>&1
}
