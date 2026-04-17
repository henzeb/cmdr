# docs

Use this skill when adding or updating documentation in `docs/`.

## What to do

1. Make the requested documentation change.
2. **Update `README.md`** — the Documentation section contains a hand-maintained TOC that links to every `docs/*.md` file and its sections. After any change that adds, removes, or renames a section heading, update the TOC to match. Use the exact anchor format GitHub generates: lowercase, spaces become `-`, punctuation stripped.
3. If you create a new `docs/*.md` file, add it to the TOC in the right place (grouped by topic, consistent with the existing order).

## Tone of voice

Write for a developer configuring or extending cmdr — someone who knows Bash and wants to get things done, not read a spec.

- **Second-person, active voice.** Address the reader as "you". Prefer "Register a listener with..." over "A listener can be registered by calling...".
- **Lead with purpose.** Open each section with what it's for before showing the API. One sentence is enough.
- **Section headers as tasks.** Use imperative or gerund: "Listen for a hook", "Declare your arguments". Not bare nouns like "Declaring".
- **Tables for lookup only.** Keep syntax reference tables. Replace parameter-list tables that just restate prose with a labeled code example or a short sentence.
- **Short context sentences, not walls of prose.** Earn the code block with one sentence, then show the example.
- **Fewer horizontal rules.** Use `---` only for major topic breaks, not between every subsection.

## Examples

Every code example that shows a cmdr invocation must be a full command starting with `cmdr`:

```bash
# correct
cmdr docker start

# wrong
docker start
```

This applies to inline code in prose as well: write `cmdr greet hello`, not `greet hello`.
