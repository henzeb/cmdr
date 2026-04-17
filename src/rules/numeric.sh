cmdr::validator::rule::numeric() {
    [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || cmdr::validator::fail 'It must be a number.'
}

cmdr::validator::rule::min() {
    local value="$1" param="$2"
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        awk "BEGIN { exit !($value >= $param) }" || \
            cmdr::validator::fail "It must be at least ${param}." numeric "$param"
    elif [[ "$value" == *,* ]]; then
        local _s="${value//,/}"
        local _count=$(( ${#value} - ${#_s} + 1 ))
        (( _count >= param )) || cmdr::validator::fail "It must have at least ${param} items." array "$param"
    else
        (( ${#value} >= param )) || cmdr::validator::fail "It must be at least ${param} characters." string "$param"
    fi
}

cmdr::validator::rule::max() {
    local value="$1" param="$2"
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        awk "BEGIN { exit !($value <= $param) }" || \
            cmdr::validator::fail "It must be no greater than ${param}." numeric "$param"
    elif [[ "$value" == *,* ]]; then
        local _s="${value//,/}"
        local _count=$(( ${#value} - ${#_s} + 1 ))
        (( _count <= param )) || cmdr::validator::fail "It must have at most ${param} items." array "$param"
    else
        (( ${#value} <= param )) || cmdr::validator::fail "It must not exceed ${param} characters." string "$param"
    fi
}

# size:<n> — exact numeric value, exact string length, or exact item count (mirrors min/max dual behaviour)
cmdr::validator::rule::size() {
    local value="$1" param="$2"
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        awk "BEGIN { exit !($value == $param) }" || \
            cmdr::validator::fail "It must be ${param}." numeric "$param"
    elif [[ "$value" == *,* ]]; then
        local _s="${value//,/}"
        local _count=$(( ${#value} - ${#_s} + 1 ))
        (( _count == param )) || cmdr::validator::fail "It must have exactly ${param} items." array "$param"
    else
        (( ${#value} == param )) || cmdr::validator::fail "It must be ${param} characters." string "$param"
    fi
}

cmdr::validator::rule::integer() {
    [[ "$1" =~ ^-?[0-9]+$ ]] || cmdr::validator::fail 'It must be a whole number.'
}

cmdr::validator::rule::positive() {
    local value="$1"
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        awk "BEGIN { exit !($value > 0) }" || cmdr::validator::fail 'It must be a positive number.'
    else
        cmdr::validator::fail 'It must be a positive number.'
    fi
}

cmdr::validator::rule::negative() {
    local value="$1"
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        awk "BEGIN { exit !($value < 0) }" || cmdr::validator::fail 'It must be a negative number.'
    else
        cmdr::validator::fail 'It must be a negative number.'
    fi
}

cmdr::validator::rule::multiple_of() {
    local value="$1" param="$2"
    [[ "$value" =~ ^-?[0-9]+$ ]] || cmdr::validator::fail "It must be a multiple of ${param}."
    (( value % param == 0 )) || cmdr::validator::fail "It must be a multiple of ${param}."
}

# digits:<n> — exactly n digits (unsigned integers only)
cmdr::validator::rule::digits() {
    local value="$1" param="$2"
    [[ "$value" =~ ^[0-9]{$param}$ ]] || cmdr::validator::fail "It must be ${param} digits."
}

# digits_between:<min,max> — digit count within range (unsigned integers only)
cmdr::validator::rule::digits_between() {
    local value="$1" param="$2"
    local min="${param%%,*}" max="${param##*,}"
    [[ "$value" =~ ^[0-9]{$min,$max}$ ]] || \
        cmdr::validator::fail "It must be between ${min} and ${max} digits."
}

# decimal:<n> or decimal:<min,max> — requires a decimal number with exactly n
# (or between min and max) places after the decimal point
cmdr::validator::rule::decimal() {
    local value="$1" param="$2"
    local min max
    if [[ "$param" == *,* ]]; then
        min="${param%%,*}"
        max="${param##*,}"
    else
        min="$param"
        max="$param"
    fi
    if [[ "$value" =~ ^-?[0-9]+\.([0-9]+)$ ]]; then
        local places="${#BASH_REMATCH[1]}"
        (( places >= min && places <= max )) || \
            cmdr::validator::fail "It must have between ${min} and ${max} decimal places." places "$param"
    else
        cmdr::validator::fail "It must be a decimal number."
    fi
}

# between:<min,max> — numeric range or string length range (mirrors min/max dual behaviour)
cmdr::validator::rule::between() {
    local value="$1" param="$2"
    local min="${param%%,*}" max="${param##*,}"
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        awk "BEGIN { exit !($value >= $min && $value <= $max) }" || \
            cmdr::validator::fail "It must be between ${min} and ${max}." numeric "$param"
    elif [[ "$value" == *,* ]]; then
        local _s="${value//,/}"
        local _count=$(( ${#value} - ${#_s} + 1 ))
        (( _count >= min && _count <= max )) || \
            cmdr::validator::fail "It must have between ${min} and ${max} items." array "$param"
    else
        local len="${#value}"
        (( len >= min && len <= max )) || \
            cmdr::validator::fail "It must be between ${min} and ${max} characters." string "$param"
    fi
}
