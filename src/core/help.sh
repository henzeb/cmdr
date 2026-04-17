# Help — display helpers for module/command help pages and argument listings.

# ---------------------------------------------------------------------------
# cmdr::help::display_name <module_key>
#
# Converts a snake_case module key to Title Case display name.
# e.g. laravel_tools → "Laravel Tools"
# ---------------------------------------------------------------------------
cmdr::help::display_name() {
    local input="$1"
    local words word result=""
    local _tmp="${input//::/ }"
    IFS=' ' read -ra words <<< "$_tmp"
    for word in "${words[@]}"; do
        result+="${word} "
    done
    echo "${result% }"
}

# ---------------------------------------------------------------------------
# _cmdr_help_global_options_section BOLD YELLOW GREEN GRAY RESET
#
# Prints the "Global options:" block. Called only when filter is empty.
# ---------------------------------------------------------------------------
_cmdr_help_global_options_section() {
    local BOLD="$1" YELLOW="$2" GREEN="$3" GRAY="$4" RESET="$5"

    local _gopt_keys=()
    local _gk
    for _gk in "${_CMDR_OPT_KEYS[@]}"; do
        [[ "${_gk%%|*}" == "_cmdr::global" ]] && _gopt_keys+=("$_gk")
    done
    [[ ${#_gopt_keys[@]} -eq 0 ]] && return

    local _gcol=10 _glabel _gw
    for _gk in "${_gopt_keys[@]}"; do
        _cmdr_help_opt_label_into _glabel "_cmdr::global" "${_gk#*|}"
        _gw=${#_glabel}
        [[ $_gw -gt $_gcol ]] && _gcol=$_gw
    done
    local _gcol_width=$(( _gcol + 2 ))

    printf "  %s%sGlobal options:%s\n\n" "$YELLOW" "$BOLD" "$RESET"
    for _gk in "${_gopt_keys[@]}"; do
        local _gname="${_gk#*|}"
        local _grest="${_CMDR_OPT_META[$_gk]#*|}"
        local _gdesc="${_grest%%|*}"
        local _gdefault="${_grest#*|}"
        _cmdr_help_opt_label_into _glabel "_cmdr::global" "$_gname"
        local _ghint=""
        [[ -n "$_gdefault" ]] && _ghint="${GRAY} (default: \"${_gdefault}\")${RESET}"
        printf "  %s%-${_gcol_width}s%s%s%s\n" "$GREEN" "$_glabel" "$RESET" "$_gdesc" "$_ghint"
    done
    echo ""
}

# ---------------------------------------------------------------------------
# _cmdr_help_build_reverse_lookups <rev_name> <mod_rev_name>
#
# Populates two associative arrays (by name) with reverse alias lookups from
# the global ALIASES map.
# ---------------------------------------------------------------------------
_cmdr_help_build_reverse_lookups() {
    local -n _rev_ref="$1"
    local -n _mod_rev_ref="$2"
    local key val par
    for key in "${!ALIASES[@]}"; do
        val="${ALIASES[$key]}"
        if [[ "$key" == *:* ]]; then
            par="${key%:*}"
            _mod_rev_ref["${par}::${val}"]="${key##*:}"
        else
            _rev_ref["$val"]="$key"
            _mod_rev_ref["$val"]="$key"
        fi
    done
}

# ---------------------------------------------------------------------------
# _cmdr_help_command_col_width <filter> <rev_name> <mod_rev_name> <out_name>
#
# Computes the column width needed to align command descriptions and writes the
# result (integer) into the variable named by <out_name>.
# ---------------------------------------------------------------------------
_cmdr_help_command_col_width() {
    local _filter="$1"
    local -n _rev_ref="$2"
    local -n _mod_rev_ref="$3"
    local -n _out_ref="$4"
    local max_width=10
    local entry em ec hint_str w
    for entry in "${HELP_ENTRIES[@]}"; do
        em="${entry%%|*}"
        local _rest="${entry#*|}"
        ec="${_rest%%|*}"
        [[ -n "$_filter" && "$em" != "$_filter" ]] && continue
        [[ -z "$_filter" && "$em" == *::* ]] && continue
        [[ -z "$_filter" && -n "$em" && -n "${HELP_MODULE_HIDDEN[$em]+_}" ]] && continue
        [[ -z "$_filter" && -z "$em" && -n "${HELP_MODULE_HIDDEN[$ec]+_}" ]] && continue
        hint_str=""
        if [[ -n "${_rev_ref[$ec]+_}" ]]; then
            hint_str=" (${_rev_ref[$ec]})"
        elif [[ -n "$em" && -n "${_mod_rev_ref["${em}::${ec}"]+_}" ]]; then
            hint_str=" (${_mod_rev_ref["${em}::${ec}"]})"
        fi
        w=$(( ${#ec} + ${#hint_str} ))
        [[ $w -gt $max_width ]] && max_width=$w
    done
    _out_ref=$(( max_width + 2 ))
}

# ---------------------------------------------------------------------------
# _cmdr_help_build_display_order <out_name>
#
# Populates the indexed array named by <out_name> with module keys in display
# order: general first, then global, vendor, user, project.
# ---------------------------------------------------------------------------
_cmdr_help_build_display_order() {
    local -n _out_ref="$1"
    local _grp_general=() _grp_global=() _grp_vendor=() _grp_user=() _grp_project=()
    local _seen_key_o _ok _ov
    for _seen_key_o in "${HELP_MODULE_ORDER[@]}"; do
        _ok="${_seen_key_o:-__root__}"
        _ov="${HELP_MODULE_ORIGIN[$_ok]:-global}"
        if [[ -z "$_seen_key_o" ]]; then
            _grp_general+=("$_seen_key_o")
        else
            case "$_ov" in
                global)  _grp_global+=("$_seen_key_o") ;;
                vendor)  _grp_vendor+=("$_seen_key_o") ;;
                user)    _grp_user+=("$_seen_key_o") ;;
                project) _grp_project+=("$_seen_key_o") ;;
                *)       _grp_global+=("$_seen_key_o") ;;
            esac
        fi
    done
    _out_ref=(
        "${_grp_general[@]+"${_grp_general[@]}"}"
        "${_grp_global[@]+"${_grp_global[@]}"}"
        "${_grp_vendor[@]+"${_grp_vendor[@]}"}"
        "${_grp_user[@]+"${_grp_user[@]}"}"
        "${_grp_project[@]+"${_grp_project[@]}"}"
    )
}

# ---------------------------------------------------------------------------
# _cmdr_help_print_module_commands <module> <col_width> <filter>
#                                  BOLD YELLOW GREEN GRAY RESET
#                                  <rev_name> <mod_rev_name>
#
# Prints each command row (and its inline args) that belongs to <module>.
# ---------------------------------------------------------------------------
_cmdr_help_print_module_commands() {
    local _module="$1" _col_width="$2" _filter="$3"
    local BOLD="$4" YELLOW="$5" GREEN="$6" GRAY="$7" RESET="$8"
    local -n _rev_ref="$9"
    local -n _mod_rev_ref="${10}"

    local entry em ec ed hint_str label padded
    for entry in "${HELP_ENTRIES[@]}"; do
        em="${entry%%|*}"
        local _rest="${entry#*|}"
        ec="${_rest%%|*}"
        ed="${_rest#*|}"
        [[ "$em" != "$_module" ]] && continue
        [[ -z "$_filter" && -z "$em" && -n "${HELP_MODULE_HIDDEN[$ec]+_}" ]] && continue

        hint_str=""
        if [[ -n "${_rev_ref[$ec]+_}" ]]; then
            hint_str=" (${_rev_ref[$ec]})"
        elif [[ -n "$_module" && -n "${_mod_rev_ref["${_module}::${ec}"]+_}" ]]; then
            hint_str=" (${_mod_rev_ref["${_module}::${ec}"]})"
        fi

        label="${ec}${hint_str}"
        padded="$(printf "%-${_col_width}s" "$label")"
        printf "  %s%s%s%s\n" "$GREEN" "$padded" "$RESET" "$ed"

        if declare -f cmdr::help::args_inline > /dev/null 2>&1; then
            local full_cmd="${_module:+${_module}::}${ec}"
            cmdr::help::args_inline "$full_cmd" "$_col_width" "$BOLD" "$YELLOW" "$GREEN" "$GRAY" "$RESET"
        fi
    done
}

# ---------------------------------------------------------------------------
# _cmdr_help_fallbacks <filter> <printed_name> <col_width>
#                      BOLD YELLOW GREEN GRAY RESET
#
# Handles the three fallback cases when no module matched the filter:
#   1. filter is "module::cmd" — print the single command description row.
#   2. filter is a root command — print its description row.
#   3. No args/opts registered either — emit an error.
# Sets <printed_name> to 1 in cases 1 and 2.
# ---------------------------------------------------------------------------
_cmdr_help_fallbacks() {
    local _filter="$1"
    local -n _printed_ref="$2"
    local _col_width="$3"
    local BOLD="$4" YELLOW="$5" GREEN="$6" GRAY="$7" RESET="$8"

    [[ -z "$_filter" ]] && return

    # Fallback 1: filter="module::cmd"
    if [[ "$_printed_ref" -eq 0 && "$_filter" == *::* ]]; then
        local _parent="${_filter%::*}"
        local _cmd="${_filter##*::}"
        local _entry _em _ec _ed _rest
        for _entry in "${HELP_ENTRIES[@]}"; do
            _em="${_entry%%|*}"
            _rest="${_entry#*|}"
            _ec="${_rest%%|*}"
            _ed="${_rest#*|}"
            if [[ "$_em" == "$_parent" && "$_ec" == "$_cmd" ]]; then
                printf "  %s%s%s  %s\n\n" "$GREEN" "$_ec" "$RESET" "$_ed"
                _printed_ref=1
                break
            fi
        done
    fi

    # Fallback 2: filter is a root command name (no "::")
    if [[ "$_printed_ref" -eq 0 && -n "${_CMDR_ROOT_COMMANDS[$_filter]+_}" ]]; then
        local _entry _em _ec _ed _rest
        for _entry in "${HELP_ENTRIES[@]}"; do
            _em="${_entry%%|*}"
            _rest="${_entry#*|}"
            _ec="${_rest%%|*}"
            _ed="${_rest#*|}"
            if [[ -z "$_em" && "$_ec" == "$_filter" ]]; then
                printf "  %s%s%s  %s\n\n" "$GREEN" "$_ec" "$RESET" "$_ed"
                _printed_ref=1
                break
            fi
        done
        _printed_ref=1
    fi

    # Fallback 3: nothing at all — error unless args/opts are registered
    if [[ "$_printed_ref" -eq 0 ]]; then
        local _k _has_cmd_detail=0
        if declare -f cmdr::help::args_detail > /dev/null 2>&1; then
            for _k in "${_CMDR_ARG_KEYS[@]}" "${_CMDR_OPT_KEYS[@]}"; do
                [[ "${_k%%|*}" == "$_filter" ]] && { _has_cmd_detail=1; break; }
            done
        fi
        [[ "$_has_cmd_detail" -eq 0 ]] && cmdr::output::error "No help registered for module: $_filter"
    fi
}

# ---------------------------------------------------------------------------
# cmdr::help::show [filter]
#
# Prints the full help page, or a module/command-scoped page when filter is set.
# ---------------------------------------------------------------------------
cmdr::help::show() {
    local filter="${1:-}"

    # ANSI colours — only when stdout is a real terminal
    local BOLD='' YELLOW='' GREEN='' GRAY='' RESET=''
    if [[ -t 1 ]]; then
        BOLD=$'\e[1m'
        YELLOW=$'\e[33m'
        GREEN=$'\e[32m'
        GRAY=$'\e[90m'
        RESET=$'\e[0m'
    fi

    echo ""

    printf "  %s%sUsage:%s\n" "$YELLOW" "$BOLD" "$RESET"
    if [[ -n "$filter" ]]; then
        local _synopsis=""
        declare -f cmdr::help::args_synopsis > /dev/null 2>&1 && _synopsis="$(cmdr::help::args_synopsis "$filter")"
        if [[ -n "$_synopsis" ]]; then
            printf "    cmdr %s %s\n" "${filter//_/ }" "$_synopsis"
        else
            printf "    cmdr %s <command> [arguments]\n" "${filter//_/ }"
        fi
    else
        local _has_globals=0
        for _gk in "${_CMDR_OPT_KEYS[@]}"; do
            [[ "${_gk%%|*}" == "_cmdr::global" ]] && { _has_globals=1; break; }
        done
        if [[ "$_has_globals" -eq 1 ]]; then
            printf "    cmdr [global options] <command> [arguments]\n"
        else
            printf "    cmdr <command> [arguments]\n"
        fi
    fi
    echo ""

    # Global options section — root help only
    if [[ -z "$filter" ]]; then
        _cmdr_help_global_options_section "$BOLD" "$YELLOW" "$GREEN" "$GRAY" "$RESET"
    fi

    # Build reverse lookups from the unified ALIASES map
    declare -A REVERSE=() MODULE_REVERSE=()
    _cmdr_help_build_reverse_lookups REVERSE MODULE_REVERSE

    # Pass 1 — compute the widest command+hint label for column alignment
    local col_width=0
    _cmdr_help_command_col_width "$filter" REVERSE MODULE_REVERSE col_width

    printf "  %s%sAvailable commands:%s\n" "$YELLOW" "$BOLD" "$RESET"
    echo ""

    # Build display order: general first, then built-in (global), then vendor,
    # user, and project — each non-global group gets a bracketed header.
    local -a _display_order=()
    _cmdr_help_build_display_order _display_order

    local printed=0
    local _last_group=""
    for module in "${_display_order[@]}"; do
        [[ -n "$filter" && "$module" != "$filter" ]] && continue
        # At root level, skip sub-modules (depth > 1 indicated by :: in name)
        [[ -z "$filter" && "$module" == *::* ]] && continue
        # At root level, skip hidden modules
        [[ -z "$filter" && -n "$module" && -n "${HELP_MODULE_HIDDEN[$module]+_}" ]] && continue

        # Print a bracketed header whenever we enter a non-global group.
        if [[ -z "$filter" ]]; then
            local _seen_key="${module:-__root__}"
            local _origin="${HELP_MODULE_ORIGIN[$_seen_key]:-global}"
            local _group="${_origin}"
            [[ -z "$module" ]] && _group="general"
            if [[ "$_group" != "$_last_group" ]]; then
                [[ -n "$_last_group" ]] && echo ""
                case "$_group" in
                    general|global) : ;;
                    project) printf " %s%s[current project]%s\n" "$YELLOW" "$BOLD" "$RESET" ;;
                    *)       printf " %s%s[%s]%s\n" "$YELLOW" "$BOLD" "$_group" "$RESET" ;;
                esac
                _last_group="$_group"
            fi
        fi

        if [[ -z "$module" ]]; then
            printf " %sgeneral%s\n" "$GRAY" "$RESET"
        else
            local mhint=""
            [[ -n "${MODULE_REVERSE[$module]+_}" ]] && mhint=" (${MODULE_REVERSE[$module]})"
            printf " %s%s%s%s\n" "$GRAY" "$(cmdr::help::display_name "$module")" "$mhint" "$RESET"
        fi

        _cmdr_help_print_module_commands \
            "$module" "$col_width" "$filter" \
            "$BOLD" "$YELLOW" "$GREEN" "$GRAY" "$RESET" \
            REVERSE MODULE_REVERSE

        printed=1
    done
    echo ""

    # Fallbacks for when no module matched the filter
    _cmdr_help_fallbacks \
        "$filter" printed "$col_width" \
        "$BOLD" "$YELLOW" "$GREEN" "$GRAY" "$RESET"

    # If a specific command is filtered, show its registered arguments and options.
    if [[ -n "$filter" ]] && declare -f cmdr::help::args_detail > /dev/null 2>&1; then
        cmdr::help::args_detail "$filter" "$col_width" "$BOLD" "$YELLOW" "$GREEN" "$GRAY" "$RESET"
    fi
}

