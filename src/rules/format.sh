cmdr::validator::rule::email() {
    [[ "$1" =~ ^[^@]+@[^@]+\.[^@]+$ ]] || cmdr::validator::fail 'It must be a valid email address.'
}

cmdr::validator::rule::url() {
    [[ "$1" =~ ^https?://[^[:space:]]+$ ]] || cmdr::validator::fail 'It must be a valid URL.'
}

cmdr::validator::rule::snake_case() {
    [[ "$1" =~ ^[a-z][a-z0-9_]*$ ]] || \
        cmdr::validator::fail 'It may only contain lowercase letters, numbers, and underscores, and must start with a letter.'
}

cmdr::validator::rule::kebab_case() {
    [[ "$1" =~ ^[a-z][a-z0-9-]*$ ]] || \
        cmdr::validator::fail 'It may only contain lowercase letters, numbers, and hyphens, and must start with a letter.'
}

# semver — matches major.minor.patch with optional pre-release and build metadata
cmdr::validator::rule::semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9._-]+)?(\+[a-zA-Z0-9._-]+)?$ ]] || \
        cmdr::validator::fail 'It must be a valid semantic version (e.g. 1.2.3).'
}

cmdr::validator::rule::port() {
    local value="$1"
    if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 1 && value <= 65535 )); then
        return 0
    fi
    cmdr::validator::fail 'It must be a valid port number (1–65535).'
}

cmdr::validator::rule::ip() {
    cmdr::validator::rule::ipv4 "$@"
}

cmdr::validator::rule::ipv4() {
    local value="$1"
    if [[ ! "$value" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        cmdr::validator::fail 'It must be a valid IPv4 address.'
    fi
    local octet
    for octet in "${BASH_REMATCH[@]:1}"; do
        (( octet <= 255 )) || cmdr::validator::fail 'It must be a valid IPv4 address.'
    done
}

# ipv6 — accepts full, compressed (::), and mixed IPv4-mapped forms
cmdr::validator::rule::ipv6() {
    local value="$1"

    # Strip optional brackets (e.g. [::1])
    value="${value#[}"
    value="${value%]}"

    # Must not be empty and may only contain hex digits, colons, and dots (for IPv4-mapped)
    [[ -n "$value" && "$value" =~ ^[0-9a-fA-F:.]+$ ]] || \
        cmdr::validator::fail 'It must be a valid IPv6 address.'

    # No more than one :: occurrence
    local compressed="${value//[^:]}"
    local dcolon_count=0
    [[ "$value" == *::* ]] && dcolon_count=1
    [[ "$value" =~ :::  ]] && { cmdr::validator::fail 'It must be a valid IPv6 address.'; }

    # Split on :: into left and right halves; each half is colon-separated groups
    local left right
    if (( dcolon_count == 1 )); then
        left="${value%%::*}"
        right="${value##*::}"
    else
        left="$value"
        right=""
    fi

    # Count and validate groups on each side
    local -a lgroups rgroups
    local IFS=':'
    [[ -n "$left"  ]] && read -ra lgroups <<< "$left"  || lgroups=()
    [[ -n "$right" ]] && read -ra rgroups <<< "$right" || rgroups=()

    local total_groups=$(( ${#lgroups[@]} + ${#rgroups[@]} ))

    # With ::, total explicit groups must be ≤ 7; without ::, exactly 8
    if (( dcolon_count == 1 )); then
        (( total_groups <= 7 )) || cmdr::validator::fail 'It must be a valid IPv6 address.'
    else
        (( total_groups == 8 )) || cmdr::validator::fail 'It must be a valid IPv6 address.'
    fi

    # Each group must be 1-4 hex digits (or a valid IPv4 address in the last group position)
    local group
    for group in "${lgroups[@]}" "${rgroups[@]}"; do
        if [[ "$group" =~ \. ]]; then
            # IPv4-mapped segment — delegate to ipv4 rule
            cmdr::validator::rule::ipv4 "$group" || \
                cmdr::validator::fail 'It must be a valid IPv6 address.'
        else
            [[ "$group" =~ ^[0-9a-fA-F]{1,4}$ ]] || \
                cmdr::validator::fail 'It must be a valid IPv6 address.'
        fi
    done
}

cmdr::validator::rule::uuid() {
    [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || \
        cmdr::validator::fail 'It must be a valid UUID.'
}

cmdr::validator::rule::hex_color() {
    [[ "$1" =~ ^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$ ]] || \
        cmdr::validator::fail 'It must be a valid hex color (e.g. #FFF or #FFFFFF).'
}

cmdr::validator::rule::mac_address() {
    [[ "$1" =~ ^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$ ]] || \
        cmdr::validator::fail 'It must be a valid MAC address.'
}

cmdr::validator::rule::hostname() {
    local value="$1"
    # Total length must not exceed 253 characters
    (( ${#value} <= 253 )) || cmdr::validator::fail 'It must be a valid hostname.'
    # Each label: 1-63 chars, letters/digits/hyphens, no leading or trailing hyphen
    local IFS='.'
    local -a labels
    read -ra labels <<< "$value"
    (( ${#labels[@]} > 0 )) || cmdr::validator::fail 'It must be a valid hostname.'
    local label
    for label in "${labels[@]}"; do
        [[ -n "$label" && ${#label} -le 63 && "$label" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] || \
            cmdr::validator::fail 'It must be a valid hostname.'
    done
}
