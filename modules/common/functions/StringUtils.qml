pragma Singleton
import Quickshell

Singleton {
    id: root

    /**
     * Formats a string according to the args that are passed inc
     * @param { string } str
     * @param  {...any} args
     * @returns { string }
     */
    function format(str, ...args) {
        return str.replace(/{(\d+)}/g, (match, index) => typeof args[index] !== 'undefined' ? args[index] : match);
    }

    /**
     * Returns the domain of the passed in url or null.
     * Only hostname characters are accepted, so the result is always safe to
     * embed in shell commands, file paths and URLs.
     * @param { string } url
     * @returns { string| null }
     */
    function getDomain(url) {
        const match = String(url).match(/^(?:https?:\/\/)?(?:www\.)?([A-Za-z0-9.-]+)/);
        return match ? match[1] : null;
    }

    /**
     * Escapes single quotes in shell commands
     * @param { string } str
     * @returns { string }
     */
    function shellSingleQuoteEscape(str) {
        return String(str)
        // .replace(/\\/g, '\\\\')
        .replace(/'/g, "'\\''");
    }

    /**
     * Escapes a string for safe interpolation inside a double-quoted bash
     * context by neutralizing the characters that are special there
     * (backslash, double quote, dollar sign, backtick).
     * @param { string } str
     * @returns { string }
     */
    function shellDoubleQuoteEscape(str) {
        return String(str).replace(/([\\"$`])/g, "\\$1");
    }

    /**
     * Splits markdown blocks into three different types: text, think, and code.
     * @param { string } markdown
     * @returns {Array<{type: "text" | "think" | "code", content: string, lang?: string, completed?: boolean}>}
     */
    function splitMarkdownBlocks(markdown) {
        if (markdown === undefined || markdown === null)
            return [];
        const regex = /```(\w+)?\n([\s\S]*?)```|<think>([\s\S]*?)<\/think>/g;
        /**
         * @type {{type: "text" | "think" | "code"; content: string; lang: string | undefined; completed: boolean | undefined}[]}
         */
        let result = [];
        let lastIndex = 0;
        let match;
        while ((match = regex.exec(markdown)) !== null) {
            if (match.index > lastIndex) {
                const text = markdown.slice(lastIndex, match.index);
                if (text.trim()) {
                    result.push({
                        type: "text",
                        content: text
                    });
                }
            }
            if (match[0].startsWith('```')) {
                if (match[2] && match[2].trim()) {
                    result.push({
                        type: "code",
                        lang: match[1] || "",
                        content: match[2],
                        completed: true
                    });
                }
            } else if (match[0].startsWith('<think>')) {
                if (match[3] && match[3].trim()) {
                    result.push({
                        type: "think",
                        content: match[3],
                        completed: true
                    });
                }
            }
            lastIndex = regex.lastIndex;
        }
        // Handle any remaining text after the last match
        if (lastIndex < markdown.length) {
            const text = markdown.slice(lastIndex);
            // Check for unfinished <think> block
            const thinkStart = text.indexOf('<think>');
            const codeStart = text.indexOf('```');
            if (thinkStart !== -1 && (codeStart === -1 || thinkStart < codeStart)) {
                const beforeThink = text.slice(0, thinkStart);
                if (beforeThink.trim()) {
                    result.push({
                        type: "text",
                        content: beforeThink
                    });
                }
                const thinkContent = text.slice(thinkStart + 7);
                if (thinkContent.trim()) {
                    result.push({
                        type: "think",
                        content: thinkContent,
                        completed: false
                    });
                }
            } else if (codeStart !== -1) {
                const beforeCode = text.slice(0, codeStart);
                if (beforeCode.trim()) {
                    result.push({
                        type: "text",
                        content: beforeCode
                    });
                }
                // Try to detect language after ```
                const codeLangMatch = text.slice(codeStart + 3).match(/^(\w+)?\n/);
                let lang = "";
                let codeContentStart = codeStart + 3;
                if (codeLangMatch) {
                    lang = codeLangMatch[1] || "";
                    codeContentStart += codeLangMatch[0].length;
                } else if (text[codeStart + 3] === '\n') {
                    codeContentStart += 1;
                }
                const codeContent = text.slice(codeContentStart);
                if (codeContent.trim()) {
                    result.push({
                        type: "code",
                        lang,
                        content: codeContent,
                        completed: false
                    });
                }
            } else if (text.trim()) {
                result.push({
                    type: "text",
                    content: text
                });
            }
        }
        // console.log(JSON.stringify(result, null, 2));
        return result;
    }

    /**
     * Escapes HTML special characters in a string.
     * @param { string } str
     * @returns { string }
     */
    function escapeHtml(str) {
        if (typeof str !== 'string')
            return str;
        return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    /**
     * Cleans a cliphist entry by removing leading digits and tab.
     * @param { string } str
     * @returns { string }
     */
    function cleanCliphistEntry(str: string): string {
        return str.replace(/^\d+\t/, "");
    }
}
