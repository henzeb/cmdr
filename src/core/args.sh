# Declarative argument and option registration for cmdr commands.
#
# Use cmdr::args::define with Laravel-style {signature} blocks:
#
#   cmdr::args::define development::debug \
#       "{target=. : Path or name to debug}" \
#       "{--verbose : Enable verbose output}" \
#       "{--dry-run : Print commands without running}" \
#       "{--output= : Write output to this file}"
#
# Argument block syntax:
#   {name}             required positional
#   {name?}            optional positional
#   {name=default}     optional with default value
#   {name*}            variadic — consumes all remaining positionals
#
# Option block syntax:
#   {--flag}           boolean flag (present = 1, absent = "")
#   {--name=}          string option, value required
#   {--name=default}   string option with default
#
# Short alias syntax — append |-s (or |-s= / |-s=default) to any option block:
#   {--verbose|-v}     boolean flag with short alias -v
#   {--output|-o=}     string option with short alias -o
#   {--level|-l=1}     string option with default and short alias -l
#
# Append " : description" inside any block:
#   {target=. : Path or name to debug}
#   {--verbose : Enable verbose output}
#
# Inside command functions:
#   target=$(cmdr::args::get target)          # uses registered default
#   verbose=$(cmdr::args::get_option verbose) # "1" or ""
#   output=$(cmdr::args::get_option output)   # value, registered default, or ""
#   "${_CMDR_PASSTHROUGH[@]+"${_CMDR_PASSTHROUGH[@]}"}"

# ----- Registration storage -----
# Ordered "cmd|name" keys — position determines positional argument index.
declare -a _CMDR_ARG_KEYS=()
# "cmd|name" → "type|desc|default"   type: required | optional | variadic
declare -A _CMDR_ARG_META=()
# Ordered "cmd|name" keys for options.
declare -a _CMDR_OPT_KEYS=()
# "cmd|name" → "type|desc|default"   type: flag | string
declare -A _CMDR_OPT_META=()
# "cmd|s" → "longname"  (short-option alias lookup)
declare -A _CMDR_OPT_SHORT=()
# "cmd|longname" → "s"  (reverse short-option lookup, built at define time)
declare -A _CMDR_OPT_SHORT_REVERSE=()

# ----- Per-invocation parsed state -----
declare -A _CMDR_OPTS=()
declare -a _CMDR_ARGS=()
declare -a _CMDR_PASSTHROUGH=()
_CMDR_CURRENT_CMD=""

# ----- Global (cmdr-level) option state -----
declare -A _CMDR_GLOBAL_OPTS=()
declare -a _CMDR_REMAINING_ARGS=()

# ---------------------------------------------------------------------------
# cmdr::args::define <command> <block> [<block>...]
#
# Register arguments and options using Laravel-style {signature} blocks.
# ---------------------------------------------------------------------------
cmdr::args::define() {
    local cmd="$1"
    shift
    local block desc name type default key
    for block in "$@"; do
        block="${block#\{}"
        block="${block%\}}"

        desc=""
        if [[ "$block" == *" : "* ]]; then
            desc="${block#* : }"
            block="${block%% : *}"
        fi

        if [[ "$block" == --* ]]; then
            name="${block#--}"
            type="flag"
            default=""
            local shortcut=""
            # Parse optional short alias: --name|-s, --name|-s=, --name|-s=default
            if [[ "$name" == *"|"* ]]; then
                shortcut="${name#*|}"   # "-s", "-s=", or "-s=default"
                shortcut="${shortcut#-}"  # strip leading "-"
                shortcut="${shortcut%%=*}"  # strip "=" and anything after
                name="${name%%|*}"
            fi
            if [[ "$name" == *=* ]]; then
                type="string"
                default="${name#*=}"
                name="${name%%=*}"
            fi
            key="${cmd}|${name}"
            _CMDR_OPT_KEYS+=("$key")
            _CMDR_OPT_META["$key"]="${type}|${desc}|${default}"
            if [[ -n "$shortcut" ]]; then
                _CMDR_OPT_SHORT["${cmd}|${shortcut}"]="$name"
                _CMDR_OPT_SHORT_REVERSE["${cmd}|${name}"]="$shortcut"
            fi
        else
            name="$block"
            type="required"
            default=""
            if [[ "$name" == *"*" ]]; then
                name="${name%\*}"
                type="variadic"
            elif [[ "$name" == *"?" ]]; then
                name="${name%?}"
                type="optional"
            elif [[ "$name" == *=* ]]; then
                default="${name#*=}"
                name="${name%%=*}"
                type="optional"
            fi
            key="${cmd}|${name}"
            _CMDR_ARG_KEYS+=("$key")
            _CMDR_ARG_META["$key"]="${type}|${desc}|${default}"
        fi
    done
}

