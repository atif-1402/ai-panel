import QtQuick
import "../../modules/common"
import "../../modules/common/functions" as CF

/**
 * Shared behaviour for local agent CLIs (Claude Code, Cursor Agent, Codex).
 *
 * These are not chat APIs. Each is an agentic process that owns its own
 * conversation state, tools and working directory, and none of them exposes an
 * HTTP endpoint a panel could POST to. What they do expose is newline-delimited
 * JSON on stdout — exactly what this panel's streaming parser already consumes —
 * so they slot in as a second transport rather than a second protocol.
 *
 * Three consequences shape this base class:
 *
 * - Conversation state lives in the CLI, not here. The first turn replays the
 *   panel's history as one flattened prompt; once the CLI reports a session id,
 *   later turns send only the new user message and resume that session, so the
 *   agent keeps its own tool results and file context instead of re-reading the
 *   project every turn.
 * - The prompt travels on stdin, never in argv. Long conversations would
 *   otherwise hit the kernel's 128 KiB per-argument limit, and stdin sidesteps
 *   shell quoting entirely.
 * - stderr is folded into stdout. A CLI that refuses to start — not logged in,
 *   untrusted workspace, missing binary — then says so in the chat instead of
 *   producing a silent empty reply.
 */
ApiStrategy {
    id: root

    // Set by subclasses; the executable that must be on PATH.
    property string binary: ""

    // Whether this turn produced incremental deltas. CLIs that stream deltas
    // also emit one consolidated message at the end; without this flag that
    // final message would be appended a second time.
    property bool sawDelta: false

    // Whether this turn produced any answer text. Drives the fallback that
    // promotes diagnostics when a CLI exits without saying anything useful.
    property bool sawContent: false

    // Exit status of the CLI, set by the service once the process ends.
    property int exitCode: 0

    // Diagnostic lines seen this turn, kept so a silent failure can be
    // explained after the fact rather than leaving an empty bubble.
    property string diagnostics: ""

    // Open/closed state of the <think> block the panel renders as collapsible
    // reasoning. Tool activity and reasoning share it, so it must be tracked
    // rather than emitted per event.
    property bool inThink: false

    // Fail closed while config is unavailable: bypass flags are added only
    // after the user explicitly opts into unrestricted tool access.
    readonly property bool fullAccess: Config.options?.ai?.agentFullAccess ?? false

    function transport(): string { return "process" }

    // HTTP-only hooks. Harmless no-ops so the shared request path can compute
    // its headers without branching before it reaches buildProcessCommand().
    function buildEndpoint(model: AiModel): string { return "" }
    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) { return ({}) }
    function buildAuthorizationHeader(apiKeyEnvVarName: string): string { return "" }

    function quote(str): string {
        return `'${CF.StringUtils.shellSingleQuoteEscape(String(str))}'`;
    }

    /**
     * `cd` into the chat's working directory before running the agent. A
     * missing directory is reported in the chat and ends the turn cleanly —
     * running an agent that can write files from an unexpected directory is
     * worse than not running it at all.
     */
    function workingDirectoryPrefix(context): string {
        const dir = context.workingDirectory && context.workingDirectory.length > 0
            ? context.workingDirectory : "$HOME";
        return `cd ${root.quote(dir)} 2>/dev/null || { printf '%s\\n' `
            + root.quote(`working directory not found: ${dir}`)
            + `; exit 0; }\n`;
    }

    /**
     * The agent invocation itself. The prompt arrives on stdin as a redirect
     * rather than through `cat`, which keeps the agent first in the pipeline —
     * the shared streaming caps read PIPESTATUS[0], and that has to mean the
     * agent's exit status, not a pipe feeder's.
     */
    function invocation(context, args): string {
        const quotedArgs = args.map(a => root.quote(a)).join(" ");
        return `${root.quote(root.binary)} ${quotedArgs}`
            + ` < ${root.quote(context.promptFile)} 2>&1`;
    }

    // ---- Shared message writing -------------------------------------------

    function openThink(message: AiMessageData) {
        if (root.inThink) return;
        root.inThink = true;
        const block = "\n\n<think>\n\n";
        message.content += block;
        message.rawContent += block;
    }

    function closeThink(message: AiMessageData) {
        if (!root.inThink) return;
        root.inThink = false;
        const block = "\n\n</think>\n\n";
        message.content += block;
        message.rawContent += block;
    }

    function writeThinking(message: AiMessageData, text: string) {
        if (!text || text.length === 0) return;
        root.openThink(message);
        message.content += text;
        message.rawContent += text;
    }

    function writeContent(message: AiMessageData, text: string) {
        if (!text || text.length === 0) return;
        root.sawContent = true;
        root.closeThink(message);
        message.content += text;
        message.rawContent += text;
    }

    // Chatter every run produces, carrying no information for the reader.
    readonly property var diagnosticNoise: [
        /^Reading prompt from stdin/,
        /^Reading additional input from stdin/
    ]

    /**
     * A line that isn't JSON is diagnostic output from the CLI, almost always
     * stderr. It goes to the collapsible block rather than the answer: on a
     * successful turn it is noise, and on a failed one finishTurn() promotes it
     * so the reason is never lost.
     */
    function writeDiagnostic(message: AiMessageData, line: string) {
        const cleaned = String(line).replace(/\u001b\[[0-9;?]*[A-Za-z]/g, "").trim();
        if (cleaned.length === 0) return;
        for (let i = 0; i < root.diagnosticNoise.length; i++) {
            if (root.diagnosticNoise[i].test(cleaned)) return;
        }
        root.diagnostics += (root.diagnostics.length > 0 ? "\n" : "") + cleaned;
        root.writeThinking(message, cleaned + "\n");
    }

    /**
     * Ends the turn. A CLI that produced no answer has failed in some way the
     * event stream didn't spell out — a bad flag, a missing login, a crash —
     * so whatever it did print is promoted into the message rather than
     * leaving the user with an empty reply and no reason for it.
     */
    function finishTurn(message: AiMessageData) {
        if (!root.sawContent) {
            const reason = root.diagnostics.length > 0
                ? root.diagnostics
                : `\`${root.binary}\` exited without producing a reply (exit code ${root.exitCode}).`;
            root.closeThink(message);
            message.content += `\n\n**Error**: ${reason}`;
            message.rawContent += `\n\n**Error**: ${reason}`;
        }
        root.closeThink(message);
    }

    // ---- Prompt assembly ---------------------------------------------------

    function roleLabel(role: string): string {
        if (role === "assistant") return "Assistant";
        if (role === "user") return "User";
        return role.charAt(0).toUpperCase() + role.slice(1);
    }

    /**
     * First turn: replay the whole conversation so a chat that started on
     * another model keeps its context. Resumed turn: send only the new message,
     * because the CLI still holds everything before it.
     */
    function buildPrompt(model: AiModel, messages, systemPrompt: string, hasSession: bool, filePath: string): string {
        const history = messages.filter(m => m.rawContent && m.rawContent.length > 0);
        let body = "";

        if (hasSession) {
            const last = history.length > 0 ? history[history.length - 1] : null;
            body = last ? last.rawContent : "";
        } else {
            let parts = [];
            if (systemPrompt && systemPrompt.length > 0) {
                parts.push(systemPrompt.trim());
                parts.push("---");
            }
            if (history.length === 1) {
                parts.push(history[0].rawContent);
            } else {
                // Label the turns so the agent can tell replayed history from
                // the request it is being asked to answer now.
                for (let i = 0; i < history.length; i++) {
                    const m = history[i];
                    const isLast = (i === history.length - 1);
                    parts.push(isLast && m.role === "user"
                        ? m.rawContent
                        : `[${root.roleLabel(m.role)}]\n${m.rawContent}`);
                }
            }
            body = parts.join("\n\n");
        }

        // Agents read files themselves, so an attachment is a path, not base64.
        const trimmedPath = filePath && filePath.length > 0 ? CF.FileUtils.trimFileProtocol(filePath) : "";
        if (trimmedPath.length > 0) {
            body += `\n\nAttached file: ${trimmedPath}`;
        }
        return body;
    }

    function reset() {
        root.sawDelta = false;
        root.inThink = false;
        root.sawContent = false;
        root.diagnostics = "";
        root.exitCode = 0;
    }
}
