cmdr::validator::rule::has_uppercase() {
    [[ "$1" =~ [A-Z] ]] || cmdr::validator::fail 'It must contain at least one uppercase letter.'
}

cmdr::validator::rule::has_lowercase() {
    [[ "$1" =~ [a-z] ]] || cmdr::validator::fail 'It must contain at least one lowercase letter.'
}

cmdr::validator::rule::has_numbers() {
    [[ "$1" =~ [0-9] ]] || cmdr::validator::fail 'It must contain at least one number.'
}

cmdr::validator::rule::has_symbols() {
    [[ "$1" =~ [^a-zA-Z0-9] ]] || cmdr::validator::fail 'It must contain at least one symbol.'
}

cmdr::validator::rule::mixed_case() {
    [[ "$1" =~ [A-Z] && "$1" =~ [a-z] ]] || \
        cmdr::validator::fail 'It must contain both uppercase and lowercase letters.'
}

# Compound rule — collects failures from has_uppercase, has_lowercase, has_numbers,
# and has_symbols, emitting all messages so the validator shows each one separately.
cmdr::validator::rule::password() {
    local value="$1" _failed=0
    cmdr::validator::rule::has_uppercase "$value" || _failed=1
    cmdr::validator::rule::has_lowercase "$value" || _failed=1
    cmdr::validator::rule::has_numbers   "$value" || _failed=1
    cmdr::validator::rule::has_symbols   "$value" || _failed=1
    return $_failed
}
