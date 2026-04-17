cmdr::validator::rule::alpha() {
    [[ "$1" =~ ^[a-zA-Z]+$ ]] || cmdr::validator::fail 'It may only contain letters.'
}

cmdr::validator::rule::alpha_num() {
    [[ "$1" =~ ^[a-zA-Z0-9]+$ ]] || cmdr::validator::fail 'It may only contain letters and numbers.'
}

cmdr::validator::rule::alpha_dash() {
    [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] || cmdr::validator::fail 'It may only contain letters, numbers, dashes, and underscores.'
}

cmdr::validator::rule::uppercase() {
    [[ "$1" == "${1^^}" ]] || cmdr::validator::fail 'It must be uppercase.'
}

cmdr::validator::rule::lowercase() {
    [[ "$1" == "${1,,}" ]] || cmdr::validator::fail 'It must be lowercase.'
}

cmdr::validator::rule::ucfirst() {
    [[ "$1" =~ ^[A-Z] ]] || cmdr::validator::fail 'It must start with an uppercase letter.'
}

cmdr::validator::rule::starts_with() {
    local value="$1" param="$2"
    local IFS=',' prefix
    local -a prefixes
    read -ra prefixes <<< "$param"
    for prefix in "${prefixes[@]}"; do
        [[ "$value" == "$prefix"* ]] && return 0
    done
    cmdr::validator::fail "It must start with one of: ${param//,/, }."
}

cmdr::validator::rule::ends_with() {
    local value="$1" param="$2"
    local IFS=',' suffix
    local -a suffixes
    read -ra suffixes <<< "$param"
    for suffix in "${suffixes[@]}"; do
        [[ "$value" == *"$suffix" ]] && return 0
    done
    cmdr::validator::fail "It must end with one of: ${param//,/, }."
}

cmdr::validator::rule::ascii() {
    # In C locale [:print:] and [:space:] cover exactly the ASCII range
    LC_ALL=C
    [[ "$1" =~ ^[[:print:][:space:]]*$ ]] || cmdr::validator::fail 'It may only contain ASCII characters.'
}

cmdr::validator::rule::regex() {
    # shellcheck disable=SC2076 — intentionally unquoted for regex matching
    [[ "$1" =~ $2 ]] || cmdr::validator::fail 'The format is invalid.'
}
