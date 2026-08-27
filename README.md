# AI Panel for Omarchy

A native [Omarchy](https://omarchy.org) shell plugin: a full AI chat sidebar summoned with a keypress. Streaming responses, multiple providers, prompt presets, saved chats — all inside your window manager.

<img width="1366" height="768" alt="screenshot-2026-08-21_14-27-58" src="https://github.com/user-attachments/assets/2f304b1d-aae4-4232-9f0e-92b796c716c0" />

## Features

- **Streaming chat** with token-by-token output and markdown rendering (code blocks, tables, links)
- **Multi-provider** — Gemini, Mistral, DeepSeek, Ollama (local), and more
- **Local agent CLIs** — Claude Code, Cursor Agent and Codex as first-class models, running in a working directory you choose
- **Prompt presets** — ship your own `.md` prompts, switch anytime; built-in placeholders like `{DISTRO}`, `{DE}`, `{DATETIME}`
- **Saved chats** — name, save, and reload conversations
- **Theme-aware** — automatically follows `omarchy theme set`, including light themes
- **Slash commands** for everything
- **RUN /quattro INSIDE PANEL FOR EASTER EGG**

## Install

```bash
omarchy plugin add https://github.com/atif-1402/ai-panel.git --enable
```

Then add a keybind to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + A", "AI Panel", "omarchy-shell shell toggle io.github.atif-1402.ai-panel")
```

Press **SUPER + ALT + A** and you're in.

or 

Run `omarchy-shell shell toggle io.github.atif-1402.ai-panel` in your terminal


## Agent CLIs

Claude Code, Cursor Agent and Codex are picked up automatically when their
binary is on `PATH` — they appear in `/model` as **Claude Code**, **Cursor
Agent** and **Codex**. There is no API key to set: each one uses the login its
CLI already has, so a subscription works exactly as it does in the terminal.

They differ from the HTTP models in three ways worth knowing:

| | Behaviour |
|---|---|
| **Tools** | Each agent brings its own — shell, file edits, search — and decides when to use them. The `/tool` picker is hidden for them. |
| **Working directory** | They run in the directory shown next to the model name, set with `/cwd PATH`. This is where they read and write files. |
| **Memory** | The agent keeps the conversation itself. The first message replays the chat history; after that the panel resumes the agent's own session, so its context and tool results carry over. `/clear`, `/cwd` and regenerating start a fresh session. |

Attachments are passed to agents as a file path rather than an image, since
they can open files themselves.

> **These agents run with full tool access, unattended.** A panel has no way to
> answer an approval prompt, so they are launched with approvals bypassed. The
> working directory is the boundary that matters — set it with `/cwd` before
> asking for anything that writes.
>
> To keep agents read-only instead, set `ai.agentFullAccess` to `false` in
> `~/.config/ai-panel/config.json`.

Codex reports its answer in one piece rather than streaming it; progress
(reasoning, commands, file edits) still appears as it happens.

## Setup

Open The panel and pick a model by typing `/model` and then add api key of the model you selected by `/key API_KEY`

## Slash commands

| Command | Description |
|---|---|
| `/model` | Choose model |
| `/prompt` | Set the system prompt |
| `/key` | Set API key |
| `/temp` | Set temperature (0–2 Gemini, 0–1 others) |
| `/tool` | Set the tool to use for the model |
| `/attach` | Attach a file (Gemini and agent CLIs) |
| `/save` | Save the current chat |
| `/load` | Load a saved chat |
| `/cwd` | Set the working directory agent models run in |
| `/clear` | Clear chat history |

### Custom prompts

Drop `.md` or `.txt` files into `~/.config/ai-panel/ai/prompts/` and they appear in `/prompt`. Available placeholders:

| Placeholder | Replaced with |
|---|---|
| `{DISTRO}` | Distribution name |
| `{DE}` | Desktop environment / WM |
| `{DATETIME}` | Current date & time |
| `{WINDOWCLASS}` | Active window class |

## Uninstall

```bash
omarchy plugin disable io.github.atif-1402.ai-panel
omarchy plugin remove io.github.atif-1402.ai-panel
```

Chats are stored in `~/.local/state/ai-panel/` if you want to keep them.

## License

[MIT](LICENSE)
