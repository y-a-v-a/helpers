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
- An Anthropic API key in `ANTHROPIC_API_KEY`

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

### Notes / Safety

- The generated command is executed in your current directory (`process.cwd()`), not necessarily in the `shsh/` directory.
- `shsh` prints the command before executing; you should review it carefully.
- The `retry` option regenerates a command, but the current implementation does not incorporate additional “previous attempt failed” context in the prompt.
