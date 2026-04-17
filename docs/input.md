# Input

cmdr includes a set of styled interactive prompt helpers inspired by Laravel Prompts. Each helper draws a box in the terminal, handles keyboard navigation, and stores the result in a variable.

All input helpers are part of the lazy `cmdr::input` module. Call `cmdr::use cmdr::input` at the top of any implementation file that uses them.

```bash
cmdr::use cmdr::input
```

---

## Prompt helpers

### `cmdr::input::text`

Free-form text input. Supports cursor movement, editing, and horizontal scrolling for long values.

Pass the variable to write into, the prompt label, an optional default, and an optional hint.

```bash
cmdr::input::text <varname> <prompt> [default] [description]
```

```bash
local name
cmdr::input::text name "Your name" "World" "Used in the greeting"
echo "Hello, $name!"
```

### `cmdr::input::password`

Masked text input. Characters are echoed as `*` and the summary line shows asterisks instead of the actual value.

```bash
cmdr::input::password <varname> <prompt> [description]
```

```bash
local secret
cmdr::input::password secret "Password:" "At least 8 characters"
```

Works with `cmdr::validator::validate` the same way `cmdr::input::text` does — the box turns red and displays errors inline on re-prompt.

### `cmdr::input::confirm`

A yes/no prompt. Returns `0` for yes and `1` for no.

Pass a question, an optional default (`y` or `n`, defaults to `n`), and an optional hint.

```bash
cmdr::input::confirm <prompt> [default=n] [description]
```

```bash
if cmdr::input::confirm "Delete all files?" n "This cannot be undone"; then
    rm -rf ./build
fi
```

### `cmdr::input::select`

A single-choice list. The user navigates with arrow keys and confirms with Enter.

Pass the variable to write into, the prompt label, a hint (or `""` to skip), then the options.

```bash
cmdr::input::select <varname> <prompt> <description> <option>...
```

```bash
local env
cmdr::input::select env "Target environment" "Where to deploy" \
    "staging" "production" "local"
cmdr::output::info "Deploying to: $env"
```

### `cmdr::input::multiselect`

A multiple-choice list. Navigate with `↑`/`↓`, toggle the current item with `Space`, select all with `a`, clear all with `n`, and confirm with `Enter`. The result is a comma-separated string, or `""` if nothing was selected.

Pass the variable to write into, the prompt label, a hint (or `""` to skip), then the options.

```bash
cmdr::input::multiselect <varname> <prompt> <description> <option>...
```

```bash
local services
cmdr::input::multiselect services "Services to start" "" \
    "nginx" "mysql" "redis" "worker"
cmdr::output::info "Starting: $services"
# e.g. "nginx, redis, worker"
```

To require at least one selection, wrap it with `cmdr::validator::validate "required"` — an empty result fails the `required` rule and re-prompts automatically. See [Validating input helpers](validation.md#validating-input-helpers).

### `cmdr::input::pause`

Waits for the user to press any key, or automatically continues after a countdown.

Pass an optional message, an optional hint, and an optional auto-continue timeout in seconds.

```bash
cmdr::input::pause [message] [description] [seconds]
```

```bash
cmdr::input::pause "Ready to deploy"
cmdr::input::pause "Deploying in..." "" 5
```

When `seconds` is given, the box shows a `MM:SS` (or `H:MM:SS`) countdown. Any key skips the countdown and continues immediately.

---

## The description argument

Every helper accepts an optional `description` argument that renders as gray text inside the prompt box, below the main label. It is useful for usage hints, constraints, or contextual help.

Pass `""` as the description when you need to supply a later positional argument (such as `seconds`) without providing a description:

```bash
cmdr::input::pause "Continuing..." "" 10
```

## Using input with validation

Input helpers integrate with the validation system. Pass a `cmdr::input::*` function as the second argument to `cmdr::validator::validate` and the prompt will loop until the value satisfies all rules. The box turns red and displays the error messages inline.

```bash
cmdr::use cmdr::input

local email
cmdr::validator::validate "required|email" \
    cmdr::input::text email "Email address" "" "Must be a valid address"
```

See [Validation](validation.md) for the full rule reference.