# ---------------------------------------------------------------------------
# _cmdr_args_define_global <block> [<block>...]
#
# Internal — called only from bin/cmdr to register cmdr-level options that
# are parsed before the module/command tokens.  Only options are supported
# (no positionals).  Uses the same {--name} / {--name=} / {--name=default}
# block syntax as cmdr::args::define.
#
# Example (in bin/cmdr only):
#   _cmdr_args_define_global \
#       "{--env=production : Application environment}" \
#       "{--dry-run : Print commands without executing}"
# ---------------------------------------------------------------------------
_cmdr_args_define_global() {
    cmdr::args::define "_cmdr::global" "$@"
}

# ---------------------------------------------------------------------------
# _cmdr_args_try_opt <cmd> <arg> <pending_var> <dest_map_var>
#
# Internal — tries to match and consume a single token as a known option for
# <cmd>.  Returns 0 if the token was consumed, 1 if it was not recognised.
# Handles all four option forms and the pending_opt flush.
#
# <pending_var>   — nameref to caller's pending_opt variable
# <dest_map_var>  — nameref to caller's destination associative array
# ---------------------------------------------------------------------------
_cmdr_args_try_opt() {
    local _cmd="$1" _arg="$2"
    local -n _pending_ref="$3"
    local -n _dest_ref="$4"

    if [[ -n "$_pending_ref" ]]; then
        _dest_ref["$_pending_ref"]="$_arg"
        _pending_ref=""
        return 0
    fi

    if [[ "$_arg" == "--" ]]; then
        return 1
    fi

    if [[ "$_arg" == --*=* ]]; then
        local _k="${_arg#--}"
        local _opt_name="${_k%%=*}"
        local _opt_key="${_cmd}|${_opt_name}"
        if [[ -n "${_CMDR_OPT_META[$_opt_key]+_}" ]]; then
            _dest_ref["$_opt_name"]="${_k#*=}"
            return 0
        fi
        return 1
    fi

    if [[ "$_arg" == --* ]]; then
        local _opt_name="${_arg#--}"
        local _opt_key="${_cmd}|${_opt_name}"
        if [[ -n "${_CMDR_OPT_META[$_opt_key]+_}" ]]; then
            if [[ "${_CMDR_OPT_META[$_opt_key]%%|*}" == "string" ]]; then
                _pending_ref="$_opt_name"
            else
                _dest_ref["$_opt_name"]=1
            fi
            return 0
        fi
        return 1
    fi

    if [[ "$_arg" == -[^-]* ]]; then
        local _sarg="${_arg#-}"
        if [[ "$_sarg" == *=* ]]; then
            local _s="${_sarg%%=*}" _sval="${_sarg#*=}"
            local _skey="${_cmd}|${_s}"
            if [[ -n "${_CMDR_OPT_SHORT[$_skey]+_}" ]]; then
                _dest_ref["${_CMDR_OPT_SHORT[$_skey]}"]="$_sval"
                return 0
            fi
            return 1
        else
            local _skey="${_cmd}|${_sarg}"
            if [[ -n "${_CMDR_OPT_SHORT[$_skey]+_}" ]]; then
                local _long_name="${_CMDR_OPT_SHORT[$_skey]}"
                local _opt_key="${_cmd}|${_long_name}"
                if [[ "${_CMDR_OPT_META[$_opt_key]%%|*}" == "string" ]]; then
                    _pending_ref="$_long_name"
                else
                    _dest_ref["$_long_name"]=1
                fi
                return 0
            fi
            return 1
        fi
    fi

    return 1
}

