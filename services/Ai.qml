pragma Singleton
pragma ComponentBehavior: Bound

import "../modules/common/functions" as CF
import "../modules/common"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "ai"

/**
 * Basic service to handle LLM chats. Supports Google's and OpenAI's API formats.
 * Supports Gemini and OpenAI models.
 * Limitations:
 * - For now functions only work with Gemini API format
 */
Singleton {
    id: root

    property Component aiMessageComponent: AiMessageData {}
    property Component aiModelComponent: AiModel {}
    property Component geminiApiStrategy: GeminiApiStrategy {}
    property Component openaiApiStrategy: OpenAiApiStrategy {}
    property Component mistralApiStrategy: MistralApiStrategy {}
    readonly property string interfaceRole: "interface"
    readonly property string apiKeyEnvVarName: "API_KEY"

    signal responseFinished()

    property string systemPrompt: {
        let prompt = Config.options?.ai?.systemPrompt ?? "";
        for (let key in root.promptSubstitutions) {
            // prompt = prompt.replaceAll(key, root.promptSubstitutions[key]);
            // QML/JS doesn't support replaceAll, so use split/join
            prompt = prompt.split(key).join(root.promptSubstitutions[key]);
        }
        return prompt;
    }
    // property var messages: []
    property var messageIDs: []
    property var messageByID: ({})
    readonly property var apiKeys: KeyringStorage.keyringData?.apiKeys ?? {}
    readonly property var apiKeysLoaded: KeyringStorage.loaded
    readonly property bool currentModelHasApiKey: {
        const model = models[currentModelId];
        if (!model || !model.requires_key) return true;
        if (!apiKeysLoaded) return false;
        const key = apiKeys[model.key_id];
        return (key?.length > 0);
    }
    property var postResponseHook
    property real temperature: Persistent.states?.ai?.temperature ?? 0.5
    property QtObject tokenCount: QtObject {
        property int input: -1
        property int output: -1
        property int total: -1
    }

    function idForMessage(message) {
        // Generate a unique ID using timestamp and random value
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 8);
    }

    function safeModelName(modelName) {
        return modelName.replace(/:/g, "_").replace(/ /g, "-").replace(/\//g, "-")
    }

    property list<var> userPrompts: []
    property list<var> defaultPrompts: []
    readonly property var userPromptNames: userPrompts.map(p => p.split("/").pop())
    property list<var> promptFiles: [...userPrompts, ...defaultPrompts.filter(p => !userPromptNames.includes(p.split("/").pop()))]
    property list<var> savedChats: []

    property var promptSubstitutions: {
        "{DISTRO}": SystemInfo.distroName,
        "{DATETIME}": `${DateTime.time}, ${DateTime.collapsedCalendarFormat}`,
        "{WINDOWCLASS}": ToplevelManager.activeToplevel?.appId ?? "Unknown",
        "{DE}": `${SystemInfo.desktopEnvironment} (${SystemInfo.windowingSystem})` 
    }

    // Gemini: https://ai.google.dev/gemini-api/docs/function-calling
    // OpenAI: https://platform.openai.com/docs/guides/function-calling
    property string currentTool: Config?.options.ai.tool ?? "search"
    property var tools: {
        "gemini": {
            "functions": [{"functionDeclarations": [
                {
                    "name": "switch_to_search_mode",
                    "description": "Search the web",
                },
                {
                    "name": "get_shell_config",
                    "description": "Get the desktop shell config file contents",
                },
                {
                    "name": "set_shell_config",
                    "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "key": {
                                "type": "string",
                                "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                            },
                            "value": {
                                "type": "string",
                                "description": "The value to set, e.g. `true`"
                            }
                        },
                        "required": ["key", "value"]
                    }
                },
                {
                    "name": "run_shell_command",
                    "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "command": {
                                "type": "string",
                                "description": "The bash command to run",
                            },
                        },
                        "required": ["command"]
                    }
                },
            ]}],
            "search": [{
                "google_search": {}
            }],
            "none": []
        },
        "openai": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": {
                                    "type": "string",
                                    "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                                },
                                "value": {
                                    "type": "string",
                                    "description": "The value to set, e.g. `true`"
                                }
                            },
                            "required": ["key", "value"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run",
                                },
                            },
                            "required": ["command"]
                        }
                    },
                },
            ],
            "search": [],
            "none": [],
        },
        "mistral": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": {
                                    "type": "string",
                                    "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                                },
                                "value": {
                                    "type": "string",
                                    "description": "The value to set, e.g. `true`"
                                }
                            },
                            "required": ["key", "value"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run",
                                },
                            },
                            "required": ["command"]
                        }
                    },
                },
            ],
            "search": [],
            "none": [],
        }
    }
    property list<var> availableTools: Object.keys(root.tools[models[currentModelId]?.api_format])
    property var toolDescriptions: {
        "functions": Translation.tr("Commands, edit configs, search.\nTakes an extra turn to switch to search mode if that's needed"),
        "search": Translation.tr("Gives the model search capabilities (immediately)"),
        "none": Translation.tr("Disable tools")
    }

    // Model properties:
    // - name: Name of the model
    // - icon: Icon name of the model
    // - description: Description of the model
    // - endpoint: Endpoint of the model
    // - model: Model name of the model
    // - requires_key: Whether the model requires an API key
    // - key_id: The identifier of the API key. Use the same identifier for models that can be accessed with the same key.
    // - key_get_link: Link to get an API key
    // - key_get_description: Description of pricing and how to get an API key
    // - api_format: The API format of the model. Can be "openai" or "gemini". Default is "openai".
    // - extraParams: Extra parameters to be passed to the model. This is a JSON object.
    property var models: Config.options.policies.ai === 2 ? {} : {
        "gemini-3.6-flash": aiModelComponent.createObject(this, {
            "name": "Gemini 3.6 Flash",
            "icon": "google-gemini-symbolic",
            "description": Translation.tr("Online | Google's model\nFast, high quality answers"),
            "homepage": "https://aistudio.google.com",
            "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:streamGenerateContent",
            "model": "gemini-3.6-flash",
            "requires_key": true,
            "key_id": "gemini",
            "key_get_link": "https://aistudio.google.com/app/apikey",
            "key_get_description": Translation.tr("**Pricing**: free. Data used for training.\n\n**Instructions**: Log into Google account, allow AI Studio to create Google Cloud project or whatever it asks, go back and click Get API key"),
            "api_format": "gemini",
            "supports_image_input": true,
        }),
        "gemini-3-flash": aiModelComponent.createObject(this, {
            "name": "Gemini 3 Flash",
            "icon": "google-gemini-symbolic",
            "description": Translation.tr("Online | Google's model\nPro-level intelligence at the speed and pricing of Flash."),
            "homepage": "https://aistudio.google.com",
            "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:streamGenerateContent",
            "model": "gemini-3-flash-preview",
            "requires_key": true,
            "key_id": "gemini",
            "key_get_link": "https://aistudio.google.com/app/apikey",
            "key_get_description": Translation.tr("**Pricing**: free. Data used for training.\n\n**Instructions**: Log into Google account, allow AI Studio to create Google Cloud project or whatever it asks, go back and click Get API key"),
            "api_format": "gemini",
            "supports_image_input": true,
        }),
        "mistral-medium-3": aiModelComponent.createObject(this, {
            "name": "Mistral Medium 3",
            "icon": "mistral-symbolic",
            "description": Translation.tr("Online | %1's model | Delivers fast, responsive and well-formatted answers. Disadvantages: not very eager to do stuff; might make up unknown function calls").arg("Mistral"),
            "homepage": "https://mistral.ai/news/mistral-medium-3",
            "endpoint": "https://api.mistral.ai/v1/chat/completions",
            "model": "mistral-medium-2505",
            "requires_key": true,
            "key_id": "mistral",
            "key_get_link": "https://console.mistral.ai/api-keys",
            "key_get_description": Translation.tr("**Instructions**: Log into Mistral account, go to Keys on the sidebar, click Create new key"),
            "api_format": "mistral",
        }),
        "groq-gpt-oss-120b": aiModelComponent.createObject(this, {
            "name": "GPT-OSS 120B",
            "icon": "groq-symbolic",
            "description": Translation.tr("Online | %1's model | OpenAI's open-weight 120B model hosted on Groq. Free tier with rate limits.").arg("Groq"),
            "homepage": "https://console.groq.com/docs/models",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "openai/gpt-oss-120b",
            "requires_key": true,
            "key_id": "groq",
            "key_get_link": "https://console.groq.com/keys",
            "key_get_description": Translation.tr("**Pricing**: free tier with rate limits.\n\n**Instructions**: Create a Groq account, go to console.groq.com/keys and click Create API Key"),
            "api_format": "openai",
        }),
        "groq-gpt-oss-20b": aiModelComponent.createObject(this, {
            "name": "GPT-OSS 20B",
            "icon": "groq-symbolic",
            "description": Translation.tr("Online | %1's model | OpenAI's open-weight 20B model hosted on Groq. Free tier with rate limits.").arg("Groq"),
            "homepage": "https://console.groq.com/docs/models",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "openai/gpt-oss-20b",
            "requires_key": true,
            "key_id": "groq",
            "key_get_link": "https://console.groq.com/keys",
            "key_get_description": Translation.tr("**Pricing**: free tier with rate limits.\n\n**Instructions**: Create a Groq account, go to console.groq.com/keys and click Create API Key"),
            "api_format": "openai",
        }),
        "groq-qwen3.6-27b": aiModelComponent.createObject(this, {
            "name": "Qwen3.6 27B",
            "icon": "groq-symbolic",
            "description": Translation.tr("Online | %1's model | Qwen's open-weight 27B model hosted on Groq. Free tier with rate limits.").arg("Groq"),
            "homepage": "https://console.groq.com/docs/models",
            "endpoint": "https://api.groq.com/openai/v1/chat/completions",
            "model": "qwen/qwen3.6-27b",
            "requires_key": true,
            "key_id": "groq",
            "key_get_link": "https://console.groq.com/keys",
            "key_get_description": Translation.tr("**Pricing**: free tier with rate limits.\n\n**Instructions**: Create a Groq account, go to console.groq.com/keys and click Create API Key"),
            "api_format": "openai",
            "supports_image_input": true,
        }),
    }
    property var modelList: Object.keys(root.models)
    property var currentModelId: modelList.includes(Persistent.states?.ai?.model) ? Persistent.states.ai.model : modelList[0]

    // True when an attachment is pending on a model without image support.
    // Live binding: switching models re-evaluates instantly, so the send
    // gate in AiChat unlocks as soon as a vision-capable model is chosen.
    readonly property bool attachmentUnsupported: {
        const model = models[currentModelId];
        return !!(root.pendingFilePath && root.pendingFilePath.length > 0 && model && model.supports_image_input !== true);
    }

    property var apiStrategies: {
        "openai": openaiApiStrategy.createObject(this),
        "gemini": geminiApiStrategy.createObject(this),
        "mistral": mistralApiStrategy.createObject(this),
    }
    property ApiStrategy currentApiStrategy: apiStrategies[models[currentModelId]?.api_format || "openai"]

    // IDs of models added from config, so live config reloads can drop removed ones
    property var userModelIds: []

    function addUserModels() {
        const extraModels = Config?.options.ai?.extraModels ?? [];
        const newIds = extraModels.map(model => root.safeModelName(model["model"]));
        const staleIds = root.userModelIds.filter(id => !newIds.includes(id));
        if (staleIds.length > 0) {
            let updatedModels = Object.assign({}, root.models);
            staleIds.forEach(id => delete updatedModels[id]);
            root.models = updatedModels;
        }
        root.userModelIds = newIds;
        extraModels.forEach(model => {
            const safeModelName = root.safeModelName(model["model"]);
            root.addModel(safeModelName, model)
        });
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (!Config.ready) return;
            root.addUserModels()
        }
    }

    // Config.ready stays true on live config reloads, so onReadyChanged won't
    // fire again. Watch extraModels directly to pick up runtime config edits.
    Connections {
        target: Config.options?.ai ?? null
        function onExtraModelsChanged() {
            if (!Config.ready) return;
            root.addUserModels()
        }
    }

    property string requestScriptFilePath: `${Directories.aiTmpDir}/request.sh`
    property string pendingFilePath: ""

    Component.onCompleted: {
        setModel(currentModelId, false, false); // Do necessary setup for model
        root.addUserModels() // Config onReadyChanged above might not fire if config is loaded before this service
    }

    function guessModelLogo(model) {
        if (model.includes("llama")) return "ollama-symbolic";
        if (model.includes("gemma")) return "google-gemini-symbolic";
        if (model.includes("deepseek")) return "deepseek-symbolic";
        if (/^phi\d*:/i.test(model)) return "microsoft-symbolic";
        return "ollama-symbolic";
    }

    function guessModelName(model) {
        const replaced = model.replace(/-/g, ' ').replace(/:/g, ' ');
        let words = replaced.split(' ');
        words[words.length - 1] = words[words.length - 1].replace(/(\d+)b$/, (_, num) => `${num}B`)
        words = words.map((word) => {
            return (word.charAt(0).toUpperCase() + word.slice(1))
        });
        if (words[words.length - 1] === "Latest") words.pop();
        else words[words.length - 1] = `(${words[words.length - 1]})`; // Surround the last word with square brackets
        const result = words.join(' ');
        return result;
    }

    function addModel(modelName, data) {
        root.models = Object.assign({}, root.models, {
            [modelName]: aiModelComponent.createObject(this, data)
        });
    }

    Process {
        id: getOllamaModels
        running: true
        command: ["bash", "-c", `${Directories.scriptPath}/ai/show-installed-ollama-models.sh`.replace(/file:\/\//, "")]
        stdout: SplitParser {
            onRead: data => {
                try {
                    if (data.length === 0) return;
                    const dataJson = JSON.parse(data);
                    dataJson.forEach(model => {
                        const safeModelName = root.safeModelName(model);
                        root.addModel(safeModelName, {
                            "name": guessModelName(model),
                            "icon": guessModelLogo(model),
                            "description": Translation.tr("Local Ollama model | %1").arg(model),
                            "homepage": `https://ollama.com/library/${model}`,
                            "endpoint": "http://localhost:11434/v1/chat/completions",
                            "model": model,
                            "requires_key": false,
                        })
                    });
                    // NOTE: do not assign to root.modelList here — it is a binding
                    // to Object.keys(root.models) and assignment would break it.

                } catch (e) {
                    console.log("Could not fetch Ollama models:", e);
                }
            }
        }
    }

    Process {
        id: getUserPrompts
        running: true
        command: ["ls", "-1", Directories.userAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.userPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.userAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getDefaultPrompts
        running: true
        command: ["ls", "-1", Directories.defaultAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.defaultPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.defaultAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getSavedChats
        running: true
        command: ["ls", "-1", Directories.aiChats]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.savedChats = text.split("\n")
                    .filter(fileName => fileName.endsWith(".json"))
                    .map(fileName => `${Directories.aiChats}/${fileName}`)
            }
        }
    }

    FileView {
        id: promptLoader
        watchChanges: false;
        onLoadedChanged: {
            if (!promptLoader.loaded) return;
            Config.options.ai.systemPrompt = promptLoader.text();
            root.addMessage(Translation.tr("Loaded the following system prompt\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
        }
    }

    function printPrompt() {
        root.addMessage(Translation.tr("The current system prompt is\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
    }

    function loadPrompt(filePath) {
        promptLoader.path = "" // Unload
        promptLoader.path = filePath; // Load
        promptLoader.reload();
    }

    function addMessage(message, role) {
        if (message.length === 0) return;
        const aiMessage = aiMessageComponent.createObject(root, {
            "role": role,
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true,
        });
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function removeMessage(index) {
        if (index < 0 || index >= messageIDs.length) return;
        const id = root.messageIDs[index];
        root.messageIDs.splice(index, 1);
        root.messageIDs = [...root.messageIDs];
        delete root.messageByID[id];
    }

    function addApiKeyAdvice(model) {
        root.addMessage(
            Translation.tr('To set an API key, pass it with the %4 command\n\nTo view the key, pass "get" with the command<br/>\n\n### For %1:\n\n**Link**: %2\n\n%3')
                .arg(model.name).arg(model.key_get_link).arg(model.key_get_description ?? Translation.tr("<i>No further instruction provided</i>")).arg("/key"), 
            Ai.interfaceRole
        );
    }

    function getModel() {
        return models[currentModelId];
    }

    function setModel(modelId, feedback = true, setPersistentState = true) {
        if (!modelId) modelId = ""
        modelId = modelId.toLowerCase()
        if (modelList.indexOf(modelId) !== -1) {
            const model = models[modelId]
            // See if policy prevents online models
            if (Config.options.policies.ai === 2 && !model.endpoint.includes("localhost")) {
                root.addMessage(
                    Translation.tr("Online models disallowed\n\nControlled by `policies.ai` config option"),
                    root.interfaceRole
                );
                return;
            }
            if (setPersistentState) Persistent.states.ai.model = modelId;
            if (feedback) root.addMessage(Translation.tr("Model set to %1").arg(model.name), root.interfaceRole);
            if (model.requires_key) {
                // If key not there show advice
                if (root.apiKeysLoaded && (!root.apiKeys[model.key_id] || root.apiKeys[model.key_id].length === 0)) {
                    root.addApiKeyAdvice(model)
                }
            }
        } else {
            if (feedback) root.addMessage(Translation.tr("Invalid model. Supported: \n```\n") + modelList.join("\n```\n```\n"), Ai.interfaceRole) + "\n```"
        }
    }

    function setTool(tool) {
        if (!root.tools[models[currentModelId]?.api_format] || !(tool in root.tools[models[currentModelId]?.api_format])) {
            root.addMessage(Translation.tr("Invalid tool. Supported tools:\n- %1").arg(root.availableTools.join("\n- ")), root.interfaceRole);
            return false;
        }
        Config.options.ai.tool = tool;
        return true;
    }
    
    function setTemperature(value) {
        if (value == NaN || value < 0 || value > 2) {
            root.addMessage(Translation.tr("Temperature must be between 0 and 2"), Ai.interfaceRole);
            return;
        }
        Persistent.states.ai.temperature = value;
        root.temperature = value;
        root.addMessage(Translation.tr("Temperature set to %1").arg(value), Ai.interfaceRole);
    }

    function setApiKey(key) {
        const model = models[currentModelId];
        if (!model.requires_key) {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
            return;
        }
        if (!key || key.length === 0) {
            const model = models[currentModelId];
            root.addApiKeyAdvice(model)
            return;
        }
        KeyringStorage.setNestedField(["apiKeys", model.key_id], key.trim());
        root.addMessage(Translation.tr("API key set for %1").arg(model.name), Ai.interfaceRole);
    }

    function printApiKey() {
        const model = models[currentModelId];
        if (model.requires_key) {
            const key = root.apiKeys[model.key_id];
            if (key) {
                const masked = key.length <= 8 ? "****" : key.slice(0, 4) + "..." + key.slice(-4);
                root.addMessage(Translation.tr("API key is set (%1)").arg(masked), Ai.interfaceRole);
            } else {
                root.addMessage(Translation.tr("No API key set for %1").arg(model.name), Ai.interfaceRole);
            }
        } else {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
        }
    }

    function printTemperature() {
        root.addMessage(Translation.tr("Temperature: %1").arg(root.temperature), Ai.interfaceRole);
    }

    function clearMessages() {
        root.messageIDs = [];
        root.messageByID = ({});
        root.tokenCount.input = -1;
        root.tokenCount.output = -1;
        root.tokenCount.total = -1;
    }

    FileView {
        id: requesterScriptFile
    }

    // Multimodal request bodies can exceed the kernel's per-argument size
    // limit (MAX_ARG_STRLEN, 128 KiB) once base64-encoded, so the JSON body
    // is assembled from two files inside the private tmp dir and handed to
    // curl as --data-binary instead of living on the command line.
    FileView {
        id: requestBodyHeadFile
        path: `${Directories.aiTmpDir}/body-head.json`
    }

    FileView {
        id: requestBodyTailFile
        path: `${Directories.aiTmpDir}/body-tail.json`
    }

    Process {
        id: requester
        property AiMessageData message
        property ApiStrategy currentStrategy

        // Streaming budget: hard cap on characters accepted from a provider
        // stream per request. Without it a malicious endpoint could stream
        // forever and exhaust memory in this long-lived shell process.
        // Character-based: JS strings are UTF-16, so .length bounds heap
        // directly (~2 bytes/char).
        readonly property int maxStreamChars: 8388608  // 8 Mi chars ≈ 16 MB heap per request
        readonly property int maxLineChars: 1048576    // 1 Mi chars for any single SSE line
        property int receivedChars: 0

        // Pre-parser stream cap: bounds the bytes entering SplitParser's
        // internal incomplete-line buffer (Process::stdoutBuffer), which
        // Quickshell appends to without limit while a hostile endpoint sends
        // bytes containing no newline. `head -c` exits at the cap, closing
        // the pipe and terminating curl (SIGPIPE / write error), so no more
        // than this many bytes can ever reach the parser. Byte-based:
        // enforced before any text decoding.
        readonly property int maxStreamBytes: 16777216 // 16 MiB per response
        readonly property string streamTruncateSentinel: "__AIPANEL_STREAM_TRUNCATED__"

        // Appended after each curl invocation in the generated request
        // script. Caps the stream and, when the cap was hit (curl died via
        // SIGPIPE 141 or a graceful write error 23/55), emits a sentinel
        // line that onRead converts into the visible size error.
        // Legitimate responses finish far below the cap and pass through
        // byte-identically.
        readonly property string streamPipelineSuffix: ` | head -c ${maxStreamBytes}
if [ "\${PIPESTATUS[0]}" -eq 141 ] || [ "\${PIPESTATUS[0]}" -eq 23 ] || [ "\${PIPESTATUS[0]}" -eq 55 ]; then printf '%s\\n' '${streamTruncateSentinel}'
fi
`

        function markDone() {
            requester.message.done = true;
            if (root.postResponseHook) {
                root.postResponseHook();
                root.postResponseHook = null; // Reset hook after use
            }
            root.saveChat("lastSession")
            root.responseFinished()
        }

        function makeRequest() {
            const model = models[currentModelId];

            // Capability-aware attachment handling: text-only models get a
            // visible notice and the request is stopped entirely (defensive
            // fallback — the send path is already gated in AiChat).
            if (root.pendingFilePath && !(model.supports_image_input === true)) {
                root.addMessage(Translation.tr("This model doesn't support image input — switch to a vision-capable model or remove the attachment."), root.interfaceRole);
                root.pendingFilePath = "";
                return;
            }

            // Fetch API keys if needed
            if (model?.requires_key && !KeyringStorage.loaded) KeyringStorage.fetchKeyringData();
            
            requester.currentStrategy = root.currentApiStrategy;
            requester.currentStrategy.reset(); // Reset strategy state
            requester.receivedChars = 0; // Reset streaming budget

            /* Put API key in environment variable */
            if (model.requires_key) requester.environment[`${root.apiKeyEnvVarName}`] = root.apiKeys ? (root.apiKeys[model.key_id] ?? "") : ""

            /* Private scratch dir for the request script and provider temp files */
            requester.environment["AI_TMP_DIR"] = Directories.aiTmpDir

            /* Build endpoint, request data */
            const endpoint = root.currentApiStrategy.buildEndpoint(model);
            const messageArray = root.messageIDs.map(id => root.messageByID[id]);
            const filteredMessageArray = messageArray.filter(message => message.role !== Ai.interfaceRole);
            const data = root.currentApiStrategy.buildRequestData(model, filteredMessageArray, root.systemPrompt, root.temperature, root.tools[model.api_format][root.currentTool], root.pendingFilePath);
            // console.log("[Ai] Request data: ", JSON.stringify(data, null, 2));

            let requestHeaders = {
                "Content-Type": "application/json",
            }
            
            /* Create local message object */
            requester.message = root.aiMessageComponent.createObject(root, {
                "role": "assistant",
                "model": currentModelId,
                "content": "",
                "rawContent": "",
                "thinking": true,
                "done": false,
            });
            const id = idForMessage(requester.message);
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = requester.message;

            /* Build header string for curl */ 
            let headerString = Object.entries(requestHeaders)
                .filter(([k, v]) => v && v.length > 0)
                .map(([k, v]) => `-H '${k}: ${v}'`)
                .join(' ');

            // console.log("Request headers: ", JSON.stringify(requestHeaders));
            // console.log("Header string: ", headerString);

            /* Get authorization header from strategy */
            const authHeader = requester.currentStrategy.buildAuthorizationHeader(root.apiKeyEnvVarName);
            
            /* Script shebang */
            const scriptShebang = "#!/usr/bin/env bash\n";

            /* Create extra setup when there's an attached file */
            let scriptFileSetupContent = ""
            if (root.pendingFilePath && root.pendingFilePath.length > 0) {
                requester.message.localFilePath = root.pendingFilePath;
                scriptFileSetupContent = requester.currentStrategy.buildScriptFileSetup(root.pendingFilePath);
                root.pendingFilePath = ""
            }

            /* Create command string */
            /* Send the request.
             * Multimodal bodies (base64 image) exceed the kernel's 128 KiB
             * per-argument limit, so when the strategy emitted the image
             * placeholder we assemble the JSON body from files in the private
             * tmp dir and pass it via --data-binary instead of argv. */
            const bodyJson = JSON.stringify(data);
            const IMAGE_PLACEHOLDER = '"{{ imageDataUrl }}"';
            const placeholderIdx = bodyJson.indexOf(IMAGE_PLACEHOLDER);
            let scriptRequestContent = ""
            if (placeholderIdx !== -1) {
                requestBodyHeadFile.setText(bodyJson.slice(0, placeholderIdx));
                requestBodyTailFile.setText(bodyJson.slice(placeholderIdx + IMAGE_PLACEHOLDER.length));
                scriptRequestContent += `cat "${Directories.aiTmpDir}/body-head.json" > "${Directories.aiTmpDir}/request-body.json"\n`
                    + `printf '"%s"' "$IMAGE_DATA_URL" >> "${Directories.aiTmpDir}/request-body.json"\n`
                    + `cat "${Directories.aiTmpDir}/body-tail.json" >> "${Directories.aiTmpDir}/request-body.json"\n`
                    + `curl --no-buffer "${endpoint}"`
                    + ` ${headerString}`
                    + (authHeader ? ` ${authHeader}` : "")
                    + ` --data-binary "@${Directories.aiTmpDir}/request-body.json"`
                    + requester.streamPipelineSuffix;
            } else {
                scriptRequestContent += `curl --no-buffer "${endpoint}"`
                    + ` ${headerString}`
                    + (authHeader ? ` ${authHeader}` : "")
                    + ` --data '${CF.StringUtils.shellSingleQuoteEscape(bodyJson)}'`
                    + requester.streamPipelineSuffix;
            }

            /* Send the request */
            const scriptContent = requester.currentStrategy.finalizeScriptContent(scriptShebang + scriptFileSetupContent + scriptRequestContent)
            const shellScriptPath = CF.FileUtils.trimFileProtocol(root.requestScriptFilePath)
            requesterScriptFile.path = Qt.resolvedUrl(shellScriptPath)
            requesterScriptFile.setText(scriptContent)
            // Ownership guard: refuse to execute the script unless it is owned
            // by the current user (defeats symlink swaps / pre-positioned files).
            requester.command = ["bash", "-c", '[ -O "$1" ] && exec bash "$1"; exit 126', "bash", shellScriptPath];
            requester.running = true
        }

        stdout: SplitParser {
            onRead: data => {
                if (data.length === 0) return;

                // Pre-parser truncation sentinel: emitted by the generated
                // script when `head -c` capped the byte stream (see
                // streamPipelineSuffix). Surface the visible size error once
                // and finish — skip provider parsing entirely.
                if (data === requester.streamTruncateSentinel) {
                    if (!requester.message.done) {
                        const truncError = "\n\n**Error**: response exceeded the maximum supported size and was stopped.";
                        requester.message.rawContent += truncError;
                        requester.message.content += truncError;
                        requester.markDone();
                    }
                    return;
                }

                // Oversized single-line guard: no legitimate SSE chunk comes
                // anywhere near this size. Skip before any downstream
                // accumulation (strategy parsing, message content, tool args).
                if (data.length > requester.maxLineChars) {
                    console.log("[AI] Dropped oversized stream line (" + data.length + " chars)");
                    return;
                }

                // Global stream budget: stop reading once the cap is exceeded.
                requester.receivedChars += data.length;
                if (requester.receivedChars > requester.maxStreamChars) {
                    if (!requester.message.done) {
                        const sizeError = "\n\n**Error**: response exceeded the maximum supported size and was stopped.";
                        requester.message.rawContent += sizeError;
                        requester.message.content += sizeError;
                        requester.markDone();
                        requester.running = false; // Terminate curl; onExited cleanup is safe (markDone guards on done)
                    }
                    return;
                }

                if (requester.message.thinking) requester.message.thinking = false;
                // console.log("[Ai] Raw response line: ", data);

                // Handle response line
                try {
                    const result = requester.currentStrategy.parseResponseLine(data, requester.message);
                    // console.log("[Ai] Parsed response result: ", JSON.stringify(result, null, 2));

                    if (result.functionCall) {
                        requester.message.functionCall = result.functionCall;
                        root.handleFunctionCall(result.functionCall.name, result.functionCall.args, requester.message);
                    }
                    if (result.tokenUsage) {
                        root.tokenCount.input = result.tokenUsage.input;
                        root.tokenCount.output = result.tokenUsage.output;
                        root.tokenCount.total = result.tokenUsage.total;
                    }
                    if (result.finished) {
                        requester.markDone();
                    }
                    
                } catch (e) {
                    console.log("[AI] Could not parse response: ", e);
                    requester.message.rawContent += data;
                    requester.message.content += data;
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            const result = requester.currentStrategy.onRequestFinished(requester.message);
            
            if (result.finished) {
                requester.markDone();
            } else if (!requester.message.done) {
                requester.markDone();
            }

            // Handle error responses
            if (requester.message.content.includes("API key not valid")) {
                root.addApiKeyAdvice(models[requester.message.model]);
            }
        }
    }

    function sendUserMessage(message) {
        if (message.length === 0) return;
        root.addMessage(message, "user");
        requester.makeRequest();
    }

    function attachFile(filePath: string) {
        let trimmedPath = CF.FileUtils.trimFileProtocol(filePath);
        // Expand a leading ~ (bash never expands it once the path is quoted
        // inside the generated request script).
        if (trimmedPath === "~" || trimmedPath.startsWith("~/")) {
            trimmedPath = Directories.home + trimmedPath.slice(1);
        }
        root.pendingFilePath = trimmedPath;
    }

    // Local "Flip a Coin" UX: result decided here (never by the model), no
    // provider request involved. The card animates only for freshly created
    // messages (_playAnimation is transient and never serialized), so loaded
    // chats render their coins in the landed state.
    function startCoinFlip() {
        const coinResult = Math.random() < 0.5;
        const message = aiMessageComponent.createObject(root, {
            "role": root.interfaceRole,
            "content": "",
            "rawContent": "",
            "kind": "coinflip",
            "coinResult": coinResult,
            "thinking": false,
            "done": true,
        });
        message.playAnimation = true;
        const id = idForMessage(message);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = message;
    }

    function regenerate(messageIndex) {
        if (messageIndex < 0 || messageIndex >= messageIDs.length) return;
        const id = root.messageIDs[messageIndex];
        const message = root.messageByID[id];
        if (message.role !== "assistant") return;
        // Remove all messages after this one
        for (let i = root.messageIDs.length - 1; i >= messageIndex; i--) {
            root.removeMessage(i);
        }
        requester.makeRequest();
    }

function createFunctionOutputMessage(name, output, includeOutputInChat = true, functionCallId = "") {
        return aiMessageComponent.createObject(root, {
            "role": "user",
            "content": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n thinking\n" + output + "\n response") : ""}`,
            "rawContent": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n thinking\n" + output + "\n response") : ""}`,
            "functionName": name,
            "functionCallId": functionCallId,
            "functionResponse": output,
            "thinking": false,
            "done": true,
            // "visibleToUser": false,
        });
    }

    function addFunctionOutputMessage(name, output, functionCallId = "") {
        const aiMessage = createFunctionOutputMessage(name, output, true, functionCallId);
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function rejectCommand(message: AiMessageData) {
        if (!message.functionPending) return;
        message.functionPending = false; // User decided, no more "thinking"
        addFunctionOutputMessage(message.functionName, Translation.tr("Command rejected by user"), message.functionCallId)
    }

    function approveCommand(message: AiMessageData) {
        if (!message.functionPending) return;
        message.functionPending = false; // User decided, no more "thinking"

        if (message.functionName === "set_shell_config") {
            const args = message.functionCall?.args ?? {};
            Config.setNestedValue(args.key, args.value);
            addFunctionOutputMessage("set_shell_config", Translation.tr("Config updated: %1 = %2").arg(args.key ?? "").arg(String(args.value ?? "")), message.functionCallId);
            requester.makeRequest(); // Continue
            return;
        }

        const responseMessage = createFunctionOutputMessage(message.functionName, "", false, message.functionCallId);
        const id = idForMessage(responseMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = responseMessage;

        commandExecutionProc.message = responseMessage;
        commandExecutionProc.baseMessageContent = responseMessage.content;
        commandExecutionProc.shellCommand = message.functionCall.args.command;
        commandExecutionProc.running = true; // Start the command execution
    }

    Process {
        id: commandExecutionProc
        property string shellCommand: ""
        property AiMessageData message
        property string baseMessageContent: ""
        command: ["bash", "-c", shellCommand]
        stdout: SplitParser {
            onRead: (output) => {
                commandExecutionProc.message.functionResponse += output + "\n\n";
                const updatedContent = commandExecutionProc.baseMessageContent + `\n\n<think>\n<tt>${commandExecutionProc.message.functionResponse}</tt>\n</think>`;
                commandExecutionProc.message.rawContent = updatedContent;
                commandExecutionProc.message.content = updatedContent;
            }
        }
        onExited: (exitCode, exitStatus) => {
            commandExecutionProc.message.functionResponse += `[[ Command exited with code ${exitCode} (${exitStatus}) ]]\n`;
            requester.makeRequest(); // Continue
        }
    }

    function handleFunctionCall(name, args: var, message: AiMessageData) {
        const callId = message.functionCallId ?? message.functionCall?.id ?? "";
        if (name === "switch_to_search_mode") {
            const modelId = root.currentModelId;
            root.currentTool = "search"
            root.postResponseHook = () => { root.currentTool = "functions" }
            addFunctionOutputMessage(name, Translation.tr("Switched to search mode. Continue with the user's request."), callId)
            requester.makeRequest();
        } else if (name === "get_shell_config") {
            const configJson = CF.ObjectUtils.toPlainObject(Config.options)
            addFunctionOutputMessage(name, JSON.stringify(configJson), callId);
            requester.makeRequest();
        } else if (name === "set_shell_config") {
            if (!args.key || args.value === undefined) {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `key` and `value`."), callId);
                return;
            }
            // Config writes are gated behind user approval, same as shell commands.
            const contentToAppend = `\n\n**Config change request**\n\n\`\`\`command\n${args.key} = ${String(args.value)}\n\`\`\``;
            message.rawContent += contentToAppend;
            message.content += contentToAppend;
            message.functionPending = true; // Wait for user approval
        } else if (name === "run_shell_command") {
            if (!args.command || args.command.length === 0) {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `command`."));
                return;
            }
            const contentToAppend = `\n\n**Command execution request**\n\n\`\`\`command\n${args.command}\n\`\`\``;
            message.rawContent += contentToAppend;
            message.content += contentToAppend;
            message.functionPending = true; // Use thinking to indicate the command is waiting for approval
        }
        else root.addMessage(Translation.tr("Unknown function call: %1").arg(name), "assistant");
    }

    function chatToJson() {
        return root.messageIDs.map(id => {
            const message = root.messageByID[id]
            return ({
                "role": message.role,
                "rawContent": message.rawContent,
                "fileMimeType": message.fileMimeType,
                "fileUri": message.fileUri,
                "localFilePath": message.localFilePath,
                "model": message.model,
                "thinking": false,
                "done": true,
                "annotations": message.annotations,
                "annotationSources": message.annotationSources,
                "functionName": message.functionName,
                "functionCall": message.functionCall,
                "functionCallId": message.functionCallId,
                "functionResponse": message.functionResponse,
                "visibleToUser": message.visibleToUser,
                "kind": message.kind,
                "coinResult": message.coinResult,
            })
        })
    }

    FileView {
        id: chatSaveFile
        property string chatName: ""
        path: chatName.length > 0 ? `${Directories.aiChats}/${chatName}.json` : ""
        blockLoading: true // Prevent race conditions
    }

    /**
     * Saves chat to a JSON list of message objects.
     * @param chatName name of the chat
     */
    function saveChat(chatName) {
        chatSaveFile.chatName = chatName.trim()
        const saveContent = JSON.stringify(root.chatToJson())
        chatSaveFile.setText(saveContent)
        getSavedChats.running = true;
    }

    /**
     * Loads chat from a JSON list of message objects.
     * @param chatName name of the chat
     */
    function loadChat(chatName) {
        try {
            chatSaveFile.chatName = chatName.trim()
            chatSaveFile.reload()
            const saveContent = chatSaveFile.text()
            // console.log(saveContent)
            const saveData = JSON.parse(saveContent)
            root.clearMessages()
            root.messageIDs = saveData.map((_, i) => {
                return i
            })
            // console.log(JSON.stringify(messageIDs))
            for (let i = 0; i < saveData.length; i++) {
                const message = saveData[i];
                root.messageByID[i] = root.aiMessageComponent.createObject(root, {
                    "role": message.role,
                    "rawContent": message.rawContent,
                    "content": message.rawContent,
                    "fileMimeType": message.fileMimeType,
                    "fileUri": message.fileUri,
                    "localFilePath": message.localFilePath,
                    "model": message.model,
                    "thinking": message.thinking,
                    "done": message.done,
                    "annotations": message.annotations,
                    "annotationSources": message.annotationSources,
                    "functionName": message.functionName,
                    "functionCall": message.functionCall,
                    "functionCallId": message.functionCallId ?? "",
                    "functionResponse": message.functionResponse,
                    "visibleToUser": message.visibleToUser,
                    "kind": message.kind ?? "",
                    "coinResult": message.coinResult ?? false,
                });
            }
        } catch (e) {
            console.log("[AI] Could not load chat: ", e);
        } finally {
            getSavedChats.running = true;
        }
    }
}
