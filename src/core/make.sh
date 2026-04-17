# cmdr::make — scaffold generation core.
# Loaded lazily via: cmdr::use cmdr::make

# ---------------------------------------------------------------------------
# _cmdr_make_find_file <relative_path>
#
# Echoes the absolute path of a scaffold file by searching in priority order:
#   <project>/.cmdr/scaffolds/<relative_path>
#   ~/.cmdr/scaffolds/<relative_path>
#   <cmdr_install>/scaffolds/<relative_path>
#
# Returns 1 if not found in any location.
# ---------------------------------------------------------------------------
_cmdr_make_find_file() {
    local rel="$1"
    local _root
    _root="$(cmdr::loader::find_project_root 2>/dev/null || true)"

    local type="${rel%%/*}"
    local module_dir="${_CMDR_MAKE_MODULE_DIRS[$type]:-}"

    local candidate
    for candidate in \
        "${_root:+${_root}/.cmdr/scaffolds/${rel}}" \
        "${module_dir:+${module_dir}/scaffolds/${rel}}" \
        "${HOME}/.cmdr/scaffolds/${rel}" \
        "${_CMDR_SELF_DIR}/../scaffolds/${rel}"
    do
        [[ -z "$candidate" ]] && continue
        [[ -f "$candidate" ]] && { echo "$candidate"; return 0; }
    done
    return 1
}

# ---------------------------------------------------------------------------
# _cmdr_make_find_scaffold_dir <type>
#
# Echoes the path of the first scaffold directory found for <type>.
# Returns 1 if not found.
# ---------------------------------------------------------------------------
_cmdr_make_find_scaffold_dir() {
    local type="$1"
    local _root
    _root="$(cmdr::loader::find_project_root 2>/dev/null || true)"

    local module_dir="${_CMDR_MAKE_MODULE_DIRS[$type]:-}"

    local candidate
    for candidate in \
        "${_root:+${_root}/.cmdr/scaffolds/${type}}" \
        "${HOME}/.cmdr/scaffolds/${type}" \
        "${module_dir:+${module_dir}/scaffolds/${type}}" \
        "${_CMDR_SELF_DIR}/../scaffolds/${type}"
    do
        [[ -z "$candidate" ]] && continue
        [[ -d "$candidate" ]] && { echo "$candidate"; return 0; }
    done
    return 1
}

# ---------------------------------------------------------------------------
# _cmdr_make_substitute <src_file> <dest_file>
#
# Copies <src_file> to <dest_file>, substituting every {{VARNAME}} placeholder
# with the value of $VARNAME from the calling scope (bash dynamic scoping).
# Lines consisting solely of a {{VARNAME}} that resolves to empty are deleted.
# ---------------------------------------------------------------------------
_cmdr_make_substitute() {
    local src="$1"
    local dest="$2"

    local vars=()
    while IFS= read -r var; do
        vars+=("$var")
    done < <(grep -oE '[{][{][A-Z_]+[}][}]' "$src" | grep -oE '[A-Z_]+' | sort -u)

    if [[ ${#vars[@]} -eq 0 ]]; then
        cp "$src" "$dest"
        return
    fi

    local sed_args=() var val
    for var in "${vars[@]}"; do
        val="${!var:-}"
        # Line consisting only of {{VAR}} with empty value → delete the line
        sed_args+=(-e "/^[[:space:]]*[{][{]${var}[}][}][[:space:]]*\$/{s|[{][{]${var}[}][}]|${val}|;/^[[:space:]]*\$/d;}")
        # All remaining occurrences → substitute
        sed_args+=(-e "s|[{][{]${var}[}][}]|${val}|g")
    done

    sed "${sed_args[@]}" "$src" > "$dest"
}

# ---------------------------------------------------------------------------
# cmdr::make::copy <scaffold/relative/path> <target_path>
#
# Copies a single scaffold file to <target_path>, substituting {{VARNAME}}
# placeholders with variables from the calling scope. The source is resolved
# by scanning scaffold directories (project → user → shipped).
#
# Example:
#   local NAME="mymod" LOCK="cmdr::register::lock mymod" HIDE=""
#   cmdr::make::copy module/main.sh "${target_dir}/main.sh"
# ---------------------------------------------------------------------------
cmdr::make::copy() {
    local rel="$1"
    local dest="$2"

    local src
    src="$(_cmdr_make_find_file "$rel")" || \
        cmdr::output::fail "Scaffold file not found: ${rel}"

    _cmdr_make_substitute "$src" "$dest"
}

# ---------------------------------------------------------------------------
# cmdr::make::generate <type> <target_dir>
#
# Copies all files from a scaffold type directory to <target_dir>, applying
# {{VARNAME}} substitution to both file contents and filenames.
# Scaffold directories are scanned in priority order: project → user → shipped.
#
# Example:
#   local NAME="mymod"
#   cmdr::make::generate mytype "${HOME}/.cmdr/mymod"
# ---------------------------------------------------------------------------
cmdr::make::generate() {
    local type="$1"
    local target_dir="$2"

    local scaffold_dir
    scaffold_dir="$(_cmdr_make_find_scaffold_dir "$type")" || \
        cmdr::output::fail "No scaffold found for type '${type}'."

    mkdir -p "$target_dir"

    local src_file src_filename dest_filename var val
    for src_file in "${scaffold_dir}/"*; do
        [[ -f "$src_file" ]] || continue
        src_filename="${src_file##*/}"

        # Apply {{VARNAME}} substitution to the filename
        dest_filename="$src_filename"
        while [[ "$dest_filename" =~ [{][{]([A-Z_]+)[}][}] ]]; do
            var="${BASH_REMATCH[1]}"
            val="${!var:-}"
            dest_filename="${dest_filename/\{\{${var}\}\}/${val}}"
        done

        _cmdr_make_substitute "$src_file" "${target_dir}/${dest_filename}"
    done
}
