# Task list — multi-line, in-place, grouped task tracker.
#
# Public API:
#   cmdr::output::tasks::add        <group> <label> <desc>  — register task and redraw
#   cmdr::output::tasks::processing <group> <label>         — mark in-progress and redraw
#   cmdr::output::tasks::done       <group> <label>         — mark done and redraw
#   cmdr::output::tasks::failed     <group> <label>         — mark failed and redraw
#   cmdr::output::tasks::canceled   <group> <label>         — mark canceled and redraw
#   cmdr::output::tasks::tick                               — advance spinner frame and redraw
#   cmdr::output::tasks::clear                              — erase block and reset all state

declare -ga _CMDR_TL_GROUP_ORDER=()
declare -gA _CMDR_TL_COUNT=()
declare -gA _CMDR_TL_LABELS=()
declare -gA _CMDR_TL_DESCS=()
declare -gA _CMDR_TL_STATUS=()
declare -gA _CMDR_TL_START_TIME=()
declare -g  _CMDR_TL_ACTIVE=0
declare -g  _CMDR_TL_LINE_COUNT=0
declare -g  _CMDR_TL_SPINNER_FRAME=0
declare -ga _CMDR_TL_SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
declare -g  _CMDR_TL_PREV_TRAP=""

_cmdr_tl_tty() { [[ -t 1 ]]; }

_cmdr_tl_handle_interrupt() {
    local group i status
    local -A _processing=()

    for group in "${_CMDR_TL_GROUP_ORDER[@]}"; do
        _processing[$group]=$(_cmdr_tl_find_processing "$group")
        cmdr::hook::run "cmdr.task.${group}.cancel" "$group" "${_processing[$group]}"
    done

    for group in "${_CMDR_TL_GROUP_ORDER[@]}"; do
        local count="${_CMDR_TL_COUNT[$group]:-0}"
        for (( i = 0; i < count; i++ )); do
            status="${_CMDR_TL_STATUS["$group:$i"]}"
            [[ "$status" == processing ]] && _CMDR_TL_STATUS["$group:$i"]="failed"
            [[ "$status" == pending    ]] && _CMDR_TL_STATUS["$group:$i"]="canceled"
        done
    done

    _cmdr_tl_tty && _cmdr_tl_draw

    for group in "${_CMDR_TL_GROUP_ORDER[@]}"; do
        cmdr::hook::run "cmdr.task.${group}.canceled" "$group" "${_processing[$group]}"
    done

    _cmdr_tl_restore_trap
    kill -INT $$
}

_cmdr_tl_restore_trap() {
    if [[ -n "$_CMDR_TL_PREV_TRAP" ]]; then
        eval "$_CMDR_TL_PREV_TRAP"
    else
        trap - INT
    fi
}

_cmdr_tl_find_processing() {
    local group="$1"
    local count="${_CMDR_TL_COUNT[$group]:-0}"
    local i
    for (( i = 0; i < count; i++ )); do
        if [[ "${_CMDR_TL_STATUS["$group:$i"]}" == processing ]]; then
            printf '%s' "${_CMDR_TL_LABELS["$group:$i"]}"
            return 0
        fi
    done
}

_cmdr_tl_find_index() {
    local group="$1" label="$2"
    local count="${_CMDR_TL_COUNT[$group]:-0}"
    local i
    for (( i = 0; i < count; i++ )); do
        if [[ "${_CMDR_TL_LABELS["$group:$i"]}" == "$label" ]]; then
            printf '%d' "$i"
            return 0
        fi
    done
    return 1
}

