cmdr::validator::rule::no_spaces() {
    [[ "$1" != *" "* ]] || cmdr::validator::fail 'It must not contain spaces.'
}
