demo::showcase::args() {
    local name times shout
    name=$(cmdr::args::get name)
    times=$(cmdr::args::get_option times)
    shout=$(cmdr::args::get_option shout)

    cmdr::output::info "=== args showcase ==="
    echo ""
    cmdr::output::info "Registered via cmdr::args::define:"
    cmdr::output::info "  {name=World}   → \"$name\""
    cmdr::output::info "  {--times=1}    → \"$times\""
    cmdr::output::info "  {--shout}      → \"${shout:-0}\""
    echo ""

    local msg="Hello, ${name}!"
    [[ -n "$shout" ]] && msg="${msg^^}"

    local i
    for (( i=0; i<times; i++ )); do
        cmdr::output::info "$msg"
    done
}

demo::showcase::alias() {
    cmdr::output::info "=== alias showcase ==="
    echo ""

    local key val display
    for key in "${!ALIASES[@]}"; do
        val="${ALIASES[$key]}"
        # Scoped keys are stored as "parent:short" internally.
        # Convert to the actual invocation: "cmdr <parent> <short>"
        if [[ "$key" == *:* ]]; then
            local parent="${key%:*}" short="${key##*:}"
            display="cmdr ${parent} ${short}"
        else
            display="cmdr ${key}"
        fi
        printf "  %-24s → cmdr %s\n" "$display" "$val"
    done | sort

    echo ""
}
