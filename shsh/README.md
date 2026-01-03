## shsh

`shsh` is a small Node.js CLI that turns a natural-language request into a single shell command using Anthropic’s API, shows you the generated command, and (optionally) executes it after confirmation.

### What it does

- Takes your prompt from the command line arguments (e.g. `shsh "find large files"`).
- Sends it to Anthropic (`@anthropic-ai/sdk`) with a strict system prompt that asks for:
  - **Only** the shell command (no explanation/markdown).
  - A command suitable for your current OS (`os.platform()`).
  - A command intended to run in the current working directory (`process.cwd()`).
- Prints the generated command.
- Prompts: `Execute? (y/n/r):`
  - `y` / `yes`: runs the command via your `$SHELL -c <command>` (falls back to `/bin/sh`), inheriting stdio.
  - `n`: aborts without running anything.
  - `r` / `retry`: generates a new command again.

### Requirements

- Node.js installed
- An Anthropic API key, either:
  - Environment variable: `export ANTHROPIC_API_KEY="sk-ant-..."`
  - Config file: `~/.config/shsh/config.json` with `{"apiKey": "sk-ant-..."}`
  - (Config file takes precedence)

### Install

From the `shsh/` directory:

```sh
npm install
```

To make `shsh` available on your PATH during development:

```sh
npm link
```

Alternatively, install it globally from this folder:

```sh
npm install -g .
```

### Usage

After linking (or after installing this package globally), run from the directory you want the command to execute in:

```sh
export ANTHROPIC_API_KEY="..."
shsh "describe what you want to do"
```

You can also run it without linking by calling the script directly:

```sh
/path/to/helpers/shsh/shsh.js "describe what you want to do"
```

### Flags

- `--yes, -y`: Auto-execute without confirmation (skips the y/n/r prompt)
- `--print, -p`: Print command only, don't execute (useful for piping)
- `--init <shell>`: Generate shell integration code for `zsh` or `bash`

### Shell Integration

Add executed commands to your shell history automatically:

```sh
# For Zsh (add to ~/.zshrc)
eval "$(shsh --init zsh)"

# For Bash (add to ~/.bashrc)
eval "$(shsh --init bash)"
```

This creates a shell wrapper that integrates with your history and enables retry support.

### Stdin Support

Pipe data to shsh for processing:

```sh
cat error.log | shsh "find the error"
shsh "find large files" | shsh "count lines"
echo "file1\nfile2" | shsh --yes "delete these files"
```

Large inputs are automatically summarized before sending to the API.

### Testing

Run the test suite:

```sh
npm test
```

### Notes / Safety

- The generated command is executed in your current directory (`process.cwd()`), not necessarily in the `shsh/` directory.
- `shsh` prints the command before executing; you should review it carefully.
- The `retry` option tells Claude the previous command didn't work and generates an alternative approach.
