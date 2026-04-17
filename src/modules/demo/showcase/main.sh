cmdr::register::alias showcase sc demo
cmdr::register::help demo showcase        "Showcase submodule demonstrating advanced cmdr features"
cmdr::register::help demo::showcase args  "Demonstrate argument and option declaration"
cmdr::register::help demo::showcase alias "Show all registered aliases"

cmdr::args::define demo::showcase::args \
    "{name=World : Name to greet}" \
    "{--shout|-s : Print in uppercase}" \
    "{--times|-t=1 : How many times to repeat}"

cmdr::register::lock showcase
