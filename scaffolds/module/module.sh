{{NAME}}::example() {
    local greeting; greeting=$(cmdr::args::get greeting)
    local shout;    shout=$(cmdr::args::get_option shout)

    local msg="${greeting} from {{NAME}}!"
    [[ -n "$shout" ]] && msg="${msg^^}"

    cmdr::output::info "$msg"
}
