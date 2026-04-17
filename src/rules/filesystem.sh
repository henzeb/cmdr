cmdr::validator::rule::file_exists() {
    [[ -f "$1" ]] || cmdr::validator::fail 'This path does not point to an existing file.'
}

cmdr::validator::rule::dir_exists() {
    [[ -d "$1" ]] || cmdr::validator::fail 'This path does not point to an existing directory.'
}

cmdr::validator::rule::writable() {
    [[ -w "$1" ]] || cmdr::validator::fail 'This path is not writable.'
}

cmdr::validator::rule::not_exists() {
    [[ ! -e "$1" ]] || cmdr::validator::fail 'This path already exists.'
}

# extension:<ext>  — accepts with or without leading dot: extension:sh or extension:.sh
cmdr::validator::rule::extension() {
    local value="$1" param="$2"
    local ext="${param#.}"   # strip leading dot if present
    [[ "$value" == *."$ext" ]] || cmdr::validator::fail "This file must have a .${ext} extension."
}
