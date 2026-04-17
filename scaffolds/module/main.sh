cmdr::register::module {{NAME}}
{{LOCK}}
{{HIDE}}

cmdr::register::help {{NAME}} example "An example command"

cmdr::args::define {{NAME}}::example \
    "{greeting=Hello : Greeting to use}" \
    "{--shout|-s : Print in uppercase}"
