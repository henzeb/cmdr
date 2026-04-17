# -----------------------------------------------------------------------
# completion::bash
#
# Prints a bash completion script.  Source it or add to your bash RC file:
#   source <(cmdr completion bash)
# -----------------------------------------------------------------------
completion::bash() {
    cat <<'BASH'
# cmdr bash completion
# Add to ~/.bashrc (Linux/Git Bash) or ~/.bash_profile (macOS):
#   source <(cmdr completion bash)
_cmdr_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local cword="$COMP_CWORD"
    local -a _words=("${COMP_WORDS[@]:1}")

    COMPREPLY=()
    local _out
    _out=$(cmdr --_complete "$cword" "${_words[@]}" 2>/dev/null) || return 0

    # Directory path completion for --root (and future path flags)
    if [[ "$_out" == "__cmdr_complete_dir__"* ]]; then
        COMPREPLY=($(compgen -d -- "$cur"))
        compopt -o nospace -o filenames 2>/dev/null
        return 0
    fi

    mapfile -t COMPREPLY < <(compgen -W "$_out" -- "$cur")
}
complete -F _cmdr_completions cmdr
BASH
}

# -----------------------------------------------------------------------
# completion::zsh
#
# Prints a zsh completion script.  Source it or add to ~/.zshrc:
#   source <(cmdr completion zsh)
# -----------------------------------------------------------------------
completion::zsh() {
    cat <<'ZSH'
# cmdr zsh completion
# Add to ~/.zshrc:
#   source <(cmdr completion zsh)
_cmdr() {
    local cword=$(( CURRENT - 1 ))
    local _out
    _out=$(cmdr --_complete "$cword" "${words[@]:1}" 2>/dev/null)

    # Directory path completion for --root (and future path flags)
    if [[ "$_out" == "__cmdr_complete_dir__"* ]]; then
        _path_files -/
        return
    fi

    local -a _completions=()
    while IFS= read -r _line; do
        [[ -n "$_line" ]] && _completions+=("$_line")
    done <<< "$_out"
    compadd -a _completions
}
compdef _cmdr cmdr
ZSH
}

# -----------------------------------------------------------------------
# completion::fish
#
# Prints a fish completion script.  Save it or pipe to source:
#   cmdr completion fish | source
# -----------------------------------------------------------------------
completion::fish() {
    cat <<'FISH'
# cmdr fish completion
# Save to ~/.config/fish/completions/cmdr.fish, or run:
#   cmdr completion fish | source
function __cmdr_complete
    set -l tokens (commandline -opc)
    set -l cword (math (count $tokens) - 1)
    cmdr --_complete $cword $tokens[2..] 2>/dev/null
end
complete -c cmdr -f -a "(__cmdr_complete)"
# --root takes a directory path: use native file completion restricted to directories
complete -c cmdr -l root -r -F -a "(__fish_complete_directories)"
FISH
}

# -----------------------------------------------------------------------
# completion::install
#
# Detects the current shell and appends the appropriate source line to
# the shell RC file, or installs the fish completion file directly.
# -----------------------------------------------------------------------
completion::install() {
    local shell="${SHELL##*/}"
    case "$shell" in
        bash)
            # macOS Terminal opens login shells, which skip ~/.bashrc in favour of
            # ~/.bash_profile. Use ~/.bash_profile on Darwin, ~/.bashrc everywhere else.
            local rc
            if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
                rc="${HOME}/.bash_profile"
            else
                rc="${HOME}/.bashrc"
            fi
            if grep -q "cmdr completion bash" "$rc" 2>/dev/null; then
                cmdr::output::info "Bash completion already present in $rc"
            else
                printf '\n# cmdr completion\nsource <(cmdr completion bash)\n' >> "$rc"
                cmdr::output::info "Installed. Reload with: source $rc"
            fi
            ;;
        zsh)
            local rc="${HOME}/.zshrc"
            if grep -q "cmdr completion zsh" "$rc" 2>/dev/null; then
                cmdr::output::info "Zsh completion already present in $rc"
            else
                printf '\n# cmdr completion\nsource <(cmdr completion zsh)\n' >> "$rc"
                cmdr::output::info "Installed. Reload with: source $rc"
            fi
            ;;
        fish)
            local dir="${HOME}/.config/fish/completions"
            mkdir -p "$dir"
            completion::fish > "${dir}/cmdr.fish"
            cmdr::output::info "Installed to ${dir}/cmdr.fish"
            ;;
        *)
            cmdr::output::fail "Unsupported shell: $shell — run: cmdr completion bash|zsh|fish"
            ;;
    esac
}
