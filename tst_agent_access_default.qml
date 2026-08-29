import QtQuick
import Quickshell
import Quickshell.Io
import "modules/common" as Common
import "services/ai" as Ai

ShellRoot {
    id: root

    Ai.AiModel {
        id: model
    }

    Ai.ClaudeCliApiStrategy {
        id: claude
    }

    Ai.CursorCliApiStrategy {
        id: cursor
    }

    Ai.CodexCliApiStrategy {
        id: codex
    }

    readonly property var context: ({
        workingDirectory: "/tmp",
        promptFile: "/tmp/ai-panel-test-prompt",
        sessionId: ""
    })

    FileView {
        id: resultFile
        path: Quickshell.env("AI_PANEL_TEST_RESULT")
        blockWrites: true
    }

    Component.onCompleted: {
        const failures = [];
        function expect(condition, message) {
            if (!condition) failures.push(message);
        }

        const claudeCommand = claude.buildProcessCommand(model, context);
        const cursorCommand = cursor.buildProcessCommand(model, context);
        const codexCommand = codex.buildProcessCommand(model, context);

        expect(!claude.fullAccess, "Claude defaults to full access");
        expect(!claudeCommand.includes("--dangerously-skip-permissions"), "Claude bypasses permissions by default");
        expect(claudeCommand.includes("--disallowed-tools"), "Claude is not restricted by default");

        expect(!cursor.fullAccess, "Cursor defaults to full access");
        expect(!cursorCommand.includes("--force"), "Cursor bypasses approvals by default");

        expect(!codex.fullAccess, "Codex defaults to full access");
        expect(!codexCommand.includes("--dangerously-bypass-approvals-and-sandbox"), "Codex bypasses approvals and sandboxing by default");
        expect(codexCommand.includes("'--sandbox' 'read-only'"), "Codex is not sandboxed read-only by default");

        Common.Config.options.ai.agentFullAccess = true;
        const fullAccessClaudeCommand = claude.buildProcessCommand(model, context);
        const fullAccessCursorCommand = cursor.buildProcessCommand(model, context);
        const fullAccessCodexCommand = codex.buildProcessCommand(model, context);

        expect(claude.fullAccess, "Claude ignores the full-access opt-in");
        expect(fullAccessClaudeCommand.includes("--dangerously-skip-permissions"), "Claude full access does not bypass approval prompts");

        expect(cursor.fullAccess, "Cursor ignores the full-access opt-in");
        expect(fullAccessCursorCommand.includes("--force"), "Cursor full access does not bypass approval prompts");

        expect(codex.fullAccess, "Codex ignores the full-access opt-in");
        expect(fullAccessCodexCommand.includes("--dangerously-bypass-approvals-and-sandbox"), "Codex full access does not bypass approval and sandbox protections");

        resultFile.setText(failures.length === 0 ? "PASS\n" : `FAIL\n${failures.join("\n")}\n`);
        Qt.callLater(function() { Qt.quit(); });
    }
}
