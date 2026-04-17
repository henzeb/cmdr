# Common utilities shared across core namespaces.

cmdr::common::timestamp() {
    if [[ "${CMDR_TIMESTAMP:-false}" == "true" ]]; then
        printf '[%s] ' "$(date +"${CMDR_TIMESTAMP_FORMAT:-%Y-%m-%d %H:%M:%S}")"
    fi
}

