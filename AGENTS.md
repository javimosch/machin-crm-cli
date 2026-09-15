
## Memgraph — Skill Discovery

This project uses [memgraph-cli](https://github.com/javimosch/memgraph-cli) for skill and memory discovery.

**Before starting a task**, run these commands to find relevant skills and context:

```bash
# Get skill recommendations for your current task
memgraph recommend "<your task description>" --json

# Search the skill graph by keyword
memgraph query "<keywords>" --json

# Get skills related to a specific skill
memgraph related "<skill-name>" --json
```

The `--json` flag outputs structured data. Read the "file_path" field to load the full skill content.
Always check `memgraph recommend` first — it ranks skills by relevance and surfaces related skills you might miss by grepping.

