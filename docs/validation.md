# Validation

cmdr includes a Laravel-style validation system for checking values and for wrapping interactive [input](input.md) prompts so they loop until a valid value is provided.

The validator is a lazy module. Call `cmdr::use cmdr::validator` at the top of any implementation file that uses it directly. When using the input-function path (see below), it is initialized automatically.

```bash
cmdr::use cmdr::validator
```

## Validating a value

Pass a pipe-separated rule string (or a named group) and a value to `cmdr::validator::validate`:

```bash
cmdr::validator::validate "required|email|max:255" "$email"
```

Returns `0` on success, `1` on failure, and prints each failed rule's error message to stderr.

## Creating named validator groups

For rules you reuse across commands, register them as a named group with `cmdr::validator::create`:

```bash
cmdr::validator::create email_rules    "required|email|max:255"
cmdr::validator::create username_rules "required|alpha_dash|min:3|max:50"

cmdr::validator::validate email_rules "$email"
```

Named groups are interchangeable with raw rule strings — either form works in any `cmdr::validator::validate` call.

## Validating interactive input

When the second argument to `cmdr::validator::validate` is a `cmdr::input::*` function name, the validator calls that function, runs the rules on the result, and re-prompts if validation fails. The input box turns red and displays error messages inline. This loop continues until a valid value is entered.

```bash
cmdr::use cmdr::input

local email
cmdr::validator::validate "required|email" cmdr::input::text email "Enter email:"
```

Any additional arguments after the function name are forwarded to the input function. The first of these is always the variable name the input function writes its result into:

```bash
local username
cmdr::validator::validate username_rules \
    cmdr::input::text username "Enter username:" "" "3-50 characters, letters and dashes only"
```

This works with all input helpers:

```bash
local env
cmdr::validator::validate "required" \
    cmdr::input::select env "Target environment" "" "staging" "production"
```

```bash
local services
cmdr::validator::validate "required" \
    cmdr::input::multiselect services "Services to enable" "" \
    "nginx" "mysql" "redis"
```

`cmdr::input::multiselect` sets the variable to `""` when nothing is selected, so `required` re-prompts until the user picks at least one item.

---

## Built-in rules

### Presence

| Rule | Description |
|---|---|
| `required` | Value must not be empty |

### Strings

| Rule | Description |
|---|---|
| `alpha` | Only letters |
| `alpha_num` | Only letters and numbers |
| `alpha_dash` | Letters, numbers, dashes, and underscores |
| `uppercase` | All alphabetic characters must be uppercase |
| `lowercase` | All alphabetic characters must be lowercase |
| `ucfirst` | Must start with an uppercase letter |
| `starts_with:<a,b>` | Must start with one of the comma-separated values |
| `ends_with:<a,b>` | Must end with one of the comma-separated values |
| `ascii` | Only printable ASCII characters |
| `snake_case` | Lowercase letters, numbers, and underscores; must start with a letter |
| `kebab_case` | Lowercase letters, numbers, and hyphens; must start with a letter |
| `regex:<pattern>` | Value must match the given regex pattern |

### Numbers

| Rule | Description |
|---|---|
| `numeric` | Integer or decimal number |
| `integer` | Whole number only (no decimals) |
| `positive` | Number greater than zero |
| `negative` | Number less than zero |
| `multiple_of:<n>` | Must be a multiple of n |
| `digits:<n>` | Must be exactly n digits (unsigned integers only) |
| `digits_between:<min,max>` | Digit count must be between min and max |
| `decimal:<n>` | Must be a decimal number with exactly n decimal places |
| `decimal:<min,max>` | Must be a decimal number with between min and max decimal places |
| `min:<n>` | For numbers: value ≥ n; for strings: at least n characters; for arrays: at least n items |
| `max:<n>` | For numbers: value ≤ n; for strings: at most n characters; for arrays: at most n items |
| `size:<n>` | For numbers: exact value; for strings: exact character count; for arrays: exact item count |
| `between:<min,max>` | For numbers: value within range; for strings: length within range; for arrays: item count within range |

The `min`, `max`, `size`, and `between` rules automatically detect the value type: numeric values are compared directly, comma-separated arrays (such as those from `cmdr::input::multiselect`) have their item count compared, and all other strings have their character length compared.

### Collections

| Rule | Description |
|---|---|
| `in:<a,b,c>` | Value must be one of the comma-separated options |
| `not_in:<a,b,c>` | Value must not be any of the comma-separated options |

### Passwords

| Rule | Description |
|---|---|
| `has_uppercase` | Contains at least one uppercase letter |
| `has_lowercase` | Contains at least one lowercase letter |
| `has_numbers` | Contains at least one digit |
| `has_symbols` | Contains at least one non-alphanumeric character |
| `mixed_case` | Contains both uppercase and lowercase letters |
| `password` | Combines `has_uppercase`, `has_lowercase`, `has_numbers`, and `has_symbols` — all failures reported at once |

