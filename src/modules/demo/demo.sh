cmdr::use cmdr::input
cmdr::use cmdr::validator

demo::run() {
    cmdr::output::info "=== cmdr demo ==="
    echo ""

    local sections
    cmdr::validator::validate "required" \
        cmdr::input::multiselect sections "Which features would you like to explore?" "Space to toggle, Enter to confirm" \
        "Output helpers" \
        "Progress bar" \
        "Task list" \
        "Text & password input" \
        "Confirm prompt" \
        "Select & multiselect" \
        "Pause"

    if [[ "$sections" == *"Output helpers"* ]]; then
        echo ""
        cmdr::output::info "=== Output helpers ==="
        echo ""
        cmdr::output::info    "  cmdr::output::info    — informational messages"
        cmdr::output::warning "  cmdr::output::warning — non-fatal warnings"
        cmdr::output::error   "  cmdr::output::error   — error messages (stderr)"
        cmdr::output::success "  cmdr::output::success — success message"
        echo ""
        cmdr::input::pause "" "" 3
    fi

    if [[ "$sections" == *"Progress bar"* ]]; then
        echo ""
        demo::output::progressbar
    fi

    if [[ "$sections" == *"Task list"* ]]; then
        echo ""
        demo::output::tasks
    fi

    if [[ "$sections" == *"Text & password input"* ]]; then
        echo ""
        demo::input::text
    fi

    if [[ "$sections" == *"Confirm prompt"* ]]; then
        echo ""
        demo::input::confirm
    fi

    if [[ "$sections" == *"Select & multiselect"* ]]; then
        echo ""
        demo::input::select
    fi

    if [[ "$sections" == *"Pause"* ]]; then
        echo ""
        demo::input::pause
    fi

    cmdr::output::info "=== demo complete ==="
}

demo::greet() {
    local name shout no_color
    name=$(cmdr::args::get name "World")
    shout=$(cmdr::args::get_option shout)
    no_color=$(cmdr::args::get_option no-color)

    local msg="Hello, ${name}!"
    [[ -n "$shout" ]] && msg="${msg^^}"

    if [[ -n "$no_color" ]]; then
        echo "$msg"
    else
        cmdr::output::info "$msg"
    fi

    if [[ ${#_CMDR_PASSTHROUGH[@]} -gt 0 ]]; then
        cmdr::output::info "Passthrough: ${_CMDR_PASSTHROUGH[*]}"
        "${_CMDR_PASSTHROUGH[@]}"
    fi
}

demo::input::text() {
    cmdr::output::info "=== Text & password input ==="
    echo ""

    cmdr::output::info "1. cmdr::input::text — free-form text with validation"
    cmdr::output::info "   Custom rule: no_spaces (defined in demo/rules/no_spaces.sh)"
    local project
    cmdr::validator::validate "required|min:2|no_spaces" \
        cmdr::input::text project "Project name:" "" "No spaces — use hyphens or underscores"
    cmdr::output::info "  Got: $project"
    echo ""

    cmdr::output::info "2. cmdr::input::password — masked input with validation"
    local secret
    cmdr::validator::validate "required|min:8|password" \
        cmdr::input::password secret "Password:" "Must contain uppercase, lowercase, number, and symbol"
    cmdr::output::info "  Got: $secret"
    echo ""
}

demo::input::confirm() {
    cmdr::output::info "=== Confirm prompt ==="
    echo ""

    cmdr::output::info "cmdr::input::confirm — yes/no prompt (default: yes)"
    if cmdr::input::confirm "Looks good?" y "Press y or n"; then
        cmdr::output::info "  Got: Yes"
    else
        cmdr::output::info "  Got: No"
    fi
    echo ""
}

demo::input::select() {
    cmdr::output::info "=== Select & multiselect ==="
    echo ""

    cmdr::output::info "1. cmdr::input::select — pick one from a list"
    local env
    cmdr::input::select env "Target environment:" "Where to deploy" \
        development staging production
    cmdr::output::info "  Got: $env"
    echo ""

    cmdr::output::info "2. cmdr::input::multiselect — pick any number (a=all, n=none, space=toggle)"
    local features
    cmdr::input::multiselect features "Enable features:" "Pick any combination" \
        redis postgres nginx queue scheduler
    cmdr::output::info "  Got: $features"
    echo ""
}

demo::input::pause() {
    cmdr::output::info "=== Pause ==="
    echo ""

    cmdr::output::info "1. cmdr::input::pause — wait for any key before continuing"
    cmdr::input::pause "Review the output above, then press any key." "Take your time"

    cmdr::output::info "2. cmdr::input::pause with countdown — auto-continues, any key skips"
    cmdr::input::pause "Continuing in..." "Auto-continues after countdown" 5
    echo ""
}

demo::output::progressbar() {
    cmdr::output::info "=== Progress bar ==="
    echo ""

    cmdr::output::info "cmdr::output::progressbar — in-place progress bar"
    echo ""

    local steps=10 i
    cmdr::output::progressbar "Building" "$steps"
    for (( i = 1; i <= steps; i++ )); do
        if (( i == 5 )); then
            sleep 1.2
        else
            sleep 0.3
        fi
        cmdr::output::progressbar::advance 1 "Step $i of $steps"
    done
    cmdr::output::progressbar::clear
    cmdr::output::info "  Build complete."
    echo ""
}

demo::output::tasks() {
    cmdr::output::info "=== Task list ==="
    echo ""
    cmdr::output::info "cmdr::output::tasks::* — grouped, in-place task tracker"

    cmdr::output::tasks::add "deploy" "Build frontend" "Compile assets"
    cmdr::output::tasks::add "deploy" "Run tests"      "Integration tests"
    cmdr::output::tasks::add "deploy" "Deploy"         "Production push"

    cmdr::output::tasks::add "notify" "Slack"          "Post to #deploys"
    cmdr::output::tasks::add "notify" "Email"          "Send release notes"

    sleep 0.5
    cmdr::output::tasks::processing "deploy" "Build frontend"
    local i
    for (( i = 0; i < 10; i++ )); do sleep 0.12; cmdr::output::tasks::tick; done
    cmdr::output::tasks::done "deploy" "Build frontend"

    sleep 0.3
    cmdr::output::tasks::processing "deploy" "Run tests"
    for (( i = 0; i < 12; i++ )); do sleep 0.1; cmdr::output::tasks::tick; done
    cmdr::output::tasks::done "deploy" "Run tests"

    sleep 0.3
    cmdr::output::tasks::processing "deploy" "Deploy"
    for (( i = 0; i < 8; i++ )); do sleep 0.15; cmdr::output::tasks::tick; done
    cmdr::output::tasks::failed "deploy" "Deploy"

    sleep 0.3
    cmdr::output::tasks::canceled "notify" "Slack"
    cmdr::output::tasks::canceled "notify" "Email"

    cmdr::input::pause "Continuing in..." "" 5
    cmdr::output::tasks::clear
    cmdr::output::info "  Task list cleared."
    echo ""
}

demo::fail() {
    cmdr::output::error "This is what a failure looks like."
    return 1
}