_cmdr_tl_draw() {
    if (( _CMDR_TL_ACTIVE == 1 && _CMDR_TL_LINE_COUNT > 0 )); then
        printf '\033[%dA' "$_CMDR_TL_LINE_COUNT"
    fi

    local lines_drawn=0
    local frame=$(( _CMDR_TL_SPINNER_FRAME % ${#_CMDR_TL_SPINNER_FRAMES[@]} ))
    local group

    printf '\r\033[2K\n'
    lines_drawn=$(( lines_drawn + 1 ))

    for group in "${_CMDR_TL_GROUP_ORDER[@]}"; do
        printf '\r\033[2K\033[0;32m[%s]: \033[0m%s\n' "$CMDR_TAG" "$group"
        lines_drawn=$(( lines_drawn + 1 ))

        local count="${_CMDR_TL_COUNT[$group]:-0}"
        local max_lbl_len=0
        local i

        for (( i = 0; i < count; i++ )); do
            local lbl="${_CMDR_TL_LABELS["$group:$i"]}"
            (( ${#lbl} > max_lbl_len )) && max_lbl_len=${#lbl}
        done

        for (( i = 0; i < count; i++ )); do
            local label="${_CMDR_TL_LABELS["$group:$i"]}"
            local desc="${_CMDR_TL_DESCS["$group:$i"]}"
            local status="${_CMDR_TL_STATUS["$group:$i"]}"
            local symbol color elapsed_str=""

            case "$status" in
                processing)
                    symbol="${_CMDR_TL_SPINNER_FRAMES[$frame]}"
                    color='\033[0;36m'
                    local start="${_CMDR_TL_START_TIME["$group:$i"]:-$SECONDS}"
                    elapsed_str="  \033[2m$(( SECONDS - start ))s\033[0m"
                    ;;
                done)
                    symbol='✓'
                    color='\033[0;32m'
                    ;;
                failed)
                    symbol='✗'
                    color='\033[0;31m'
                    ;;
                canceled)
                    symbol='⊘'
                    color='\033[0;33m'
                    ;;
                *)
                    symbol='○'
                    color='\033[2m'
                    ;;
            esac

            printf "\r\033[2K  ${color}%s\033[0m  %-*s  %s${elapsed_str}\n" \
                "$symbol" "$max_lbl_len" "$label" "$desc"
            lines_drawn=$(( lines_drawn + 1 ))
        done
    done

    printf '\r\033[2K\n'
    lines_drawn=$(( lines_drawn + 1 ))

    _CMDR_TL_LINE_COUNT=$lines_drawn
    _CMDR_TL_ACTIVE=1
}

_cmdr_tl_set_status() {
    local group="$1" label="$2" status="$3"
    local idx
    idx=$(_cmdr_tl_find_index "$group" "$label") || return 0

    local _active_task=""
    [[ "$status" == canceled ]] && _active_task=$(_cmdr_tl_find_processing "$group")
    [[ "$status" == canceled ]] && cmdr::hook::run "cmdr.task.${group}.cancel" "$group" "$_active_task"

    _CMDR_TL_STATUS["$group:$idx"]="$status"
    [[ "$status" == processing ]] && _CMDR_TL_START_TIME["$group:$idx"]=$SECONDS

    _cmdr_tl_tty || { [[ "$status" == canceled ]] && cmdr::hook::run "cmdr.task.${group}.canceled" "$group" "$_active_task"; return 0; }
    _cmdr_tl_draw

    [[ "$status" == canceled ]] && cmdr::hook::run "cmdr.task.${group}.canceled" "$group" "$_active_task"
    return 0
}

cmdr::output::tasks::add() {
    local group="$1" label="$2" desc="$3"

    if [[ -z "${_CMDR_TL_COUNT[$group]+x}" ]]; then
        _CMDR_TL_GROUP_ORDER+=("$group")
        _CMDR_TL_COUNT[$group]=0
    fi

    local idx="${_CMDR_TL_COUNT[$group]}"
    _CMDR_TL_LABELS["$group:$idx"]="$label"
    _CMDR_TL_DESCS["$group:$idx"]="$desc"
    _CMDR_TL_STATUS["$group:$idx"]="pending"
    _CMDR_TL_COUNT[$group]=$(( idx + 1 ))

    if [[ "$_CMDR_TL_ACTIVE" -eq 0 ]]; then
        _CMDR_TL_PREV_TRAP=$(trap -p INT 2>/dev/null)
        trap '_cmdr_tl_handle_interrupt' INT
    fi

    _cmdr_tl_tty || return 0
    _cmdr_tl_draw
}

cmdr::output::tasks::processing() { _cmdr_tl_set_status "$1" "$2" processing; }
cmdr::output::tasks::done()       { _cmdr_tl_set_status "$1" "$2" done;       }
cmdr::output::tasks::failed()     { _cmdr_tl_set_status "$1" "$2" failed;     }
cmdr::output::tasks::canceled()   { _cmdr_tl_set_status "$1" "$2" canceled;   }

cmdr::output::tasks::tick() {
    [[ "$_CMDR_TL_ACTIVE" -ne 1 ]] && return 0
    _CMDR_TL_SPINNER_FRAME=$(( _CMDR_TL_SPINNER_FRAME + 1 ))
    _cmdr_tl_tty || return 0
    _cmdr_tl_draw
}

cmdr::output::tasks::clear() {
    if _cmdr_tl_tty && (( _CMDR_TL_ACTIVE == 1 && _CMDR_TL_LINE_COUNT > 0 )); then
        printf '\033[%dA' "$_CMDR_TL_LINE_COUNT"
        local i
        for (( i = 0; i < _CMDR_TL_LINE_COUNT; i++ )); do
            printf '\r\033[2K\n'
        done
        printf '\033[%dA' "$_CMDR_TL_LINE_COUNT"
    fi

    _cmdr_tl_restore_trap

    _CMDR_TL_GROUP_ORDER=()
    _CMDR_TL_COUNT=()
    _CMDR_TL_LABELS=()
    _CMDR_TL_DESCS=()
    _CMDR_TL_STATUS=()
    _CMDR_TL_START_TIME=()
    _CMDR_TL_PREV_TRAP=""
    _CMDR_TL_ACTIVE=0
    _CMDR_TL_LINE_COUNT=0
    _CMDR_TL_SPINNER_FRAME=0
}