The `password` rule is a compound rule: it runs all four character-class checks and emits every failure as a separate error message, so the user sees the full list of unmet requirements at once.

```bash
local secret
cmdr::validator::validate "required|min:8|password" \
    cmdr::input::password secret "Password:"
```

### Formats

| Rule | Description |
|---|---|
| `email` | Basic email format |
| `url` | Must start with `http://` or `https://` |
| `uuid` | Valid UUID (e.g. `550e8400-e29b-41d4-a716-446655440000`) |
| `hex_color` | Valid hex colour (`#RGB` or `#RRGGBB`) |
| `mac_address` | Valid MAC address (colon or hyphen separated) |
| `semver` | Semantic version: `1.2.3`, optionally with pre-release/build metadata |
| `ip` | Valid IPv4 address (alias for `ipv4`) |
| `ipv4` | Valid IPv4 address |
| `ipv6` | Valid IPv6 address (full, compressed `::`, and IPv4-mapped forms) |
| `hostname` | Valid hostname (RFC 1123) |
| `port` | Integer between 1 and 65535 |

### Filesystem

| Rule | Description |
|---|---|
| `file_exists` | Path must point to an existing file |
| `dir_exists` | Path must point to an existing directory |
| `writable` | Path must be writable |
| `not_exists` | Path must not already exist |
| `extension:<ext>` | File must have the given extension (e.g. `extension:sh` or `extension:.sh`) |

---

## Writing custom rules

Define a function named `cmdr::validator::rule::<name>` in a `.sh` file inside a `rules/` directory in your module. All `.sh` files inside `rules/` are sourced automatically when your module calls `cmdr::use cmdr::validator`.

Use `cmdr::validator::fail` to fail a rule with an error message. The function receives the value as `$1` and an optional parameter as `$2` (for parameterised rules like `min_words:3`):

```bash
# mymodule/rules/custom.sh

cmdr::validator::rule::starts_uppercase() {
    [[ "$1" =~ ^[A-Z] ]] || cmdr::validator::fail 'It must start with an uppercase letter.'
}
```

`cmdr::validator::fail` prints the error message and returns `1`. When called with `||`, execution continues after it — so a rule that checks multiple conditions can call it more than once, and each failure is reported.

Then use it like any built-in rule:

```bash
cmdr::validator::validate "required|starts_uppercase" "$value"
```

### Writing compound rules

A compound rule runs several checks and reports all failures at once rather than stopping at the first. Call each sub-rule directly and track whether any failed:

```bash
cmdr::validator::rule::surname() {
    local value="$1" _failed=0
    cmdr::validator::rule::min     "$value" 2 || _failed=1
    cmdr::validator::rule::ucfirst "$value"   || _failed=1
    return $_failed
}
```

When a sub-rule fails it calls `cmdr::validator::fail`, which prints its message and returns `1`. The compound rule catches that with `|| _failed=1` and continues to the next check. All messages are captured by the validator and shown as individual errors.

### Adding rules globally

Rules can also be placed in `.sh` files inside a `rules/` directory at any of these locations. They are loaded when the validator is first initialised:

| Location | Scope |
|---|---|
| `src/rules/` (inside the cmdr package) | Shipped rules |
| `~/.cmdr/rules/` | Global rules |
| `.cmdr/rules/` (project root) | Project-local rules |

## Overriding error messages

Replace the default error message for any rule with `cmdr::validator::message`. Use `:param` as a placeholder for the rule's parameter:

```bash
cmdr::validator::message required "This field cannot be empty."
cmdr::validator::message min      "Must be at least :param."
cmdr::validator::message max      "Cannot exceed :param."
```

Message overrides apply globally to all subsequent `validate` calls in the same session.

### Type-scoped overrides

Rules with multiple failure paths can distinguish them with a type — a second argument to `cmdr::validator::fail`. The built-in `min` and `max` rules use `numeric`, `string`, and `array`:

```bash
cmdr::validator::message min.string  "Must be at least :param characters."
cmdr::validator::message min.numeric "Must be at least :param."
cmdr::validator::message min.array   "Select at least :param options."
```

A plain `min` override applies to all paths; a type-scoped override like `min.array` takes precedence over the plain one for that specific path.

To use types in your own rules, pass the type and the rule's parameter to `cmdr::validator::fail`:

```bash
cmdr::validator::rule::between() {
    local value="$1" param="$2"   # param format: "min,max"
    local min="${param%%,*}" max="${param##*,}"
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        (( value >= min && value <= max )) || cmdr::validator::fail "Must be between ${min} and ${max}." numeric "$param"
    else
        local len="${#value}"
        (( len >= min && len <= max )) || cmdr::validator::fail "Must be between ${min} and ${max} characters." string "$param"
    fi
}
```
