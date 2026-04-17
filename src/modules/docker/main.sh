# Show docker module only when a compose file is present in $PWD.
# Override detected filenames via CMDR_DOCKER_COMPOSE_FILES (space-separated, shell-exported).
read -ra _cmdr_docker_files <<< "${CMDR_DOCKER_COMPOSE_FILES}"
cmdr::file::exists "${_cmdr_docker_files[@]}" || return 0

cmdr::register::call "docker compose" "docker compose"

cmdr::register::alias docker d
cmdr::register::alias docker::start s
cmdr::register::alias docker::stop st
cmdr::register::alias docker::down d
cmdr::register::alias docker::exec e

cmdr::register::help docker start "Start containers"
cmdr::register::help docker stop  "Stop containers"
cmdr::register::help docker down  "Bring down containers"
cmdr::register::help docker exec  "Open a shell in a running container"

_docker_complete_services() {
    docker compose config --services 2>/dev/null
}

cmdr::register::completer docker::start _docker_complete_services
cmdr::register::completer docker::stop  _docker_complete_services
cmdr::register::completer docker::exec  _docker_complete_services

cmdr::register::native_help docker::start
cmdr::register::native_help docker::stop
cmdr::register::native_help docker::down

cmdr::args::define docker::exec \
    "{service? : Service to exec into (default: \$CMDR_DOCKER_EXEC_SERVICE)}" \
    "{cmd? : Command to run (default: \$CMDR_DOCKER_SHELL or sh)}"
