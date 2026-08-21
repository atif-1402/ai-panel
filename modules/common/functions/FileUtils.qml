pragma Singleton
import Quickshell

Singleton {
    id: root

    /**
     * Trims the File protocol off the input string
     * @param {string} str
     * @returns {string}
     */
    function trimFileProtocol(str) {
        let s = str;
        if (typeof s !== "string") s = str.toString(); // Convert to string if it's an url or whatever
        return s.startsWith("file://") ? s.slice(7) : s;
    }

    /**
     * Extracts the file name from a file path
     * @param {string} str
     * @returns {string}
     */
    function fileNameForPath(str) {
        if (typeof str !== "string") return "";
        const trimmed = trimFileProtocol(str);
        return trimmed.split(/[\\/]/).pop();
    }

    /**
     * Removes the file extension from a file path or name
     * @param {string} str
     * @returns {string}
     */
    function trimFileExt(str) {
        if (typeof str !== "string") return "";
        const trimmed = trimFileProtocol(str);
        const lastDot = trimmed.lastIndexOf(".");
        if (lastDot > -1 && lastDot > trimmed.lastIndexOf("/")) {
            return trimmed.slice(0, lastDot);
        }
        return trimmed;
    }
}
