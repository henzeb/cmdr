# JSON utilities — pure awk value extraction from well-formed JSON files.

# cmdr::json::extract <file> <path>
#
# Reads <file> and prints the value found at the dot-separated <path>.
#
# Output format:
#   string  → the raw string value
#   array   → one string item per line
#   object  → "key:value" per line (string-valued keys only)
#
# Designed for multi-line formatted JSON (e.g. composer.json). Each key and
# its opening brace/bracket must be on the same line; values inside the target
# block must be on separate lines. Single-line objects or arrays and
# non-string values inside the target are not extracted.
cmdr::json::extract() {
    local file="$1"
    local path="$2"
    [[ -f "$file" ]] || return 1
    awk -v path="$path" '
    BEGIN {
        n      = split(path, segs, ".")
        seg    = 1
        depth  = 0
        in_tgt = 0
        tgt_d  = 0
        done   = 0
    }
    done { exit }
    {
        depth_start = depth

        # Strip quoted strings before counting structural characters so that
        # braces or brackets inside string values do not affect depth tracking.
        stripped = $0
        gsub(/"[^"]*"/, "X", stripped)
        for (i = 1; i <= length(stripped); i++) {
            c = substr(stripped, i, 1)
            if      (c == "{" || c == "[") depth++
            else if (c == "}" || c == "]") depth--
        }

        # Navigate: look for segs[seg] at depth_start == seg (1-indexed).
        # Each matched segment increments seg, so we follow the exact path
        # rather than matching the same key name at the wrong nesting level.
        if (!in_tgt && !done && seg <= n \
                && depth_start == seg \
                && $0 ~ ("\"" segs[seg] "\"[[:space:]]*:")) {
            if (seg == n) {
                in_tgt = 1
                tgt_d  = seg
                # Inline string value: "key": "value"
                rest = $0
                sub(/^[^:]*:[[:space:]]*/, "", rest)
                if (rest ~ /^"[^"]*"/) {
                    v = rest
                    sub(/^"/, "", v)
                    sub(/".*/, "", v)
                    print v
                    in_tgt = 0
                    done   = 1
                }
            } else {
                seg++
            }
        }

        # Extract values at exactly one level inside the target block.
        if (in_tgt && depth_start == tgt_d + 1) {
            if ($0 ~ /"[^"]+":[ \t]*"[^"]+"/) {
                # Object entry: "key": "value"  →  key:value
                k = $0; sub(/^[^"]*"/,         "", k); sub(/".*/, "", k)
                v = $0; sub(/^[^"]*"[^"]*"[^"]*"/, "", v); sub(/".*/, "", v)
                print k ":" v
            } else if ($0 ~ /"[^"]+"/) {
                # Array item or bare string
                v = $0
                sub(/^[^"]*"/, "", v)
                sub(/".*/, "", v)
                print v
            }
        }

        # Leave target block when depth drops back to target level.
        if (in_tgt && depth <= tgt_d) { in_tgt = 0; done = 1 }
    }
    ' "$file"
}
