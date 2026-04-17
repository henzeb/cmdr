# Core bootstrap — sources all internal helpers in dependency order.
# Guard against double-sourcing (modules source this for IDE type hinting).
[[ -n "${_CMDR_LOADED:-}" ]] && return 0
_CMDR_LOADED=1

_cmdr_core_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
source "${_cmdr_core_dir}/common.sh"

# shellcheck source=file.sh
source "${_cmdr_core_dir}/file.sh"

# shellcheck source=output/output.sh
source "${_cmdr_core_dir}/output/output.sh"

# shellcheck source=output/progressbar.sh
source "${_cmdr_core_dir}/output/progressbar.sh"

# shellcheck source=output/tasks.sh
source "${_cmdr_core_dir}/output/tasks.sh"

# shellcheck source=register.sh
source "${_cmdr_core_dir}/register.sh"

# shellcheck source=hook.sh
source "${_cmdr_core_dir}/hook.sh"

# Register input, complete, composer, validator, and shell as lazy modules
cmdr::register::module cmdr::input
cmdr::register::module cmdr::complete
cmdr::register::module cmdr::composer
cmdr::register::module cmdr::validator
cmdr::register::module cmdr::shell

# shellcheck source=prescan.sh
source "${_cmdr_core_dir}/prescan.sh"

# shellcheck source=args.sh
source "${_cmdr_core_dir}/args.sh"

# shellcheck source=help.sh
source "${_cmdr_core_dir}/help.sh"

# shellcheck source=json.sh
source "${_cmdr_core_dir}/json.sh"

# shellcheck source=loader.sh
source "${_cmdr_core_dir}/loader.sh"

# shellcheck source=dispatch.sh
source "${_cmdr_core_dir}/dispatch.sh"

# shellcheck source=callers.sh
source "${_cmdr_core_dir}/callers.sh"

cmdr::register::module cmdr::make

# Bootstrap: prescan, load config + modules, define and parse global flags.
# After this call, _CMDR_REMAINING_ARGS holds the stripped argv for dispatch.
cmdr::bootstrap() {
    cmdr::hook::run cmdr.bootstrapping
    cmdr::complete::prescan "$@"
    cmdr::loader::source_config_defaults
    cmdr::loader::source_vendor_modules
    cmdr::loader::source_modules
    cmdr::loader::source_config_overrides
    [[ -n "$_CMDR_PRESCAN_ENV" ]] && cmdr::loader::source_config_env "$_CMDR_PRESCAN_ENV"
    _cmdr_args_define_global \
        "{--env=|-e= : Use .config.<env> instead of .config for project/user config}" \
        "{--root=|-r= : Override the project root directory (also honoured via \$CMDR_ROOT env var)}" \
        "{--quiet|-q : Suppress informational output (info messages)}"
    _cmdr_args_parse_global "$@"

    cmdr::hook::run cmdr.bootstrapped
}