# ---------------------------------------------------------------------------
# _cmdr_help_opt_short <cmd> <longname>
#
# Echoes the registered short alias (without leading "-") for an option, or
# nothing if no shortcut was declared.
# ---------------------------------------------------------------------------
_cmdr_help_opt_short() {
    echo "${_CMDR_OPT_SHORT_REVERSE["${1}|${2}"]:-}"
}

# ---------------------------------------------------------------------------
# _cmdr_help_opt_label_into <nameref> <cmd> <name>
#
# Writes the formatted option label into the variable named by <nameref>.
# Format: "[-s, ]--name" | "[-s, ]--name[=default]" | "[-s, ]--name=<value>"
# ---------------------------------------------------------------------------
_cmdr_help_opt_label_into() {
    local -n _label_out="$1"
    local _cmd="$2" _name="$3"
    local _key="${_cmd}|${_name}"
    local _meta="${_CMDR_OPT_META[$_key]}"
    local _type="${_meta%%|*}"
    local _rest="${_meta#*|}"
    local _default="${_rest#*|}"
    local _short="${_CMDR_OPT_SHORT_REVERSE["$_key"]:-}"
    local _prefix=""
    [[ -n "$_short" ]] && _prefix="-${_short}, "
    if [[ "$_type" == "flag" ]]; then
        _label_out="${_prefix}--${_name}"
    elif [[ -n "$_default" ]]; then
        _label_out="${_prefix}--${_name}[=${_default}]"
    else
        _label_out="${_prefix}--${_name}=<value>"
    fi
}

