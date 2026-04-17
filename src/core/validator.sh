# Validator — Laravel-style validation groups for values and interactive input.
#
# Public API:
#   cmdr::validator::create   <name> <rules>                     — register a validator group
#   cmdr::validator::message  <rule> <message>                   — override the error message for a rule
#   cmdr::validator::validate <name_or_rules> <value_or_fn> [args] — validate a value or input field
#
# Custom rules: define cmdr::validator::rule::<name> functions in .sh files
# inside a rules/ directory in your module. They are sourced automatically when
# your module calls `cmdr::use cmdr::validator`. Use cmdr::validator::fail to
# return an error message from a rule function.
#
# Rules are pipe-separated; parameterised rules use <rule>:<param> syntax:
#   "required|email|max:255"
#   "required|alpha_dash|min:3|max:50"
#
# When <value_or_fn> is a cmdr::input::* function, the validator loops until
# the user provides a valid value — the input box turns red and shows errors.
# Requires cmdr::use cmdr::input if using the input-function path.

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────

declare -gA _CMDR_VALIDATOR_GROUPS=()   # name → pipe-separated rule string
declare -gA _CMDR_VALIDATOR_MESSAGES=() # rule name → custom error message override

cmdr::loader::source_rules  # load shipped, user, and project-level rule files

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

# cmdr::validator::create <name> <rules>
#
# Register a named validator group. Rules are pipe-separated; parameterised
# rules use <rule>:<param> syntax.
#
#   cmdr::validator::create email_rules "required|email|max:255"
#   cmdr::validator::create age_rules   "required|numeric|min:18|max:120"
cmdr::validator::create() {
    local name="${1:?cmdr::validator::create requires a group name}"
    local rules="${2:?cmdr::validator::create requires a rule string}"
    _CMDR_VALIDATOR_GROUPS["$name"]="$rules"
}

# cmdr::validator::fail <message> [type] [param]
#
# Fail a rule with the given message. Use inside cmdr::validator::rule::* functions
# instead of the { printf '...'; return 1; } pattern:
#
#   cmdr::validator::rule::my_rule() {
#       [[ "$1" == "expected" ]] || cmdr::validator::fail 'Value must be "expected".'
#   }
#
# Optional <type> scopes a cmdr::validator::message override to a specific failure
# path within a rule. The override key is "<rule>.<type>"; falls back to "<rule>":
#
#   cmdr::validator::rule::min() {
#       ...
#       (( int_val >= param )) || cmdr::validator::fail "Must be at least ${param}." numeric "$param"
#       (( ${#value} >= param )) || cmdr::validator::fail "Must be at least ${param} chars." string "$param"
#   }
#
#   cmdr::validator::message min.numeric "At least :param."   # numeric path only
#   cmdr::validator::message min         "At least :param."   # both paths
#
# Optional <param> is used for :param substitution inside override messages.
#
# Rule functions are always called in a subshell, so exit 1 safely terminates
# only that subshell without affecting the parent shell.
cmdr::validator::fail() {
    local message="${1:?cmdr::validator::fail requires a message}"
    local type="${2:-}"
    local param="${3:-}"

    local rule_name="${FUNCNAME[1]##*::}"

    if [[ -n "$type" && -n "${_CMDR_VALIDATOR_MESSAGES["${rule_name}.${type}"]+_}" ]]; then
        message="${_CMDR_VALIDATOR_MESSAGES["${rule_name}.${type}"]//:param/$param}"
    elif [[ -n "${_CMDR_VALIDATOR_MESSAGES[$rule_name]+_}" ]]; then
        message="${_CMDR_VALIDATOR_MESSAGES[$rule_name]//:param/$param}"
    fi

    printf '%s\n' "$message"
    return 1
}

# cmdr::validator::message <rule> <message>
#
# Override the error message for a rule. Applies to both built-in and custom
# rules. Use :param in the message as a placeholder for the rule's parameter.
#
#   cmdr::validator::message required "This field cannot be empty."
#   cmdr::validator::message min      "Must be at least :param characters."
cmdr::validator::message() {
    local rule="${1:?cmdr::validator::message requires a rule name}"
    local message="${2:?cmdr::validator::message requires a message}"
    _CMDR_VALIDATOR_MESSAGES["$rule"]="$message"
}

