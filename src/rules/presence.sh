cmdr::validator::rule::required() {
    [[ -n "$1" ]] || cmdr::validator::fail 'It is required.'
}
