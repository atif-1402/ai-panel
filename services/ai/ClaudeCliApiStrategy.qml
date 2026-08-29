import QtQuick

/**
 * Claude Code (`claude`) as a panel model.
 *
 * Runs in print mode with `stream-json`, which emits the Anthropic streaming
 * events verbatim, so text arrives token by token exactly as it would from the
 * HTTP API. Authentication is whatever the CLI already uses — a Claude
 * subscription or an API key — so the panel never handles a credential.
 *
 * `--verbose` is not optional: print mode refuses `stream-json` without it.
 */
AgentCliApiStrategy {
    id: root

    binary: "claude"

    function buildProcessCommand(model: AiModel, context): string {
        let args = [
            "-p",
            "--output-format", "stream-json",
            "--include-partial-messages",
            "--verbose",
        ];

        // Full access is an explicit opt-in because this flag bypasses Claude's
        // approval protections. By default, tools that would need approval are
        // denied instead of stalling on a prompt nobody can answer.
        if (root.fullAccess) args.push("--dangerously-skip-permissions");
        else args.push("--disallowed-tools", "Bash Edit Write NotebookEdit");

        if (model.model && model.model.length > 0) {
            args.push("--model", model.model);
        }
        if (context.sessionId && context.sessionId.length > 0) {
            args.push("--resume", context.sessionId);
        }

        return root.workingDirectoryPrefix(context) + root.invocation(context, args);
    }

    function parseResponseLine(line, message) {
        const trimmed = String(line).trim();
        if (trimmed.length === 0) return {};

        let data;
        try {
            data = JSON.parse(trimmed);
        } catch (e) {
            root.writeDiagnostic(message, trimmed);
            return {};
        }

        if (data.type === "system") {
            // The init event names the session this turn created; replaying it
            // as --resume is what keeps the agent's context across turns.
            if (data.subtype === "init" && data.session_id) {
                return { sessionId: data.session_id };
            }
            return {};
        }

        if (data.type === "stream_event") {
            const event = data.event ?? {};
            if (event.type === "content_block_delta") {
                const delta = event.delta ?? {};
                if (delta.type === "text_delta") {
                    root.sawDelta = true;
                    root.writeContent(message, delta.text ?? "");
                } else if (delta.type === "thinking_delta") {
                    root.sawDelta = true;
                    root.writeThinking(message, delta.thinking ?? "");
                }
                return {};
            }
            if (event.type === "content_block_start" && event.content_block?.type === "tool_use") {
                // Tool activity belongs in the collapsible block: useful to see
                // which files the agent touched, noise in the answer itself.
                root.writeThinking(message, `\n\n⏺ ${event.content_block.name ?? "tool"}\n`);
            }
            return {};
        }

        if (data.type === "assistant") {
            // Consolidated turn message. Redundant once deltas arrived, and the
            // only source of text when partial streaming is unavailable.
            if (root.sawDelta) return {};
            const blocks = data.message?.content ?? [];
            for (let i = 0; i < blocks.length; i++) {
                const block = blocks[i];
                if (block.type === "text") root.writeContent(message, block.text ?? "");
                else if (block.type === "thinking") root.writeThinking(message, block.thinking ?? "");
                else if (block.type === "tool_use") root.writeThinking(message, `\n\n⏺ ${block.name ?? "tool"}\n`);
            }
            return {};
        }

        if (data.type === "result") {
            if (data.is_error) {
                const detail = data.result ?? data.error ?? "unknown error";
                root.writeContent(message, `\n\n**Error**: ${typeof detail === "string" ? detail : JSON.stringify(detail)}`);
            }
            const usage = data.usage ?? {};
            const input = usage.input_tokens ?? -1;
            const output = usage.output_tokens ?? -1;
            return {
                finished: true,
                sessionId: data.session_id ?? "",
                tokenUsage: {
                    input: input,
                    output: output,
                    total: (input >= 0 && output >= 0) ? (input + output) : -1
                }
            };
        }

        return {};
    }

    function onRequestFinished(message) {
        root.finishTurn(message);
        return {};
    }
}
