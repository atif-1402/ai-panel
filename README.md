# AI Panel for Omarchy

A native [Omarchy](https://omarchy.org) shell plugin: a full AI chat sidebar summoned with a keypress. Streaming responses, multiple providers, prompt presets, saved chats — all inside your window manager.

![screenshot](assets/readme-assets/showcase.png)

## Features

- **Streaming chat** with token-by-token output and markdown rendering (code blocks, tables, links)
- **Multi-provider** — Gemini, Mistral, DeepSeek, Ollama (local), and more
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
| `/attach` | Attach a file (Gemini only) |
| `/save` | Save the current chat |
| `/load` | Load a saved chat |
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
