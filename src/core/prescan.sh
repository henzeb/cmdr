# Pre-scan argv for --env, --root, and --quiet before config loading.
# Must run before modules are loaded; handles --_complete offset automatically.
#
# Sets globals: _CMDR_PRESCAN_ENV, CMDR_ROOT, _CMDR_QUIET
cmdr::complete::prescan() {
    local _start=1
    [[ "${1:-}" == "--_complete" ]] && _start=3

    local _psi _psa _psn
    _CMDR_PRESCAN_ENV=""
    for (( _psi=_start; _psi<=$#; _psi++ )); do
        _psa="${!_psi}"
        if   [[ "$_psa" == "--env="* ]]; then _CMDR_PRESCAN_ENV="${_psa#--env=}"; break
        elif [[ "$_psa" == "--env"   ]]; then _psn=$((_psi+1)); _CMDR_PRESCAN_ENV="${!_psn:-}"; break
        elif [[ "$_psa" != --*       ]]; then break
        fi
    done

    for (( _psi=_start; _psi<=$#; _psi++ )); do
        _psa="${!_psi}"
        if   [[ "$_psa" == "--root="* ]]; then CMDR_ROOT="${_psa#--root=}"; break
        elif [[ "$_psa" == "--root"   ]]; then _psn=$((_psi+1)); CMDR_ROOT="${!_psn:-}"; break
        elif [[ "$_psa" != --*        ]]; then break
        fi
    done

    _CMDR_QUIET=0
    for (( _psi=_start; _psi<=$#; _psi++ )); do
        _psa="${!_psi}"
        if   [[ "$_psa" == "--quiet" || "$_psa" == "-q" ]]; then _CMDR_QUIET=1
        elif [[ "$_psa" != --* && "$_psa" != -* ]]; then break
        fi
    done
}
