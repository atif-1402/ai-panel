import QtQuick

/**
 * Cursor Agent (`cursor-agent`) as a panel model.
 *
 * Cursor publishes no per-user chat or usage API — the CLI is the only way in.
 * `--stream-partial-output` gives token-level deltas; reasoning arrives on its
 * own `thinking` events rather than inline, so it is routed to the collapsible
 * block instead of the answer.
 *
 * `--trust` is required for any directory Cursor has not seen before, otherwise
 * the CLI stops on an interactive trust prompt that a panel cannot answer.
 */
AgentCliApiStrategy {
    id: root

    binary: "cursor-agent"

    function buildProcessCommand(model: AiModel, context): string {
        let args = [
            "-p",
            "--output-format", "stream-json",
            "--stream-partial-output",
            "--trust",
        ];

        // --force bypasses Cursor's approval protections, so add it only after
        // an explicit full-access opt-in. Without it, actions requiring
        // approval cannot proceed unattended.
        if (root.fullAccess) args.push("--force");

        if (model.model && model.model.length > 0) {
            args.push("--model", model.model);
        }
        if (context.sessionId && context.sessionId.length > 0) {
            args.push(`--resume=${context.sessionId}`);
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
            if (data.subtype === "init" && data.session_id) {
                return { sessionId: data.session_id };
            }
            return {};
        }

        if (data.type === "thinking") {
            if (data.subtype === "delta") {
                root.writeThinking(message, data.text ?? "");
            }
            return {};
        }

        if (data.type === "assistant") {
            // Deltas carry a timestamp; the consolidated end-of-turn message
            // does not. Without that distinction the full answer would be
            // appended a second time after streaming it.
            const isDelta = (data.timestamp_ms !== undefined);
            if (!isDelta && root.sawDelta) return {};
            if (isDelta) root.sawDelta = true;

            const blocks = data.message?.content ?? [];
            for (let i = 0; i < blocks.length; i++) {
                const block = blocks[i];
                if (block.type === "text") root.writeContent(message, block.text ?? "");
            }
            return {};
        }

        if (data.type === "tool_call") {
            const name = data.tool_call?.name ?? data.name ?? data.subtype ?? "tool";
            if (data.subtype !== "completed") {
                root.writeThinking(message, `\n\n⏺ ${name}\n`);
            }
            return {};
        }

        if (data.type === "result") {
            if (data.is_error) {
                const detail = data.result ?? data.error ?? "unknown error";
                root.writeContent(message, `\n\n**Error**: ${typeof detail === "string" ? detail : JSON.stringify(detail)}`);
            }
            const usage = data.usage ?? {};
            const input = usage.inputTokens ?? -1;
            const output = usage.outputTokens ?? -1;
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
