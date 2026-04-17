# Progress bar — single-line, in-place, determinate.
#
# Public API:
#   cmdr::output::progressbar <label> <total>      — initialise and print the bar
#   cmdr::output::progressbar::advance [n] [label] — advance n steps (default 1), optional step label
#   cmdr::output::progressbar::clear               — erase the bar line and reset state

declare -g _CMDR_PB_TOTAL=0
declare -g _CMDR_PB_CURRENT=0
declare -g _CMDR_PB_LABEL=""
declare -g _CMDR_PB_ACTIVE=0

_cmdr_pb_tty() { [[ -t 1 ]]; }

_cmdr_pb_draw() {
    local step_label="${1:-}"

    local tw; tw=$(tput cols 2>/dev/null || echo 80)
    (( tw > 80 )) && tw=80

    local pct=0
    (( _CMDR_PB_TOTAL > 0 )) && pct=$(( _CMDR_PB_CURRENT * 100 / _CMDR_PB_TOTAL ))

    # Fixed-width fragments
    local tag_part="[${CMDR_TAG}]:  ${_CMDR_PB_LABEL}  "
    local pct_part="  ${pct}%  "

    # Right side: step label or current/total counter
    local right_part
    if [[ -n "$step_label" ]]; then
        right_part="$step_label"
    else
        right_part="(${_CMDR_PB_CURRENT}/${_CMDR_PB_TOTAL})"
    fi

    # Bar width = terminal width minus surrounding text, brackets, and right side
    local bar_w=$(( tw - ${#tag_part} - 2 - ${#pct_part} - ${#right_part} ))
    (( bar_w < 4 )) && bar_w=4

    # Truncate right_part if it overflows
    if (( ${#right_part} > tw - ${#tag_part} - 2 - ${#pct_part} - 4 )); then
        local max_r=$(( tw - ${#tag_part} - 2 - ${#pct_part} - 4 ))
        (( max_r < 0 )) && max_r=0
        right_part="${right_part:0:$max_r}"
    fi

    local filled=0
    (( _CMDR_PB_TOTAL > 0 )) && filled=$(( bar_w * _CMDR_PB_CURRENT / _CMDR_PB_TOTAL ))
    local empty=$(( bar_w - filled ))

    local bar=""
    local i
    for (( i = 0; i < filled; i++ )); do bar+='█'; done
    for (( i = 0; i < empty;  i++ )); do bar+='░'; done

    printf '\r\033[2K\033[0;32m%s\033[0m[%s]%s%s' \
        "$tag_part" "$bar" "$pct_part" "$right_part"
}

cmdr::output::progressbar() {
    local label="${1:-}" total="${2:-0}"
    _CMDR_PB_LABEL="$label"
    _CMDR_PB_TOTAL="$total"
    _CMDR_PB_CURRENT=0
    _CMDR_PB_ACTIVE=1
    _cmdr_pb_tty || return 0
    _cmdr_pb_draw
}

cmdr::output::progressbar::advance() {
    [[ "$_CMDR_PB_ACTIVE" -ne 1 ]] && return 0
    local n="${1:-1}" step_label="${2:-}"
    _CMDR_PB_CURRENT=$(( _CMDR_PB_CURRENT + n ))
    (( _CMDR_PB_CURRENT > _CMDR_PB_TOTAL )) && _CMDR_PB_CURRENT=$_CMDR_PB_TOTAL
    _cmdr_pb_tty || return 0
    _cmdr_pb_draw "$step_label"
}

cmdr::output::progressbar::clear() {
    [[ "$_CMDR_PB_ACTIVE" -ne 1 ]] && return 0
    _CMDR_PB_ACTIVE=0
    _CMDR_PB_CURRENT=0
    _CMDR_PB_TOTAL=0
    _CMDR_PB_LABEL=""
    _cmdr_pb_tty || return 0
    printf '\r\033[2K'
}
