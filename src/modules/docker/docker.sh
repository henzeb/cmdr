docker::start() {
    cmdr::hook::run cmdr.docker.starting "$@"

    cmdr::call "docker compose" up -d "$@"

    cmdr::hook::run cmdr.docker.started "$@"
}

docker::stop() {
    cmdr::hook::run cmdr.docker.stopping "$@"

    cmdr::call "docker compose" stop "$@"

    cmdr::hook::run cmdr.docker.stopped "$@"
}

docker::down() {
    cmdr::hook::run cmdr.docker.taking_down "$@"

    cmdr::call "docker compose" down "$@"

    cmdr::hook::run cmdr.docker.took_down "$@"
}

docker::exec() {
    local service cmd

    if [[ ${#_CMDR_ARGS[@]} -ge 2 ]]; then
        service="${_CMDR_ARGS[0]}"
        cmd="${_CMDR_ARGS[1]}"
    elif [[ ${#_CMDR_ARGS[@]} -eq 1 && -n "${CMDR_DOCKER_EXEC_SERVICE:-}" ]]; then
        service="${CMDR_DOCKER_EXEC_SERVICE}"
        cmd="${_CMDR_ARGS[0]}"
    else
        service=$(cmdr::args::get service "${CMDR_DOCKER_EXEC_SERVICE:-}")
        cmd=$(cmdr::args::get cmd "${CMDR_DOCKER_SHELL:-sh}")
    fi

    if [[ -z "$service" ]]; then
        cmdr::output::fail "No service specified and CMDR_DOCKER_EXEC_SERVICE is not set."
    fi

    cmdr::hook::run cmdr.docker.executing "$service" "$cmd"

    cmdr::call "docker compose" exec "$service" "$cmd"

    cmdr::hook::run cmdr.docker.executed "$service" "$cmd"
}
