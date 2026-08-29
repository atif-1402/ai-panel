import QtQuick

QtObject {
    /**
     * How this strategy reaches the model.
     * - "http"    : curl against buildEndpoint(), the default for chat APIs.
     * - "process" : run the shell snippet from buildProcessCommand() and read
     *               its stdout. Used by local agent CLIs, which have no HTTP
     *               surface but stream the same newline-delimited JSON.
     * Both transports feed parseResponseLine() identically.
     */
    function transport(): string { return "http" }

    function buildEndpoint(model: AiModel): string { throw new Error("Not implemented") }
    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) { throw new Error("Not implemented") }
    function buildAuthorizationHeader(apiKeyEnvVarName: string): string { throw new Error("Not implemented") }

    /**
     * Process transport only. Returns the shell snippet to run, without a
     * trailing newline or pipeline — the caller appends the shared streaming
     * caps. `context` carries { workingDirectory, sessionId, promptFile }.
     */
    function buildProcessCommand(model: AiModel, context): string { throw new Error("Not implemented") }

    /**
     * Process transport only. The text handed to the CLI for this turn.
     * When `hasSession` is true the CLI already holds the earlier turns, so
     * only the newest user message needs sending.
     */
    function buildPrompt(model: AiModel, messages, systemPrompt: string, hasSession: bool, filePath: string): string { throw new Error("Not implemented") }

    function parseResponseLine(line: string, message: AiMessageData) { throw new Error("Not implemented") }
    function onRequestFinished(message: AiMessageData): var { return {} } // Default: no special handling
    function reset() { } // Reset any internal state if needed
    function buildScriptFileSetup(filePath) { return "" } // Default: no setup
    function finalizeScriptContent(scriptContent: string): string { return scriptContent } // Optionally modify/finalize script
}