# cmdr::validator::validate <name_or_rules> <value_or_fn> [fn_args...]
#
# Validate a literal value or collect + validate via an input function.
# The first argument is either a registered group name (see cmdr::validator::create)
# or a raw pipe-separated rule string passed inline.
#
# Literal value path — runs rules, prints errors to stderr, returns 0/1:
#   cmdr::validator::validate email_rules "user@example.com"
#   cmdr::validator::validate "required|email|max:255" "user@example.com"
#
# Input function path — loops until valid; input box turns red with errors:
#   cmdr::validator::validate email_rules cmdr::input::text email "Enter email"
#   cmdr::validator::validate "required|email|max:255" cmdr::input::text email "Enter email"
cmdr::validator::validate() {
    local group_name="${1:?cmdr::validator::validate requires a group name}"
    local fn_or_value="$2"
    shift 2
    local fn_args=("$@")

    local rule_string
    if [[ -n "${_CMDR_VALIDATOR_GROUPS[$group_name]+_}" ]]; then
        rule_string="${_CMDR_VALIDATOR_GROUPS[$group_name]}"
    else
        rule_string="$group_name"
    fi

    # Determine: function or literal value?
    local is_fn=0
    if declare -f "$fn_or_value" > /dev/null 2>&1; then
        is_fn=1
    fi

    # ── Literal-value path ──────────────────────────────────────────────────
    if (( is_fn == 0 )); then
        local errors=()
        _cmdr_validator_run_rules "$rule_string" "$fn_or_value" errors
        if (( ${#errors[@]} > 0 )); then
            local msg
            for msg in "${errors[@]}"; do
                printf '\033[0;31m✖ %s\033[0m\n' "$msg" >&2
            done
            return 1
        fi
        return 0
    fi

    # ── Input-function path ─────────────────────────────────────────────────
    # fn_args[0] is always the varname the input function writes its result into.
    local varname="${fn_args[0]}"
    _CMDR_INPUT_ERRORS=()   # no errors on first render
    _CMDR_INPUT_RULES="$rule_string"

    while true; do
        "$fn_or_value" "${fn_args[@]}"
        local value="${!varname}"

        local errors=()
        _cmdr_validator_run_rules "$rule_string" "$value" errors

        if (( ${#errors[@]} == 0 )); then
            _CMDR_INPUT_ERRORS=()   # clean up before returning
            _CMDR_INPUT_RULES=""
            return 0
        fi

        # Erase the ✔ summary line printed by the input function before re-prompting.
        # The success output ends with \n\n so cursor is two lines below the ✔ line;
        # two up+clear moves are needed to erase both the blank line and the ✔ line.
        printf '\033[A\033[2K\033[A\033[2K'
        _CMDR_INPUT_PREFILL="$value"
        _CMDR_INPUT_ERRORS=("${errors[@]}")   # triggers red box on next render
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Private dispatch helper
# ─────────────────────────────────────────────────────────────────────────────

# _cmdr_validator_run_rules <rule_string> <value> <errors_array_name>
#
# Splits rule_string on '|', dispatches to cmdr::validator::rule::<name>, and
# appends any failure messages to the named array via nameref.
_cmdr_validator_run_rules() {
    local rule_string="$1"
    local value="$2"
    local -n _vref="$3"   # caller's errors array — do not name yours "_vref"

    local IFS='|'
    local _rules=()
    read -ra _rules <<< "$rule_string"

    local rule rule_name param fn _msg _status
    for rule in "${_rules[@]}"; do
        rule="${rule// /}"          # trim surrounding whitespace
        [[ -z "$rule" ]] && continue

        if [[ "$rule" == *:* ]]; then
            rule_name="${rule%%:*}"
            param="${rule#*:}"
        else
            rule_name="$rule"
            param=""
        fi

        fn="cmdr::validator::rule::${rule_name}"
        if ! declare -f "$fn" > /dev/null 2>&1; then
            _vref+=("Unknown validation rule: ${rule_name}")
            continue
        fi

        _msg=$("$fn" "$value" "$param") && _status=0 || _status=$?
        if (( _status != 0 )); then
            local _line
            while IFS= read -r _line; do
                [[ -n "$_line" ]] && _vref+=("$_line")
            done <<< "$_msg"
        fi
    done
}

# Built-in rules live in src/rules/ and are loaded by cmdr::loader::source_rules above.
