# cmdr::validator::rule::shell_alias
#
# Validates that no alias named $1 already exists in the user's shell RC file.
# RC path detection is inlined because rule functions run in subshells and
# cannot call cmdr::use safely.
cmdr::validator::rule::shell_alias() {
    local name="$1"
    local shell="${SHELL##*/}"
    local rc
    case "$shell" in
        bash)
            if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
                rc="${HOME}/.bash_profile"
            else
                rc="${HOME}/.bashrc"
            fi
            ;;
        zsh) rc="${HOME}/.zshrc" ;;
        *)   return 0 ;;
    esac
    grep -q "^alias ${name}=" "$rc" 2>/dev/null \
        && cmdr::validator::fail "An alias named '${name}' already exists in ${rc}."
}
