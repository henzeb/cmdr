# JSON utilities

cmdr ships a small pure-awk JSON helper for reading values out of well-formed JSON files without requiring `jq` or any other external tool.

## Extracting a value

### `cmdr::json::extract`

Reads a JSON file and prints the value at a dot-separated path.

```bash
cmdr::json::extract <file> <path>
```

Output format depends on the value type:

| Value type | Output |
|---|---|
| String | The raw string value |
| Array of strings | One item per line |
| Object (string values) | `key:value` per line |

**Reading a scalar:**

```bash
name="$(cmdr::json::extract composer.json name)"
# → acme/my-package
```

**Reading an array:**

```bash
while IFS= read -r path; do
    echo "hook: $path"
done < <(cmdr::json::extract composer.json "extra.cmdr.hooks")
```

**Reading an object:**

```bash
while IFS= read -r entry; do
    module="${entry%%:*}"
    path="${entry#*:}"
    echo "$module → $path"
done < <(cmdr::json::extract composer.json "extra.cmdr.modules")
```

---

## Limitations

`cmdr::json::extract` is designed for multi-line formatted JSON such as `composer.json`. A few edge cases are not handled:

- **Single-line objects or arrays** — `"hooks": ["path"]` on one line is not extracted; values must each be on their own line.
- **Nested structures inside the target block** — only string-valued keys and string array items are extracted. Objects or arrays nested inside the target are silently ignored.
- **Non-string values** — numbers, booleans, and `null` are not extracted.

These constraints hold for all Composer-generated files.
