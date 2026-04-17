# Output helpers — coloured messages for info, warning, error, success, and fatal exit.

cmdr::output::info() {
    [[ "${_CMDR_QUIET:-0}" == "1" ]] && return 0
    local BOLD=$'\033[1m' WHITE=$'\033[97m' RESET=$'\033[0m'
    printf "   ${BOLD}%s${RESET}  ${WHITE}%s${RESET}\n" "$CMDR_TAG" "$*"
}

cmdr::output::warning() {
    local BOLD=$'\033[1m' YELLOW=$'\033[33m' RESET=$'\033[0m'
    printf "${YELLOW}${BOLD} ⚠ ${RESET}${BOLD}%s${RESET}  ${YELLOW}%s${RESET}\n" "$CMDR_TAG" "$*" >&2
}

cmdr::output::error() {
    local BOLD=$'\033[1m' RED=$'\033[1m\033[91m' RESET=$'\033[0m'
    printf "${RED} ✖ ${RESET}${BOLD}%s${RESET}  ${RED}%s${RESET}\n" "$CMDR_TAG" "$*" >&2
}

cmdr::output::fail() {
    local code="${2:-1}"
    local BOLD=$'\033[1m' RED=$'\033[1m\033[91m' RESET=$'\033[0m'
    printf "${RED} ✖ ${RESET}${BOLD}%s${RESET}  ${RED}%s${RESET}\n" "$CMDR_TAG" "$1" >&2
    exit "$code"
}

cmdr::output::success() {
    [[ "${_CMDR_QUIET:-0}" == "1" ]] && return 0
    local BOLD=$'\033[1m' GREEN=$'\033[1m\033[92m' WHITE=$'\033[97m' RESET=$'\033[0m'
    printf "${GREEN} ✔ ${RESET}${BOLD}%s${RESET}  ${WHITE}%s${RESET}\n" "$CMDR_TAG" "$*"
}
