# Common utilities shared across core namespaces.

cmdr::common::timestamp() {
    if [[ "${CMDR_TIMESTAMP:-false}" == "true" ]]; then
        printf '[%s] ' "$(date +"${CMDR_TIMESTAMP_FORMAT:-%Y-%m-%d %H:%M:%S}")"
    fi
}

cmdr::common::elapsed() {
    local s="$1"
    if (( s == 0 )); then
        printf '0.1s'
    elif (( s < 60 )); then
        printf '%ds' "$s"
    elif (( s < 3600 )); then
        printf '%dm %ds' "$(( s / 60 ))" "$(( s % 60 ))"
    else
        printf '%dh %dm' "$(( s / 3600 ))" "$(( (s % 3600) / 60 ))"
    fi
}

