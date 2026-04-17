# Output helpers — coloured messages for info, warning, error, success, and fatal exit.

cmdr::output::info() {
    printf '\033[0;32m[%s]: %s%s\033[0m\n' "$CMDR_TAG" "$(cmdr::common::timestamp)" "$*"
}

cmdr::output::warning() {
    printf '\033[0;33m[%s]: %s%s\033[0m\n' "$CMDR_TAG" "$(cmdr::common::timestamp)" "$*" >&2
}

cmdr::output::error() {
    printf '\033[0;31m[%s]: %s%s\033[0m\n' "$CMDR_TAG" "$(cmdr::common::timestamp)" "$*" >&2
}

cmdr::output::fail() {
    local code="${2:-1}"
    printf '\033[0;31m[%s]: %s%s\033[0m\n' "$CMDR_TAG" "$(cmdr::common::timestamp)" "$1" >&2
    exit "$code"
}

cmdr::output::success() {
    cmdr::output::info "$*"
    exit 0
}