# ---------------------------------------------------------------------------
# _cmdr_args_parse_global [args...]
#
# Internal — called once in bin/cmdr after all modules are loaded.  Scans
# the front of argv for registered global options, strips them, and stores
# the remainder in _CMDR_REMAINING_ARGS.  Stops at the first unrecognised
# token (the module/command name) so it never steals flags from sub-commands.
#
# A bare "--" acts as an explicit end-of-globals separator; it is consumed
# and everything after it is passed through to the normal dispatcher.
#
# Results:
#   _CMDR_GLOBAL_OPTS    — associative array of parsed global option values
#   _CMDR_REMAINING_ARGS — indexed array of args left for normal dispatch
# ---------------------------------------------------------------------------
_cmdr_args_parse_global() {
    _CMDR_GLOBAL_OPTS=()
    _CMDR_REMAINING_ARGS=()

    local pending_opt=""
    while [[ $# -gt 0 ]]; do
        local arg="$1"
        if [[ "$arg" == "--" ]]; then
            shift
            break
        fi
        if _cmdr_args_try_opt "_cmdr::global" "$arg" pending_opt _CMDR_GLOBAL_OPTS; then
            shift
        else
            break
        fi
    done

    [[ -n "$pending_opt" ]] && _CMDR_GLOBAL_OPTS["$pending_opt"]=1

    _CMDR_REMAINING_ARGS=("$@")
}

# ---------------------------------------------------------------------------
# cmdr::args::get_global <name> [fallback-default]
#
# Return the value of a global option.
# Resolution order: parsed value → registered default → fallback-default → ""
# ---------------------------------------------------------------------------
cmdr::args::get_global() {
    local name="$1"
    local fallback="${2:-}"
    local key="_cmdr::global|${name}"
    local reg_default=""
    if [[ -n "${_CMDR_OPT_META[$key]+_}" ]]; then
        local meta="${_CMDR_OPT_META[$key]}"
        local rest="${meta#*|}"
        reg_default="${rest#*|}"
    fi
    echo "${_CMDR_GLOBAL_OPTS[$name]:-${reg_default:-$fallback}}"
}

# ---------------------------------------------------------------------------
# cmdr::args::parse <command> [args...]
#
# Called automatically by the dispatcher before invoking a command function.
# Populates _CMDR_OPTS, _CMDR_ARGS, and _CMDR_PASSTHROUGH.
#
# Syntax handled:
#   --flag              boolean flag  → _CMDR_OPTS[flag]=1
#   --key=value         inline value  → _CMDR_OPTS[key]=value
#   --key value         two-token (string options only) → _CMDR_OPTS[key]=value
#   --                  separator     → everything after goes to _CMDR_PASSTHROUGH
#   anything else       positional    → _CMDR_ARGS
#
# After parsing, if -- was not used and positionals exceed registered slots,
# all positionals are routed to _CMDR_PASSTHROUGH (allows omitting --).
# ---------------------------------------------------------------------------
cmdr::args::parse() {
    _CMDR_CURRENT_CMD="$1"
    shift
    _CMDR_OPTS=()
    _CMDR_ARGS=()
    _CMDR_PASSTHROUGH=()

    local after_sep=0 pending_opt=""
    for arg in "$@"; do
        if [[ "$after_sep" -eq 1 ]]; then
            _CMDR_PASSTHROUGH+=("$arg")
        elif [[ "$arg" == "--" ]]; then
            after_sep=1
        else
            if ! _cmdr_args_try_opt "$_CMDR_CURRENT_CMD" "$arg" pending_opt _CMDR_OPTS; then
                _CMDR_ARGS+=("$arg")
            fi
        fi
    done
    # Flush a dangling --opt with no value (treat as flag)
    [[ -n "$pending_opt" ]] && _CMDR_OPTS["$pending_opt"]=1

    # If -- was not used and positionals exceed registered slots, route all
    # positionals to passthrough so callers can omit -- before a command.
    if [[ "$after_sep" -eq 0 && ${#_CMDR_ARGS[@]} -gt 0 ]]; then
        local _slot_count=0 _k
        for _k in "${_CMDR_ARG_KEYS[@]}"; do
            [[ "${_k%%|*}" == "$_CMDR_CURRENT_CMD" ]] && _slot_count=$((_slot_count + 1))
        done
        if [[ ${#_CMDR_ARGS[@]} -gt $_slot_count ]]; then
            _CMDR_PASSTHROUGH=("${_CMDR_ARGS[@]}")
            _CMDR_ARGS=()
        fi
    fi

    # Validate required arguments
    local _idx=0 _k _meta _type _arg_name
    for _k in "${_CMDR_ARG_KEYS[@]}"; do
        [[ "${_k%%|*}" != "$_CMDR_CURRENT_CMD" ]] && continue
        _meta="${_CMDR_ARG_META[$_k]}"
        _type="${_meta%%|*}"
        _arg_name="${_k#*|}"
        if [[ "$_type" == "required" && -z "${_CMDR_ARGS[$_idx]+_}" ]]; then
            cmdr::output::error "Missing required argument: <${_arg_name}>"
            exit 1
        fi
        _idx=$((_idx + 1))
    done
}

# ---------------------------------------------------------------------------
# cmdr::args::get <name> [fallback-default]
#
# Return the value of a positional argument by its registered name.
# Resolution order: parsed value → registered default → fallback-default → ""
# For variadic arguments, returns all remaining values space-separated.
# ---------------------------------------------------------------------------
cmdr::args::get() {
    local name="$1"
    local fallback="${2:-}"
    local idx=0
    for key in "${_CMDR_ARG_KEYS[@]}"; do
        [[ "${key%%|*}" != "$_CMDR_CURRENT_CMD" ]] && continue
        if [[ "${key#*|}" == "$name" ]]; then
            local meta="${_CMDR_ARG_META[$key]}"
            local type="${meta%%|*}"
            local rest="${meta#*|}"
            local reg_default="${rest#*|}"
            if [[ "$type" == "variadic" ]]; then
                echo "${_CMDR_ARGS[*]:$idx}"
            else
                local val="${_CMDR_ARGS[$idx]:-}"
                echo "${val:-${reg_default:-$fallback}}"
            fi
            return 0
        fi
        idx=$((idx + 1))
    done
    echo "$fallback"
}

# ---------------------------------------------------------------------------
# cmdr::args::get_option <name> [fallback-default]
#
# Return the value of a named option.
#   --flag        → "1"
#   --key=value   → "value"
#   --key value   → "value"  (string options only)
#   not supplied  → registered default → fallback-default → ""
# ---------------------------------------------------------------------------
cmdr::args::get_option() {
    local name="$1"
    local fallback="${2:-}"
    local reg_default=""
    local key="${_CMDR_CURRENT_CMD}|${name}"
    if [[ -n "${_CMDR_OPT_META[$key]+_}" ]]; then
        local meta="${_CMDR_OPT_META[$key]}"
        local rest="${meta#*|}"
        reg_default="${rest#*|}"
    fi
    echo "${_CMDR_OPTS[$name]:-${reg_default:-$fallback}}"
}

# ---------------------------------------------------------------------------
# cmdr::args::expand [token...]
#
# Expands a token array respecting parent-context aliases.
# Writes result into the nameref array passed as first argument.
# ---------------------------------------------------------------------------
cmdr::args::expand() {
    local -n _out=$1
    shift
    local -a _in=("$@")
    local parent=""
    _out=()
    for token in "${_in[@]}"; do
        local expanded
        expanded="$(cmdr::register::expand_token "$token" "$parent")"
        _out+=("$expanded")
        [[ -n "$parent" ]] && parent="${parent}::${expanded}" || parent="$expanded"
    done
}
