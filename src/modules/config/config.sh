config::init() {
    cmdr::hook::run cmdr.initializing
    local force global
    force=$(cmdr::args::get_option force)
    global=$(cmdr::args::get_option global)

    local config_dir
    if [[ -n "$global" ]]; then
        config_dir="${HOME}/.cmdr"
    else
        local root
        root="$(cmdr::loader::find_project_root)"
        config_dir="$root/.cmdr"
    fi

    local config_file="$config_dir/.config"

    local template="$_CMDR_SELF_DIR/../.config"

    if [[ -f "$config_file" ]] && [[ -z "$force" ]]; then
        local appended=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            local param="${line%%=*}"
            if ! grep -qE "^${param}=" "$config_file" 2>/dev/null; then
                printf '\n%s' "$line" >> "$config_file"
                cmdr::output::info "Appended ${param} to ${config_file}"
                appended=1
            fi
        done < "$template"
        if [[ "$appended" -eq 0 ]]; then
            cmdr::output::info "${config_file} is already up to date"
        else
            cmdr::output::info "${config_file} is already up to date"
            cmdr::hook::run cmdr.initialized
        fi
        return 0
    fi

    mkdir -p "$config_dir"
    cp "$template" "$config_file"

    cmdr::output::info "Created ${config_file}"
    cmdr::hook::run cmdr.initialized
}

config::alias() {
    cmdr::use cmdr::shell
    cmdr::use cmdr::input
    cmdr::use cmdr::validator
    local alias_name
    alias_name=$(cmdr::args::get name)

    if [[ -z "$alias_name" ]]; then
        cmdr::validator::validate "required|alias_not_exists" \
            cmdr::input::text alias_name "Alias name:"
    fi

    local root
    root="$(cmdr::loader::find_project_root)"

    local bin_ref
    if cmdr::shell::command_exists "$alias_name"; then
        cmdr::input::confirm "$alias_name exists already. Create a project alias anyway?" n \
            || return 0
        bin_ref="cmdr"
    else
        bin_ref="${_CMDR_SELF_DIR}/cmdr"
    fi

    local line="alias ${alias_name}=\"${bin_ref} --root ${root}\""

    if cmdr::shell::line_exists "alias ${alias_name}="; then
        cmdr::output::success "Alias '${alias_name}' is already defined in your shell config."
    fi

    cmdr::shell::write "$line"
}

config::aliases() {
    cmdr::use cmdr::shell

    local rc
    rc=$(_cmdr_shell_rc_file)

    if [[ -z "$rc" ]] || [[ ! -f "$rc" ]]; then
        cmdr::output::info "No shell config found."
        return 0
    fi

    local found=0
    while IFS= read -r line; do
        if [[ "$line" == *cmdr\ --root* ]]; then
            printf '%s\n' "$line"
            found=1
        fi
    done < "$rc"

    if [[ "$found" -eq 0 ]]; then
        cmdr::output::info "No cmdr aliases found in ${rc}."
    fi
}

config::unalias() {
    cmdr::use cmdr::shell
    local alias_name
    alias_name=$(cmdr::args::get name)

    if [[ -z "$alias_name" ]]; then
        local rc
        rc=$(_cmdr_shell_rc_file)

        if [[ -z "$rc" ]] || [[ ! -f "$rc" ]]; then
            cmdr::output::info "No shell config found."
            return 0
        fi

        local alias_names=()
        while IFS= read -r line; do
            if [[ "$line" == *cmdr\ --root* ]]; then
                local _n="${line#alias }"
                _n="${_n%%=*}"
                alias_names+=("$_n")
            fi
        done < "$rc"

        if [[ "${#alias_names[@]}" -eq 0 ]]; then
            cmdr::output::info "No cmdr aliases found in ${rc}."
            return 0
        fi

        cmdr::use cmdr::input
        cmdr::use cmdr::validator

        local selected
        cmdr::validator::validate "required" cmdr::input::multiselect \
            selected "Select aliases to remove:" "" "${alias_names[@]}"

        for alias_name in "${alias_names[@]}"; do
            [[ ",$selected," == *",$alias_name,"* ]] || continue
            cmdr::shell::remove_line "alias ${alias_name}="
            cmdr::output::info "Removed alias '${alias_name}'."
        done
        cmdr::output::info "Reload with: source ${rc}"
        return 0
    fi

    local pattern="alias ${alias_name}="

    if ! cmdr::shell::line_exists "$pattern"; then
        cmdr::output::info "No alias '${alias_name}' found in your shell config."
        return 0
    fi

    cmdr::shell::remove_line "$pattern"

    local rc
    rc=$(_cmdr_shell_rc_file)
    cmdr::output::success "Removed alias '${alias_name}'. Reload with: source ${rc}"
}