# ---------------------------------------------------------------------------
# cmdr::help::args_synopsis <command>
#
# Emits a compact usage string built from registered options and arguments,
# e.g. "[--verbose] [--output=<value>] <target> [-- ...]"
# ---------------------------------------------------------------------------
cmdr::help::args_synopsis() {
    local cmd="$1"
    local parts=()

    local key name meta type rest default short
    for key in "${_CMDR_OPT_KEYS[@]}"; do
        [[ "${key%%|*}" != "$cmd" ]] && continue
        name="${key#*|}"
        meta="${_CMDR_OPT_META[$key]}"
        type="${meta%%|*}"
        rest="${meta#*|}"
        default="${rest#*|}"
        short="${_CMDR_OPT_SHORT_REVERSE["${cmd}|${name}"]:-}"
        local _prefix=""
        [[ -n "$short" ]] && _prefix="-${short}|"
        if [[ "$type" == "flag" ]]; then
            parts+=("[${_prefix}--${name}]")
        elif [[ -n "$default" ]]; then
            parts+=("[${_prefix}--${name}[=${default}]]")
        else
            parts+=("[${_prefix}--${name}=<value>]")
        fi
    done

    for key in "${_CMDR_ARG_KEYS[@]}"; do
        [[ "${key%%|*}" != "$cmd" ]] && continue
        name="${key#*|}"
        meta="${_CMDR_ARG_META[$key]}"
        type="${meta%%|*}"
        case "$type" in
            required) parts+=("<${name}>") ;;
            optional) parts+=("[<${name}>]") ;;
            variadic) parts+=("[<${name}>...]") ;;
        esac
    done

    echo "${parts[*]+"${parts[*]}"}"
}

