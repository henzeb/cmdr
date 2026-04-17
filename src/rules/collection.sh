# in:<a,b,c>  — value must be one of the comma-separated options
cmdr::validator::rule::in() {
    local value="$1" param="$2"
    local IFS=','
    local -a options
    read -ra options <<< "$param"
    local opt
    for opt in "${options[@]}"; do
        [[ "$value" == "$opt" ]] && return 0
    done
    cmdr::validator::fail "It must be one of: ${param}."
}

# not_in:<a,b,c>  — value must not be any of the comma-separated options
cmdr::validator::rule::not_in() {
    local value="$1" param="$2"
    local IFS=','
    local -a options
    read -ra options <<< "$param"
    local opt
    for opt in "${options[@]}"; do
        [[ "$value" == "$opt" ]] && cmdr::validator::fail "It must not be one of: ${param}."
    done
    return 0
}
