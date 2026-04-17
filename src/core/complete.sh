# Completion engine — produces one candidate per line for shell tab-completion.
#
# Entry point:
#   cmdr::complete::query <cword> [word...]
#
# <cword>  1-based index of the word currently being completed, relative to
#          the words passed (i.e. COMP_CWORD for bash, CURRENT-1 for zsh).
# [word…]  All words typed after "cmdr", including the partial current word.
#
# The function writes candidates to stdout; the calling shell completion
# function is responsible for prefix-filtering (bash: compgen, zsh: compadd).

# ---------------------------------------------------------------------------
# _cmdr_complete_check_root_flag <cword> <words_ref>
#
# Detects the three --root flag forms and echoes the appropriate sentinel.
# Returns 0 and echoes a sentinel string if --root is being completed;
# returns 1 if no --root form was detected.
#
# Three forms handled:
#   cmdr --root /pa<TAB>      → prev word is "--root"
#   cmdr --root = /pa<TAB>    → bash splits on = (= in COMP_WORDBREAKS)
#   cmdr --root=/pa<TAB>      → zsh/fish keep it as one token
# ---------------------------------------------------------------------------
_cmdr_complete_check_root_flag() {
    local _cword="$1"; shift
    local _cur_word="${@:$_cword:1}"
    local _prev="" _prev2=""
    (( _cword >= 2 )) && _prev="${@:$(( _cword - 1 )):1}"
    (( _cword >= 3 )) && _prev2="${@:$(( _cword - 2 )):1}"
    if [[ "$_prev" == "--root" ]] || \
       [[ "$_prev2" == "--root" && "$_prev" == "=" ]]; then
        echo "__cmdr_complete_dir__"
        return 0
    fi
    if [[ "$_cur_word" == "--root="* ]]; then
        echo "__cmdr_complete_dir__:${_cur_word#--root=}"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# _cmdr_complete_build_prefix <cword> <words_ref> <prefix_ref> <has_help_ref>
#
# Builds a flag-excluded prefix array from the already-typed tokens (i.e. all
# tokens before the current partial word, with --* flags stripped out).
# Also sets <has_help_ref> to 1 if "--help" appears in those tokens.
# ---------------------------------------------------------------------------
_cmdr_complete_build_prefix() {
    local _cword="$1"
    local -n _bwords_ref="$2"
    local -n _prefix_ref="$3"
    local -n _has_help_ref="$4"
    local _prefix_len=$(( _cword - 1 ))
    local _i
    _prefix_ref=()
    _has_help_ref=0
    for (( _i = 0; _i < _prefix_len && _i < ${#_bwords_ref[@]}; _i++ )); do
        [[ "${_bwords_ref[$_i]}" == "--help" ]] && { _has_help_ref=1; continue; }
        [[ "${_bwords_ref[$_i]}" == --* ]] && continue
        [[ -z "${_bwords_ref[$_i]}" ]] && continue
        _prefix_ref+=("${_bwords_ref[$_i]}")
    done
}

# ---------------------------------------------------------------------------
# cmdr::complete::query <cword> [word...]
# ---------------------------------------------------------------------------
cmdr::complete::query() {
    local cword="${1:-1}"
    shift || true
    local -a words=("$@")

    # Check if --root flag is being completed; if so, delegate to the shell.
    local _root_sentinel
    if _root_sentinel="$(_cmdr_complete_check_root_flag "$cword" "${words[@]+"${words[@]}"}")"; then
        echo "$_root_sentinel"
        return 0
    fi

    # Build the flag-excluded prefix and detect --help.
    local -a prefix=()
    local _has_help=0
    _cmdr_complete_build_prefix "$cword" words prefix _has_help

    if [[ ${#prefix[@]} -eq 0 ]]; then
        cmdr::complete::_list_root
    else
        # Expand aliases in the prefix, build the module key.
        # Variable name must not clash with the `local expanded` inside
        # cmdr::args::expand, which would shadow our nameref target.
        local -a _prefix_expanded=()
        cmdr::args::expand _prefix_expanded "${prefix[@]}"

        # "help" as the first token is a meta-keyword (cmdr help <module>),
        # not a module name — strip it and use the remainder as the real path.
        local _start=0
        [[ "${_prefix_expanded[0]:-}" == "help" ]] && _start=1

        local _real_len=$(( ${#_prefix_expanded[@]} - _start ))

        # If --help is already present, or the last real token is "help", the
        # command is terminal — no further completions make sense.
        local _last_token="${_prefix_expanded[$(( ${#_prefix_expanded[@]} - 1 ))]}"
        if [[ "$_has_help" -eq 1 ]] || \
           [[ "$_start" -eq 0 && "$_last_token" == "help" ]]; then
            return 0
        fi

        if [[ "$_real_len" -eq 0 ]]; then
            # "cmdr help <TAB>" — offer root modules, but omit "help" itself
            cmdr::complete::_list_root suppress_help
        else
            local module_key="${_prefix_expanded[$_start]}"
            local i
            for (( i = _start + 1; i < ${#_prefix_expanded[@]}; i++ )); do
                module_key="${module_key}::${_prefix_expanded[$i]}"
            done
            cmdr::complete::_list_module "$module_key" "$_has_help"
        fi
    fi
}

# ---------------------------------------------------------------------------
# List completions for the first positional (root level).
# Outputs top-level module names and root commands only — no aliases.
# Pass "suppress_help" as first argument to omit "help" from the list
# (used when the user has already typed "cmdr help <TAB>").
# ---------------------------------------------------------------------------
cmdr::complete::_list_root() {
    local suppress_help="${1:-}"
    local -A _seen=()
    local entry em ec top_module

    for entry in "${HELP_ENTRIES[@]}"; do
        em="${entry%%|*}"
        local _rest="${entry#*|}"
        ec="${_rest%%|*}"

        if [[ -z "$em" ]]; then
            # Root-level command — skip if hidden
            [[ -n "${HELP_MODULE_HIDDEN[$ec]+_}" ]] && continue
            if [[ -z "${_seen[$ec]+_}" ]]; then
                echo "$ec"
                _seen["$ec"]=1
            fi
        else
            # Module — surface only the top-level segment
            top_module="${em%%::*}"
            if [[ -z "${_seen[$top_module]+_}" ]]; then
                echo "$top_module"
                _seen["$top_module"]=1
            fi
        fi
    done

    # Also emit root commands that were registered without a description
    # (not in HELP_ENTRIES) and are not hidden.
    local rc_name
    for rc_name in "${!_CMDR_ROOT_COMMANDS[@]}"; do
        [[ -n "${_seen[$rc_name]+_}" ]] && continue
        [[ -n "${HELP_MODULE_HIDDEN[$rc_name]+_}" ]] && continue
        echo "$rc_name"
        _seen["$rc_name"]=1
    done

    if [[ -z "$suppress_help" && -z "${_seen[help]+_}" ]]; then
        echo "help"
    fi
}

# ---------------------------------------------------------------------------
# List subcommands for a given module key (e.g. "docker", "laravel::tools").
# Outputs registered command names only — no aliases.
# ---------------------------------------------------------------------------
cmdr::complete::_list_module() {
    local module="$1"
    local has_help="${2:-0}"
    local -A _seen=()
    local entry em ec

    for entry in "${HELP_ENTRIES[@]}"; do
        em="${entry%%|*}"
        local _rest="${entry#*|}"
        ec="${_rest%%|*}"

        [[ "$em" != "$module" ]] && continue
        if [[ -z "${_seen[$ec]+_}" ]]; then
            echo "$ec"
            _seen["$ec"]=1
        fi
    done

    # Dynamic completer registered for this exact command path
    if [[ -n "${COMPLETERS[$module]+_}" ]]; then
        "${COMPLETERS[$module]}"
        return
    fi

    # For root commands, also offer registered --options (and -s shortcuts) as candidates.
    if [[ -n "${_CMDR_ROOT_COMMANDS[$module]+_}" ]]; then
        local _k _name
        for _k in "${_CMDR_OPT_KEYS[@]}"; do
            [[ "${_k%%|*}" != "$module" ]] && continue
            _name="${_k#*|}"
            echo "--${_name}"
        done
        for _k in "${!_CMDR_OPT_SHORT[@]}"; do
            [[ "${_k%%|*}" != "$module" ]] && continue
            echo "-${_k#*|}"
        done
    fi

    if [[ "$has_help" -eq 0 ]]; then echo "--help"; fi
}
