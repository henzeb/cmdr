cmdr::file::exists() {
    local f
    for f in "$@"; do
        [[ -f "$f" ]] && return 0
    done
    return 1
}
