# Init module — scaffold a .cmdr/ directory with a default .config.


# config
cmdr::register::command init config::init "Initializes cmdr in the current project"
cmdr::register::lock init

cmdr::args::define init \
    "{--force|-f : Overwrite an existing .config}" \
    "{--global|-g : Initialize globally in ~/.cmdr/ instead of the project}"

# alias
cmdr::register::command alias config::alias "Initializes cmdr in the current project"
cmdr::register::lock alias

cmdr::args::define alias \
    "{name? : alias to call this project}"

# aliases
cmdr::register::command aliases config::aliases "Lists all cmdr project aliases"
cmdr::register::lock aliases

# unalias
cmdr::register::command unalias config::unalias "Removes a cmdr project alias from your shell config"
cmdr::register::lock unalias

cmdr::args::define unalias \
    "{name? : alias to remove}"
