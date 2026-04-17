cmdr::validator::rule::alias_not_exists() {
    ! cmdr::shell::line_exists "alias ${1}=" \
        || cmdr::validator::fail "Alias already exists."
}
