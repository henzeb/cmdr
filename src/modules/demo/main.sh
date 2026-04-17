# Demo module — showcases cmdr features. Disable with CMDR_DEMO_DISABLED=true.

[[ "${CMDR_DEMO_DISABLED:-false}" == "true" ]] && return 0

cmdr::register::alias demo dm

cmdr::register::hide demo
cmdr::register::lock demo

cmdr::register::help demo run     "Run a demo walkthrough of cmdr features"
cmdr::register::help demo greet   "Print a greeting (shows argument + option handling)"
cmdr::register::help demo input   "Walk through all interactive input helpers"
cmdr::register::help demo fail    "Demonstrate error output"

cmdr::args::define demo::greet \
    "{name=World : Name to greet}" \
    "{--shout|-s : Print greeting in uppercase}" \
    "{--no-color|-C : Skip colour output}"


