import QtQuick

/**
 * ChatGPT Codex (`codex exec`) as a panel model.
 *
 * Codex emits completed items rather than token deltas, so the answer lands in
 * one piece instead of streaming — the only one of the three agents that
 * behaves this way. Everything before the answer (reasoning, commands, file
 * edits) does arrive incrementally and is shown as it happens, so the panel
 * still reflects progress while the agent works.
 *
 * Resuming uses a subcommand (`codex exec resume <thread>`) rather than a flag,
 * which is why the argument list is assembled around the position of the
 * subcommand.
 */
AgentCliApiStrategy {
    id: root

    binary: "codex"

    function buildProcessCommand(model: AiModel, context): string {
        let args = ["exec"];

        if (context.sessionId && context.sessionId.length > 0) {
            args.push("resume", context.sessionId);
        }

        args.push("--json");
        // Keep Codex in its read-only sandbox by default. Full access is an
        // explicit opt-in because it bypasses both approval and sandbox
        // protections.
        if (root.fullAccess) args.push("--dangerously-bypass-approvals-and-sandbox");
        else args.push("--sandbox", "read-only");
        args.push("--skip-git-repo-check");

        const dir = context.workingDirectory && context.workingDirectory.length > 0
            ? context.workingDirectory : "";
        if (dir.length > 0) args.push("-C", dir);

        if (model.model && model.model.length > 0) {
            args.push("--model", model.model);
        }

        return root.workingDirectoryPrefix(context) + root.invocation(context, args);
    }

    function describeItem(item): string {
        const type = item.type ?? "";
        if (type === "command_execution") {
            const command = item.command ?? "";
            const exitCode = item.exit_code;
            return `\n\n⏺ $ ${command}${exitCode !== undefined && exitCode !== null ? ` → exit ${exitCode}` : ""}\n`;
        }
        if (type === "file_change") {
            const changes = item.changes ?? [];
            const paths = changes.map(c => `${c.kind ?? "edit"} ${c.path ?? ""}`).join(", ");
            return `\n\n⏺ file change: ${paths.length > 0 ? paths : "(unnamed)"}\n`;
        }
        if (type === "mcp_tool_call") {
            return `\n\n⏺ ${item.server ?? "mcp"}.${item.tool ?? "tool"}\n`;
        }
        if (type === "web_search") {
            return `\n\n⏺ web search: ${item.query ?? ""}\n`;
        }
        if (type === "todo_list") {
            return "";
        }
        return "";
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

        const type = data.type ?? "";

        if (type === "thread.started") {
            return { sessionId: data.thread_id ?? "" };
        }

        if (type === "item.started" || type === "item.updated") {
            const item = data.item ?? {};
            // Reasoning streams as it is produced; commands are announced when
            // they start so a long build isn't a silent gap.
            if (item.type === "reasoning") root.writeThinking(message, item.text ?? "");
            else if (type === "item.started") root.writeThinking(message, root.describeItem(item));
            return {};
        }

        if (type === "item.completed") {
            const item = data.item ?? {};
            if (item.type === "agent_message") {
                root.writeContent(message, item.text ?? "");
            } else if (item.type === "reasoning") {
                root.writeThinking(message, item.text ?? "");
            } else if (item.type === "error") {
                // An error item is advisory — a trimmed skill list, a failed
                // MCP server. Real failures arrive as turn.failed, so this
                // belongs beside the other progress detail, not in the answer.
                root.writeThinking(message, `\n\n⚠ ${item.message ?? "unknown error"}\n`);
            } else {
                root.writeThinking(message, root.describeItem(item));
            }
            return {};
        }

        if (type === "turn.failed") {
            const detail = data.error?.message ?? JSON.stringify(data.error ?? {});
            root.writeContent(message, `\n\n**Error**: ${detail}`);
            return { finished: true };
        }

        if (type === "error") {
            root.writeContent(message, `\n\n**Error**: ${data.message ?? JSON.stringify(data)}`);
            return { finished: true };
        }

        if (type === "turn.completed") {
            const usage = data.usage ?? {};
            const input = usage.input_tokens ?? -1;
            const output = usage.output_tokens ?? -1;
            return {
                finished: true,
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