# ---------------------------------------------------------------------------
# cmdr::help::args_inline <command> <col_width> BOLD YELLOW GREEN GRAY RESET
#
# Prints args and options indented under a command row in a module listing.
# ---------------------------------------------------------------------------
cmdr::help::args_inline() {
    local cmd="$1" col_width="$2"
    local BOLD="$3" YELLOW="$4" GREEN="$5" GRAY="$6" RESET="$7"

    local key name meta type rest desc default label hint

    # Compute a local column width wide enough to fit all arg/option labels,
    # using col_width as a minimum so we stay consistent with the command listing.
    local local_col="$col_width"
    for key in "${_CMDR_ARG_KEYS[@]}"; do
        [[ "${key%%|*}" != "$cmd" ]] && continue
        name="${key#*|}"
        meta="${_CMDR_ARG_META[$key]}"
        type="${meta%%|*}"
        case "$type" in
            required) label="<${name}>" ;;
            optional) label="[<${name}>]" ;;
            variadic) label="[<${name}>...]" ;;
            *)        label="<${name}>" ;;
        esac
        local _w=$(( ${#label} + 2 ))
        [[ $_w -gt $local_col ]] && local_col=$_w
    done
    for key in "${_CMDR_OPT_KEYS[@]}"; do
        [[ "${key%%|*}" != "$cmd" ]] && continue
        _cmdr_help_opt_label_into label "$cmd" "${key#*|}"
        local _w=$(( ${#label} + 2 ))
        [[ $_w -gt $local_col ]] && local_col=$_w
    done

    for key in "${_CMDR_ARG_KEYS[@]}"; do
        [[ "${key%%|*}" != "$cmd" ]] && continue
        name="${key#*|}"
        meta="${_CMDR_ARG_META[$key]}"
        type="${meta%%|*}"
        rest="${meta#*|}"
        desc="${rest%%|*}"
        default="${rest#*|}"
        case "$type" in
            required) label="<${name}>" ;;
            optional) label="[<${name}>]" ;;
            variadic) label="[<${name}>...]" ;;
            *)        label="<${name}>" ;;
        esac
        hint=""
        [[ -n "$default" ]] && hint=" (default: \"${default}\")"
        printf "    %s%-${local_col}s%s%s%s%s%s\n" \
            "$GRAY" "$label" "$RESET" "$desc" "$GRAY" "$hint" "$RESET"
    done

    for key in "${_CMDR_OPT_KEYS[@]}"; do
        [[ "${key%%|*}" != "$cmd" ]] && continue
        name="${key#*|}"
        meta="${_CMDR_OPT_META[$key]}"
        rest="${meta#*|}"
        desc="${rest%%|*}"
        default="${rest#*|}"
        _cmdr_help_opt_label_into label "$cmd" "$name"
        hint=""
        [[ -n "$default" ]] && hint=" (default: \"${default}\")"
        printf "    %s%-${local_col}s%s%s%s%s%s\n" \
            "$GRAY" "$label" "$RESET" "$desc" "$GRAY" "$hint" "$RESET"
    done
}

# ---------------------------------------------------------------------------
# cmdr::help::args_detail <command> <col_width> BOLD YELLOW GREEN GRAY RESET
#
# Prints Arguments and Options sections for a command-level help page.
# ---------------------------------------------------------------------------
cmdr::help::args_detail() {
    local cmd="$1" col_width="$2"
    local BOLD="$3" YELLOW="$4" GREEN="$5" GRAY="$6" RESET="$7"

    local key name meta type rest desc default label hint

    local has_args=0
    for key in "${_CMDR_ARG_KEYS[@]}"; do
        [[ "${key%%|*}" == "$cmd" ]] && { has_args=1; break; }
    done
    if [[ "$has_args" -eq 1 ]]; then
        # Compute column width from argument labels
        local arg_col=10
        for key in "${_CMDR_ARG_KEYS[@]}"; do
            [[ "${key%%|*}" != "$cmd" ]] && continue
            name="${key#*|}"
            meta="${_CMDR_ARG_META[$key]}"
            type="${meta%%|*}"
            case "$type" in
                required) label="<${name}>" ;;
                optional) label="[<${name}>]" ;;
                variadic) label="[<${name}>...]" ;;
                *)        label="<${name}>" ;;
            esac
            local _w=${#label}
            [[ $_w -gt $arg_col ]] && arg_col=$_w
        done
        local arg_col_width=$(( arg_col + 2 ))
        printf "  %s%sArguments:%s\n\n" "$YELLOW" "$BOLD" "$RESET"
        for key in "${_CMDR_ARG_KEYS[@]}"; do
            [[ "${key%%|*}" != "$cmd" ]] && continue
            name="${key#*|}"
            meta="${_CMDR_ARG_META[$key]}"
            type="${meta%%|*}"
            rest="${meta#*|}"
            desc="${rest%%|*}"
            default="${rest#*|}"
            case "$type" in
                required) label="<${name}>" ;;
                optional) label="[<${name}>]" ;;
                variadic) label="[<${name}>...]" ;;
                *)        label="<${name}>" ;;
            esac
            hint=""
            [[ -n "$default" ]] && hint="${GRAY} (default: \"${default}\")${RESET}"
            printf "  %s%-${arg_col_width}s%s%s%s\n" "$GREEN" "$label" "$RESET" "$desc" "$hint"
        done
        echo ""
    fi

    local has_opts=0
    for key in "${_CMDR_OPT_KEYS[@]}"; do
        [[ "${key%%|*}" == "$cmd" ]] && { has_opts=1; break; }
    done
    if [[ "$has_opts" -eq 1 ]]; then
        local opt_col=10
        for key in "${_CMDR_OPT_KEYS[@]}"; do
            [[ "${key%%|*}" != "$cmd" ]] && continue
            _cmdr_help_opt_label_into label "$cmd" "${key#*|}"
            local _w=${#label}
            [[ $_w -gt $opt_col ]] && opt_col=$_w
        done
        local opt_col_width=$(( opt_col + 2 ))
        printf "  %s%sOptions:%s\n\n" "$YELLOW" "$BOLD" "$RESET"
        for key in "${_CMDR_OPT_KEYS[@]}"; do
            [[ "${key%%|*}" != "$cmd" ]] && continue
            name="${key#*|}"
            meta="${_CMDR_OPT_META[$key]}"
            rest="${meta#*|}"
            desc="${rest%%|*}"
            default="${rest#*|}"
            _cmdr_help_opt_label_into label "$cmd" "$name"
            hint=""
            [[ -n "$default" ]] && hint="${GRAY} (default: \"${default}\")${RESET}"
            printf "  %s%-${opt_col_width}s%s%s%s\n" "$GREEN" "$label" "$RESET" "$desc" "$hint"
        done
        echo ""
    fi
}
