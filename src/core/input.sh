# Input helpers — styled prompts inspired by Laravel Prompts.
#
# Public API:
#   cmdr::input::confirm     <prompt> [default=n]         → 0=yes / 1=no
#   cmdr::input::pause       [message]                    → waits for any key
#   cmdr::input::text        <varname> <prompt> [default]
#   cmdr::input::select      <varname> <prompt> <opt>...
#   cmdr::input::password     <varname> <prompt> [description]
#   cmdr::input::multiselect <varname> <prompt> <opt>...  → comma-separated result

# Shared with validator.sh; declared here so input works without validator loaded.
declare -ga _CMDR_INPUT_ERRORS=()

readonly _CMDR_INPUT_MIN_W=60

# Set by cmdr::validator::validate before calling an input function so that
# cmdr::input::text can revalidate live on every keystroke after the first submit.
declare -g _CMDR_INPUT_RULES=""
declare -g _CMDR_INPUT_PREFILL=""

# ─────────────────────────────────────────────────────────────────────────────
# Private helpers
# ─────────────────────────────────────────────────────────────────────────────

# Box width driven by topbar label text, with a content-minimum floor.
# W = label+hint+8  (gives 3 decorative dashes in the topbar), floored by
# min_w, capped at terminal width (never wider than 80).
# $1=label  $2=hint  $3=min_w
_cmdr_input_auto_w() {
    local label="${1:-}" hint="${2:-}" min_w="${3:-0}"
    local tw; tw=$(tput cols 2>/dev/null || echo 80)
    (( tw > 80 )) && tw=80
    local w=$(( ${#label} + ${#hint} + 8 ))
    (( w < min_w )) && w=$min_w
    (( w > tw ))    && w=$tw
    printf '%s' "$w"
}

# Repeat '─' N times
_cmdr_input_dashes() {
    local n="$1"
    (( n < 1 )) && return
    printf '─%.0s' $(seq 1 "$n")
}

# Move the cursor up N lines and erase each; cursor ends at col 0 of the
# highest erased line — ready for the next print to overwrite.
_cmdr_input_erase() {
    local n="${1:-1}" i
    for (( i = 0; i < n; i++ )); do
        printf '\033[A\033[2K'
    done
}

# Redraw the full text-input box in place.
# Cursor must be on the input row before calling.  Reads prompt, hint, description,
# W, BORDER, BOLD, GRAY, RED, RESET, _errors, _n_errors, buffer, cursor_pos,
# content_w from dynamic scope (caller's locals).
_cmdr_input_text_redraw() {
    local _vs=0
    if (( cursor_pos >= content_w )); then
        _vs=$(( cursor_pos - content_w + 1 ))
    fi
    local _view="${buffer:$_vs:$content_w}"
    local _pad=$(( content_w - ${#_view} ))
    (( _pad < 0 )) && _pad=0

    local _up=1; [[ -n "$description" ]] && _up=2
    printf '\r\033[%dA\033[J' "$_up"
    _cmdr_input_top "$prompt" "$W" "$BORDER" "$BOLD" "$RESET" "$hint"
    _cmdr_input_desc "$description" "$W" "$BORDER" "$GRAY" "$RESET"
    printf "${BORDER} │ ${GRAY}›${RESET} %s%*s${BORDER} │${RESET}\n" "$_view" "$_pad" ""
    local _e
    for _e in "${_errors[@]}"; do
        local _p=$(( W - 7 - ${#_e} ))
        (( _p < 0 )) && _p=0
        printf "${BORDER} │ ${RED}✖ %s${RESET}%*s${BORDER} │${RESET}\n" "$_e" "$_p" ""
    done
    _cmdr_input_bot "$W" "$BORDER" "$RESET"
    printf '\033[%dA\033[%dG' "$(( 2 + _n_errors ))" "$(( 6 + cursor_pos - _vs ))"
}

# Reserve N lines of space below the cursor so a box never gets clipped at
# the bottom of the terminal.  Prints N newlines (scrolling if needed), then
# moves the cursor back up N lines — net position is unchanged but the
# terminal has made room.
_cmdr_input_reserve() {
    local n="$1"
    local i
    for (( i = 0; i < n; i++ )); do printf '\n'; done
    printf '\033[%dA' "$n"
}

# Read one keypress, capturing multi-byte escape sequences (arrow keys).
# Prints the raw sequence to stdout so callers can capture it.
_cmdr_input_read_key() {
    local key seq extra
    IFS= read -r -s -n1 key </dev/tty
    if [[ "$key" == $'\033' ]]; then
        IFS= read -r -s -n2 -t 0.05 seq </dev/tty
        key="${key}${seq}"
        # Extended sequences like \033[3~ (Delete), \033[1~ (Home), \033[4~ (End)
        if [[ "$key" =~ $'\033'\[[0-9]$ ]]; then
            IFS= read -r -s -n1 -t 0.05 extra </dev/tty
            key="${key}${extra}"
        fi
    fi
    printf '%s' "$key"
}

# Print the top border:  " ┌ <label> <dashes>┐"
# $1 = label  $2 = W  $3 = CYAN  $4 = BOLD  $5 = RESET  [optional $6 = GRAY hint suffix]
_cmdr_input_top() {
    local label="$1" W="$2" CYAN="$3" BOLD="$4" RESET="$5" hint="${6:-}"
    local label_plain="${label}${hint}"          # visible length (no ANSI)
    local d=$(( W - 5 - ${#label_plain} ))
    (( d < 1 )) && d=1
    local dashes; dashes=$(_cmdr_input_dashes "$d")
    if [[ -n "$hint" ]]; then
        local GRAY=$'\033[90m'
        printf "${CYAN} ┌ ${RESET}${BOLD}%s${RESET}${GRAY}%s${RESET} ${CYAN}%s┐${RESET}\n" \
            "$label" "$hint" "$dashes"
    else
        printf "${CYAN} ┌ ${RESET}${BOLD}%s ${RESET}${CYAN}%s┐${RESET}\n" \
            "$label" "$dashes"
    fi
}

# Print the bottom border with an optional hint embedded in it:
#   plain:  " └<dashes>┘"
#   hinted: " └─ <hint> <dashes>┘"
# $1 = W  $2 = CYAN  $3 = RESET  [$4 = hint text  $5 = GRAY]
_cmdr_input_bot() {
    local W="$1" CYAN="$2" RESET="$3" hint="${4:-}" GRAY="${5:-}"
    if [[ -n "$hint" ]]; then
        local d=$(( W - 6 - ${#hint} ))
        (( d < 1 )) && d=1
        local dashes; dashes=$(_cmdr_input_dashes "$d")
        printf "${CYAN} └─ ${RESET}${GRAY}%s${RESET}${CYAN} %s┘${RESET}\n" "$hint" "$dashes"
    else
        local dashes; dashes=$(_cmdr_input_dashes $(( W - 3 )))
        printf "${CYAN} └%s┘${RESET}\n" "$dashes"
    fi
}

# Print a description row inside a box — gray text, padded to box width.
# No-op when description is empty.  $1=desc $2=W $3=CYAN $4=GRAY $5=RESET
_cmdr_input_desc() {
    local desc="$1" W="$2" CYAN="$3" GRAY="$4" RESET="$5"
    [[ -z "$desc" ]] && return 0
    local pad=$(( W - 5 - ${#desc} ))
    (( pad < 0 )) && pad=0
    printf "${CYAN} │ ${RESET}${GRAY}%s${RESET}%*s${CYAN} │${RESET}\n" "$desc" "$pad" ""
}

# ─────────────────────────────────────────────────────────────────────────────
# cmdr::input::confirm <prompt> [default=n] [description]
#
# Renders a framed yes/no prompt. Navigate with ←/→ (or ↑/↓), confirm with
# Enter. y/n are accepted as shortcuts. Collapses to a one-line ✔ summary.
#
#   cmdr::input::confirm "Delete container?" && docker rm "$id"
#   cmdr::input::confirm "Overwrite file?"  y || return 0
#   cmdr::input::confirm "Overwrite file?"  n "This cannot be undone"
# ─────────────────────────────────────────────────────────────────────────────
cmdr::input::confirm() {
    local prompt="${1:-Are you sure?}"
    local default="${2:-n}"
    local description="${3:-}"

    # Read any validation errors set by cmdr::validator::validate
    local _errors=() _n_errors=0
    if [[ ${#_CMDR_INPUT_ERRORS[@]} -gt 0 ]]; then
        _errors=("${_CMDR_INPUT_ERRORS[@]}")
        _n_errors="${#_errors[@]}"
    fi

    local CYAN=$'\033[36m' BOLD=$'\033[1m' GREEN=$'\033[32m'
    local GRAY=$'\033[90m' RED=$'\033[31m' RESET=$'\033[0m'

    local BORDER="${CYAN}"
    if (( _n_errors > 0 )); then BORDER="${RED}"; fi

    local _nav_hint="←→ navigate  ·  enter to confirm"
    local _min_w=$_CMDR_INPUT_MIN_W
    (( ${#_nav_hint} + 7 > _min_w )) && _min_w=$(( ${#_nav_hint} + 7 ))
    local _err
    for _err in "${_errors[@]}"; do
        (( ${#_err} + 7 > _min_w )) && _min_w=$(( ${#_err} + 7 ))
    done
    local W; W=$(_cmdr_input_auto_w "$prompt" "$description" $_min_w)

    # cursor: 0=Yes  1=No
    local cursor=1
    [[ "${default,,}" == "y" ]] && cursor=0

    local box_lines=$(( 3 + _n_errors ))
    [[ -n "$description" ]] && (( box_lines++ ))

    if (( _n_errors == 0 )); then printf '\n'; fi
    _cmdr_input_reserve "$box_lines"
    trap '_cmdr_input_erase "$box_lines"; printf " \033[31m✘\033[0m \033[2m\033[9m%s\033[0m\n" "$prompt"; trap - INT; kill -INT $$' INT
    while true; do
        _cmdr_input_top "$prompt" "$W" "$BORDER" "$BOLD" "$RESET"
        _cmdr_input_desc "$description" "$W" "$BORDER" "$GRAY" "$RESET"
        if (( cursor == 0 )); then
            printf "${BORDER} │ ${RESET}  ${BOLD}● Yes${RESET}  ${GRAY}○ No${RESET}%*s${BORDER} │${RESET}\n" $(( W - 18 )) ""
        else
            printf "${BORDER} │ ${RESET}  ${GRAY}○ Yes  ${RESET}${BOLD}● No${RESET}%*s${BORDER} │${RESET}\n" $(( W - 18 )) ""
        fi

        # Error rows
        local _err
        for _err in "${_errors[@]}"; do
            local _pad=$(( W - 7 - ${#_err} ))
            (( _pad < 0 )) && _pad=0
            printf "${BORDER} │ ${RED}✖ %s${RESET}%*s${BORDER} │${RESET}\n" "$_err" "$_pad" ""
        done

        _cmdr_input_bot "$W" "$BORDER" "$RESET" "$_nav_hint" "$GRAY"

        local key; key=$(_cmdr_input_read_key)
        case "$key" in
            $'\033[D'|$'\033[A') cursor=0 ;;   # ← or ↑ → Yes
            $'\033[C'|$'\033[B') cursor=1 ;;   # → or ↓ → No
            y|Y) cursor=0; _cmdr_input_erase "$box_lines"; break ;;
            n|N) cursor=1; _cmdr_input_erase "$box_lines"; break ;;
            $'\033')  # ESC — cancel
                _cmdr_input_erase "$box_lines"
                printf " \033[31m✘\033[0m \033[2m\033[9m%s\033[0m\n\n" "$prompt"
                trap - INT; kill -INT $$ ;;
            $'\n'|'') _cmdr_input_erase "$box_lines"; break ;;
        esac
        _cmdr_input_erase "$box_lines"
    done
    trap - INT

    local result; (( cursor == 0 )) && result="Yes" || result="No"
    printf "${GREEN} ✔ ${RESET}${BOLD}%s${RESET}  ${GRAY}%s${RESET}\n\n" "$prompt" "$result"
    (( cursor == 0 ))
}

# ─────────────────────────────────────────────────────────────────────────────
# cmdr::input::pause [message] [description] [seconds]
#
# Shows a framed message and waits for any key; the box vanishes afterward.
# With <seconds>, counts down and continues automatically; any key skips early.
# Time display: seconds below 60 shown as "42s", above as "1:01".
# If <description> is a plain integer it is treated as <seconds> directly.
#
#   cmdr::input::pause
#   cmdr::input::pause "Review the output above, then press any key."
#   cmdr::input::pause "Continuing in..." 10
#   cmdr::input::pause "Continuing in..." "Deployment starts after this" 10
# ─────────────────────────────────────────────────────────────────────────────
cmdr::input::pause() {
    local message="${1:-Press any key to continue...}"
    local description="${2:-}"
    local seconds="${3:-}"

    # If description is a plain integer, treat it as seconds
    if [[ "$description" =~ ^[0-9]+$ ]]; then
        seconds="$description"
        description=""
    fi

    local CYAN=$'\033[36m' BOLD=$'\033[1m' RESET=$'\033[0m'
    local GRAY=$'\033[90m'

    local _min_w=$_CMDR_INPUT_MIN_W
    (( ${#description} + 5 > _min_w )) && _min_w=$(( ${#description} + 5 ))
    if [[ -n "$seconds" ]]; then
        local _init_time_str
        if (( seconds < 60 )); then
            _init_time_str="${seconds}s"
        elif (( seconds < 3600 )); then
            _init_time_str="$(( seconds / 60 )):$(printf '%02d' $(( seconds % 60 )))"
        else
            _init_time_str="$(( seconds / 3600 )):$(printf '%02d' $(( (seconds % 3600) / 60 ))):$(printf '%02d' $(( seconds % 60 )))"
        fi
        local _bot_hint="${_init_time_str}  ·  any key to skip"
        (( ${#_bot_hint} + 7 > _min_w )) && _min_w=$(( ${#_bot_hint} + 7 ))
    fi
    local W; W=$(_cmdr_input_auto_w "$message" "" $_min_w)

    local box_lines=3
    [[ -n "$description" ]] && (( box_lines++ )) || true

    if [[ -z "$seconds" ]]; then
        _cmdr_input_reserve "$box_lines"
        printf '\n'
        _cmdr_input_top "$message" "$W" "$CYAN" "$BOLD" "$RESET"
        _cmdr_input_desc "$description" "$W" "$CYAN" "$GRAY" "$RESET"
        _cmdr_input_bot "$W" "$CYAN" "$RESET"
        read -r -s -n1 </dev/tty
        _cmdr_input_erase "$box_lines"
    else
        local remaining="$seconds"
        _cmdr_input_reserve "$box_lines"
        while true; do
            local time_str hours mins secs
            if (( remaining < 60 )); then
                time_str="${remaining}s"
            elif (( remaining < 3600 )); then
                mins=$(( remaining / 60 ))
                secs=$(( remaining % 60 ))
                time_str="${mins}:$(printf '%02d' "$secs")"
            else
                hours=$(( remaining / 3600 ))
                mins=$(( (remaining % 3600) / 60 ))
                secs=$(( remaining % 60 ))
                time_str="${hours}:$(printf '%02d' "$mins"):$(printf '%02d' "$secs")"
            fi

            printf '\n'
            _cmdr_input_top "$message" "$W" "$CYAN" "$BOLD" "$RESET"
            _cmdr_input_desc "$description" "$W" "$CYAN" "$GRAY" "$RESET"
            _cmdr_input_bot "$W" "$CYAN" "$RESET" "${time_str}  ·  any key to skip" "$GRAY"

            if (( remaining == 0 )); then
                _cmdr_input_erase "$box_lines"
                break
            fi

            if IFS= read -r -s -n1 -t 1 </dev/tty; then
                _cmdr_input_erase "$box_lines"
                break
            fi

            (( remaining-- ))
            _cmdr_input_erase "$box_lines"
        done
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# cmdr::input::text <varname> <prompt> [default] [description]
#
# Shows a framed prompt, reads a line of text into the named variable, then
# collapses to a one-line ✔ summary.  Enter with no input uses <default>.
#
#   cmdr::input::text filename "Enter filename:"
#   cmdr::input::text tag      "Enter tag:" "latest"
#   cmdr::input::text tag      "Enter tag:" "latest" "Docker image tag"
# ─────────────────────────────────────────────────────────────────────────────
cmdr::input::text() {
    local _var="${1:?cmdr::input::text requires a variable name}"
    local prompt="${2:-Input:}"
    local default="${3:-}"
    local description="${4:-}"

    # Read any validation errors set by cmdr::validator::validate
    local _errors=() _n_errors=0
    if [[ ${#_CMDR_INPUT_ERRORS[@]} -gt 0 ]]; then
        _errors=("${_CMDR_INPUT_ERRORS[@]}")
        _n_errors="${#_errors[@]}"
    fi

    local CYAN=$'\033[36m' BOLD=$'\033[1m' GREEN=$'\033[32m'
    local GRAY=$'\033[90m' RED=$'\033[31m' RESET=$'\033[0m'

    local BORDER="${CYAN}"
    if (( _n_errors > 0 )); then BORDER="${RED}"; fi

    local hint=""
    [[ -n "$default" ]] && hint=" [$default]"

    local _min_w=$_CMDR_INPUT_MIN_W
    (( ${#description} + 5 > _min_w )) && _min_w=$(( ${#description} + 5 ))
    local _err
    for _err in "${_errors[@]}"; do
        (( ${#_err} + 7 > _min_w )) && _min_w=$(( ${#_err} + 7 ))
    done
    local W; W=$(_cmdr_input_auto_w "$prompt" "$hint" $_min_w)

    local buffer="${_CMDR_INPUT_PREFILL:-}" cursor_pos="${#_CMDR_INPUT_PREFILL}"
    _CMDR_INPUT_PREFILL=""
    local content_w=$(( W - 7 ))

    # Skip the blank separator line when re-prompting so the box doesn't creep down
    if (( _n_errors == 0 )); then printf '\n'; fi
    local _box_lines=$(( 3 + _n_errors ))
    local _up=1
    [[ -n "$description" ]] && (( _box_lines++ )) && _up=2
    _cmdr_input_reserve "$_box_lines"
    _cmdr_input_top "$prompt" "$W" "$BORDER" "$BOLD" "$RESET" "$hint"
    _cmdr_input_desc "$description" "$W" "$BORDER" "$GRAY" "$RESET"

    local _vs=0
    (( cursor_pos >= content_w )) && _vs=$(( cursor_pos - content_w + 1 ))
    local _view="${buffer:$_vs:$content_w}"
    local _ipad=$(( content_w - ${#_view} ))
    (( _ipad < 0 )) && _ipad=0
    printf "${BORDER} │ ${GRAY}›${RESET} %s%*s${BORDER} │${RESET}\n" "$_view" "$_ipad" ""

    # Error rows (shown between input row and bottom border)
    local _err
    for _err in "${_errors[@]}"; do
        local _pad=$(( W - 7 - ${#_err} ))
        (( _pad < 0 )) && _pad=0
        printf "${BORDER} │ ${RED}✖ %s${RESET}%*s${BORDER} │${RESET}\n" "$_err" "$_pad" ""
    done

    _cmdr_input_bot "$W" "$BORDER" "$RESET"

    # Cursor is now below the bottom border; move back up to the input line
    # (1 bottom + _n_errors error rows + 1 = 2 + _n_errors lines up), column 6.
    printf '\033[%dA\033[%dG' "$(( 2 + _n_errors ))" "$(( 6 + cursor_pos - _vs ))"

    # Live revalidation: active on re-prompt cycles (errors already present at start).
    local _live_validate=0
    [[ -n "$_CMDR_INPUT_RULES" && _n_errors -gt 0 ]] && _live_validate=1

    # On Ctrl+C: go to col 1 of input row, up to top border, clear down, cancel line.
    trap 'printf "\r\033['"$_up"'A\033[J"; printf " \033[31m✘\033[0m \033[2m\033[9m%s\033[0m\n" "$prompt"; trap - INT; kill -INT $$' INT

    while true; do
        local key; key=$(_cmdr_input_read_key)
        case "$key" in
            $'\n'|$'\r'|'')   # Enter — accept
                break ;;
            $'\033')           # ESC — cancel
                printf '\r\033[%dA\033[J' "$_up"
                printf " \033[31m✘\033[0m \033[2m\033[9m%s\033[0m\n\n" "$prompt"
                trap - INT; kill -INT $$ ;;
            $'\033['*)         # Ignore unrecognised escape sequences (arrow keys etc.)
                ;;
            $'\177'|$'\010')   # Backspace
                if (( ${#buffer} > 0 )); then
                    buffer="${buffer%?}"
                    cursor_pos=${#buffer}
                    if (( _live_validate )); then
                        _errors=()
                        _cmdr_validator_run_rules "$_CMDR_INPUT_RULES" "$buffer" _errors
                        _n_errors=${#_errors[@]}
                        BORDER="${CYAN}"; (( _n_errors > 0 )) && BORDER="${RED}"
                    fi
                    _cmdr_input_text_redraw
                fi ;;
            *)
                # Printable character (ASCII 0x20–0x7E, or multibyte UTF-8)
                if [[ -n "$key" && ( ${#key} -gt 1 || ( "$key" > $'\037' && "$key" != $'\177' ) ) ]]; then
                    buffer="${buffer}${key}"
                    cursor_pos=${#buffer}
                    if (( _live_validate )); then
                        _errors=()
                        _cmdr_validator_run_rules "$_CMDR_INPUT_RULES" "$buffer" _errors
                        _n_errors=${#_errors[@]}
                        BORDER="${CYAN}"; (( _n_errors > 0 )) && BORDER="${RED}"
                    fi
                    _cmdr_input_text_redraw
                fi ;;
        esac
    done
    trap - INT

    local reply="${buffer:-$default}"

    printf '\r\033[%dA\033[J' "$_up"
    printf "${GREEN} ✔ ${RESET}${BOLD}%s${RESET}  ${GRAY}%s${RESET}\n\n" "$prompt" "$reply"

    printf -v "$_var" '%s' "$reply"
}

# Redraw the password-input box — identical to _cmdr_input_text_redraw but
# shows '*' for every buffered character instead of the actual content.
_cmdr_input_password_redraw() {
    local _stars; _stars=$(printf '%*s' "${#buffer}" '' | tr ' ' '*')
    local _vs=0
    if (( cursor_pos >= content_w )); then
        _vs=$(( cursor_pos - content_w + 1 ))
    fi
    local _view="${_stars:$_vs:$content_w}"
    local _pad=$(( content_w - ${#_view} ))
    (( _pad < 0 )) && _pad=0

    local _up=1; [[ -n "$description" ]] && _up=2
    printf '\r\033[%dA\033[J' "$_up"
    _cmdr_input_top "$prompt" "$W" "$BORDER" "$BOLD" "$RESET"
    _cmdr_input_desc "$description" "$W" "$BORDER" "$GRAY" "$RESET"
    printf "${BORDER} │ ${GRAY}›${RESET} %s%*s${BORDER} │${RESET}\n" "$_view" "$_pad" ""
    local _e
    for _e in "${_errors[@]}"; do
        local _p=$(( W - 7 - ${#_e} ))
        (( _p < 0 )) && _p=0
        printf "${BORDER} │ ${RED}✖ %s${RESET}%*s${BORDER} │${RESET}\n" "$_e" "$_p" ""
    done
    _cmdr_input_bot "$W" "$BORDER" "$RESET"
    printf '\033[%dA\033[%dG' "$(( 2 + _n_errors ))" "$(( 6 + cursor_pos - _vs ))"
}

# ─────────────────────────────────────────────────────────────────────────────
# cmdr::input::password <varname> <prompt> [description]
#
# Like cmdr::input::text but echoes '*' for every character and omits the
# value from the ✔ summary line.
#
#   cmdr::input::password secret "Password:"
#   cmdr::input::password secret "Password:" "At least 8 characters"
# ─────────────────────────────────────────────────────────────────────────────
cmdr::input::password() {
    local _var="${1:?cmdr::input::password requires a variable name}"
    local prompt="${2:-Password:}"
    local description="${3:-}"

    local _errors=() _n_errors=0
    if [[ ${#_CMDR_INPUT_ERRORS[@]} -gt 0 ]]; then
        _errors=("${_CMDR_INPUT_ERRORS[@]}")
        _n_errors="${#_errors[@]}"
    fi

    local CYAN=$'\033[36m' BOLD=$'\033[1m' GREEN=$'\033[32m'
    local GRAY=$'\033[90m' RED=$'\033[31m' RESET=$'\033[0m'

    local BORDER="${CYAN}"
    if (( _n_errors > 0 )); then BORDER="${RED}"; fi

    local _min_w=$_CMDR_INPUT_MIN_W
    (( ${#description} + 5 > _min_w )) && _min_w=$(( ${#description} + 5 ))
    local _err
    for _err in "${_errors[@]}"; do
        (( ${#_err} + 7 > _min_w )) && _min_w=$(( ${#_err} + 7 ))
    done
    local W; W=$(_cmdr_input_auto_w "$prompt" "" $_min_w)

    local buffer="" cursor_pos=0
    _CMDR_INPUT_PREFILL=""
    local content_w=$(( W - 7 ))

    if (( _n_errors == 0 )); then printf '\n'; fi
    local _box_lines=$(( 3 + _n_errors ))
    local _up=1
    [[ -n "$description" ]] && (( _box_lines++ )) && _up=2
    _cmdr_input_reserve "$_box_lines"
    _cmdr_input_top "$prompt" "$W" "$BORDER" "$BOLD" "$RESET"
    _cmdr_input_desc "$description" "$W" "$BORDER" "$GRAY" "$RESET"
    printf "${BORDER} │ ${GRAY}›${RESET} %*s${BORDER} │${RESET}\n" "$content_w" ""

    local _err
    for _err in "${_errors[@]}"; do
        local _pad=$(( W - 7 - ${#_err} ))
        (( _pad < 0 )) && _pad=0
        printf "${BORDER} │ ${RED}✖ %s${RESET}%*s${BORDER} │${RESET}\n" "$_err" "$_pad" ""
    done

    _cmdr_input_bot "$W" "$BORDER" "$RESET"
    printf '\033[%dA\033[%dG' "$(( 2 + _n_errors ))" 6

    local _live_validate=0
    [[ -n "$_CMDR_INPUT_RULES" && _n_errors -gt 0 ]] && _live_validate=1

    trap 'printf "\r\033['"$_up"'A\033[J"; printf " \033[31m✘\033[0m \033[2m\033[9m%s\033[0m\n" "$prompt"; trap - INT; kill -INT $$' INT

    while true; do
        local key; key=$(_cmdr_input_read_key)
        case "$key" in
            $'\n'|$'\r'|'')
                break ;;
            $'\033')
                printf '\r\033[%dA\033[J' "$_up"
                printf " \033[31m✘\033[0m \033[2m\033[9m%s\033[0m\n\n" "$prompt"
                trap - INT; kill -INT $$ ;;
            $'\033['*)
                ;;
            $'\177'|$'\010')
                if (( ${#buffer} > 0 )); then
                    buffer="${buffer%?}"
                    cursor_pos=${#buffer}
                    if (( _live_validate )); then
                        _errors=()
                        _cmdr_validator_run_rules "$_CMDR_INPUT_RULES" "$buffer" _errors
                        _n_errors=${#_errors[@]}
                        BORDER="${CYAN}"; (( _n_errors > 0 )) && BORDER="${RED}"
                    fi
                    _cmdr_input_password_redraw
                fi ;;
            *)
                if [[ -n "$key" && ( ${#key} -gt 1 || ( "$key" > $'\037' && "$key" != $'\177' ) ) ]]; then
                    buffer="${buffer}${key}"
                    cursor_pos=${#buffer}
                    if (( _live_validate )); then
                        _errors=()
                        _cmdr_validator_run_rules "$_CMDR_INPUT_RULES" "$buffer" _errors
                        _n_errors=${#_errors[@]}
                        BORDER="${CYAN}"; (( _n_errors > 0 )) && BORDER="${RED}"
                    fi
                    _cmdr_input_password_redraw
                fi ;;
        esac
    done
    trap - INT

    local _mask; _mask=$(printf '%*s' "${#buffer}" '' | tr ' ' '*')
    [[ -z "$_mask" ]] && _mask="(empty)"

    printf '\r\033[%dA\033[J' "$_up"
    printf "${GREEN} ✔ ${RESET}${BOLD}%s${RESET}  ${GRAY}%s${RESET}\n\n" "$prompt" "$_mask"

    printf -v "$_var" '%s' "$buffer"
}

# ─────────────────────────────────────────────────────────────────────────────
# cmdr::input::select <varname> <prompt> <description> <option>...
#
# Renders a framed list.  Navigate with ↑/↓, confirm with Enter.
# Sets <varname> to the chosen option text.  Pass "" for no description.
#
#   cmdr::input::select env "Choose environment:" "" development staging production
#   cmdr::input::select env "Choose environment:" "Where to deploy" development staging production
#   echo "Selected: $env"
# ─────────────────────────────────────────────────────────────────────────────
cmdr::input::select() {
    local _var="${1:?cmdr::input::select requires a variable name}"
    local prompt="${2:?cmdr::input::select requires a prompt}"
    local description="${3:-}"
    shift 3
    local options=("$@")
    local n="${#options[@]}"
    (( n == 0 )) && { cmdr::output::error "cmdr::input::select: no options provided"; return 1; }

    # Read any validation errors set by cmdr::validator::validate
    local _errors=() _n_errors=0
    if [[ ${#_CMDR_INPUT_ERRORS[@]} -gt 0 ]]; then
        _errors=("${_CMDR_INPUT_ERRORS[@]}")
        _n_errors="${#_errors[@]}"
    fi

    local CYAN=$'\033[36m' BOLD=$'\033[1m' GREEN=$'\033[32m'
    local GRAY=$'\033[90m' RED=$'\033[31m' RESET=$'\033[0m'

    local BORDER="${CYAN}"
    if (( _n_errors > 0 )); then BORDER="${RED}"; fi

    local _nav_hint="↑↓ navigate  ·  enter to select"
    local _max_opt=0; local _o
    for _o in "${options[@]}"; do (( ${#_o} > _max_opt )) && _max_opt=${#_o}; done
    local _min_w=$(( 9 + _max_opt ))
    (( _min_w < _CMDR_INPUT_MIN_W )) && _min_w=$_CMDR_INPUT_MIN_W
    (( ${#description} + 5 > _min_w )) && _min_w=$(( ${#description} + 5 ))
    (( ${#_nav_hint} + 7 > _min_w )) && _min_w=$(( ${#_nav_hint} + 7 ))
    local _err
    for _err in "${_errors[@]}"; do
        (( ${#_err} + 7 > _min_w )) && _min_w=$(( ${#_err} + 7 ))
    done
    local W; W=$(_cmdr_input_auto_w "$prompt" "" $_min_w)
    local box_lines=$(( n + 2 + _n_errors ))   # top + n options + errors + bottom
    [[ -n "$description" ]] && (( box_lines++ )) || true

    local cursor=0

    if (( _n_errors == 0 )); then printf '\n'; fi
    _cmdr_input_reserve "$box_lines"
    trap '_cmdr_input_erase "$box_lines"; printf " \033[31m✘\033[0m \033[2m\033[9m%s\033[0m\n" "$prompt"; trap - INT; kill -INT $$' INT
    while true; do
        _cmdr_input_top "$prompt" "$W" "$BORDER" "$BOLD" "$RESET"
        _cmdr_input_desc "$description" "$W" "$BORDER" "$GRAY" "$RESET"
        local i
        for (( i = 0; i < n; i++ )); do
            local pad=$(( W - 9 - ${#options[$i]} ))
            (( pad < 0 )) && pad=0
            if (( i == cursor )); then
                printf "${BORDER} │ ${RESET}  ${BORDER}›${RESET} ${BOLD}%s${RESET}%*s${BORDER} │${RESET}\n" "${options[$i]}" "$pad" ""
            else
                printf "${BORDER} │ ${RESET}    ${GRAY}%s${RESET}%*s${BORDER} │${RESET}\n" "${options[$i]}" "$pad" ""
            fi
        done

        # Error rows
        local _err
        for _err in "${_errors[@]}"; do
            local _pad=$(( W - 7 - ${#_err} ))
            (( _pad < 0 )) && _pad=0
            printf "${BORDER} │ ${RED}✖ %s${RESET}%*s${BORDER} │${RESET}\n" "$_err" "$_pad" ""
        done

        _cmdr_input_bot "$W" "$BORDER" "$RESET" "$_nav_hint" "$GRAY"

        local key; key=$(_cmdr_input_read_key)
        case "$key" in
            $'\033[A') (( cursor > 0 ))     && (( cursor-- )) || true ;;   # ↑
            $'\033[B') (( cursor < n - 1 )) && (( cursor++ )) || true ;;   # ↓
            $'\033')   # ESC — cancel
                _cmdr_input_erase "$box_lines"
                printf " \033[31m✘\033[0m \033[2m\033[9m%s\033[0m\n\n" "$prompt"
                trap - INT; kill -INT $$ ;;
            $'\n'|'')  break ;;                                              # Enter
        esac
        _cmdr_input_erase "$box_lines"
    done
    trap - INT

    _cmdr_input_erase "$box_lines"
    printf "${GREEN} ✔ ${RESET}${BOLD}%s${RESET}  ${GRAY}%s${RESET}\n\n" \
        "$prompt" "${options[$cursor]}"
    printf -v "$_var" '%s' "${options[$cursor]}"
}

# ─────────────────────────────────────────────────────────────────────────────
# cmdr::input::multiselect <varname> <prompt> <description> <option>...
#
# Renders a framed checklist.  Navigate with ↑/↓, toggle with Space,
# confirm with Enter.  Sets <varname> to a comma-separated list of the
# chosen option texts.  Pass "" for no description.
#
#   cmdr::input::multiselect chosen "Select features:" "" redis postgres nginx
#   cmdr::input::multiselect chosen "Select features:" "Pick any combination" redis postgres nginx
#   echo "Chosen: $chosen"
#   IFS=',' read -ra arr <<< "$chosen"
# ─────────────────────────────────────────────────────────────────────────────
cmdr::input::multiselect() {
    local _var="${1:?cmdr::input::multiselect requires a variable name}"
    local prompt="${2:?cmdr::input::multiselect requires a prompt}"
    local description="${3:-}"
    shift 3
    local options=("$@")
    local n="${#options[@]}"
    (( n == 0 )) && { cmdr::output::error "cmdr::input::multiselect: no options provided"; return 1; }

    # Read any validation errors set by cmdr::validator::validate
    local _errors=() _n_errors=0
    if [[ ${#_CMDR_INPUT_ERRORS[@]} -gt 0 ]]; then
        _errors=("${_CMDR_INPUT_ERRORS[@]}")
        _n_errors="${#_errors[@]}"
    fi

    local CYAN=$'\033[36m' BOLD=$'\033[1m' GREEN=$'\033[32m'
    local GRAY=$'\033[90m' RED=$'\033[31m' RESET=$'\033[0m'

    local BORDER="${CYAN}"
    if (( _n_errors > 0 )); then BORDER="${RED}"; fi

    local _nav_hint="space toggle  ·  a all  ·  n none  ·  ↑↓ navigate  ·  enter confirm"
    local _max_opt=0; local _o
    for _o in "${options[@]}"; do (( ${#_o} > _max_opt )) && _max_opt=${#_o}; done
    local _min_w=$(( 10 + _max_opt ))
    (( _min_w < _CMDR_INPUT_MIN_W )) && _min_w=$_CMDR_INPUT_MIN_W
    (( ${#description} + 5 > _min_w )) && _min_w=$(( ${#description} + 5 ))
    (( ${#_nav_hint} + 7 > _min_w )) && _min_w=$(( ${#_nav_hint} + 7 ))
    local _err
    for _err in "${_errors[@]}"; do
        (( ${#_err} + 7 > _min_w )) && _min_w=$(( ${#_err} + 7 ))
    done
    local W; W=$(_cmdr_input_auto_w "$prompt" "" $_min_w)
    local box_lines=$(( n + 2 + _n_errors ))
    [[ -n "$description" ]] && (( box_lines++ )) || true

    local cursor=0
    local _toggled=()
    for (( i = 0; i < n; i++ )); do _toggled[$i]=0; done

    if (( _n_errors == 0 )); then printf '\n'; fi
    _cmdr_input_reserve "$box_lines"
    trap '_cmdr_input_erase "$box_lines"; printf " \033[31m✘\033[0m \033[2m\033[9m%s\033[0m\n" "$prompt"; trap - INT; kill -INT $$' INT
    while true; do
        _cmdr_input_top "$prompt" "$W" "$BORDER" "$BOLD" "$RESET"
        _cmdr_input_desc "$description" "$W" "$BORDER" "$GRAY" "$RESET"
        local i
        for (( i = 0; i < n; i++ )); do
            local check arrow text_style
            if [[ "${_toggled[$i]}" == "1" ]]; then
                check="${BOLD}◼${RESET}"
                text_style="${BOLD}"
            else
                check="${GRAY}◻${RESET}"
                text_style="${GRAY}"
            fi
            if (( i == cursor )); then
                arrow="${BORDER}›${RESET}"
            else
                arrow=" "
            fi
            local pad=$(( W - 10 - ${#options[$i]} ))
            (( pad < 0 )) && pad=0
            printf "${BORDER} │ ${RESET} %s %s %s%s${RESET}%*s${BORDER} │${RESET}\n" \
                "$arrow" "$check" "$text_style" "${options[$i]}" "$pad" ""
        done

        # Error rows
        local _err
        for _err in "${_errors[@]}"; do
            local _pad=$(( W - 7 - ${#_err} ))
            (( _pad < 0 )) && _pad=0
            printf "${BORDER} │ ${RED}✖ %s${RESET}%*s${BORDER} │${RESET}\n" "$_err" "$_pad" ""
        done

        _cmdr_input_bot "$W" "$BORDER" "$RESET" "$_nav_hint" "$GRAY"

        local key; key=$(_cmdr_input_read_key)
        case "$key" in
            $'\033[A') (( cursor > 0 ))     && (( cursor-- )) || true ;;   # ↑
            $'\033[B') (( cursor < n - 1 )) && (( cursor++ )) || true ;;   # ↓
            ' ')
                if [[ "${_toggled[$cursor]}" == "1" ]]; then
                    _toggled[$cursor]=0
                else
                    _toggled[$cursor]=1
                fi
                ;;
            'a') for (( i = 0; i < n; i++ )); do _toggled[$i]=1; done ;;
            'n') for (( i = 0; i < n; i++ )); do _toggled[$i]=0; done ;;
            $'\033')   # ESC — cancel
                _cmdr_input_erase "$box_lines"
                printf " \033[31m✘\033[0m \033[2m\033[9m%s\033[0m\n\n" "$prompt"
                trap - INT; kill -INT $$ ;;
            $'\n'|'') break ;;                                      # Enter
        esac
        _cmdr_input_erase "$box_lines"
    done
    trap - INT

    _cmdr_input_erase "$box_lines"

    # Build comma-separated result and a display summary
    local result=() i
    for (( i = 0; i < n; i++ )); do
        [[ "${_toggled[$i]}" == "1" ]] && result+=("${options[$i]}")
    done

    local joined value
    if (( ${#result[@]} == 0 )); then
        joined="(none)"
        value=""
    else
        local IFS=', '
        joined="${result[*]}"
        value="$joined"
    fi

    printf "${GREEN} ✔ ${RESET}${BOLD}%s${RESET}  ${GRAY}%s${RESET}\n\n" "$prompt" "$joined"
    printf -v "$_var" '%s' "$value"
}
