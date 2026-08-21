pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

// Lightweight syntax highlighter for read-only code blocks.
// State-machine tokenizer: comments/strings first, then numbers,
// identifiers (keyword/function/type/variable), and operators.
// Emits HTML spans colored from the theme palette passed in.
QtObject {
    function escapeHtml(text) {
        return String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    function isIdentStart(c) {
        return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c === "_" || c === "$"
    }

    function isIdentChar(c) {
        return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c === "_" || c === "$"
    }

    function isDigit(c) {
        return c >= "0" && c <= "9"
    }

    // lang -> highlighting behavior id
    function langId(lang) {
        var l = String(lang || "").toLowerCase()
        if (l === "bash" || l === "sh" || l === "shell" || l === "zsh" || l === "command") return "bash"
        if (l === "python" || l === "py") return "python"
        if (l === "javascript" || l === "js") return "js"
        if (l === "typescript" || l === "ts") return "ts"
        if (l === "c" || l === "cpp" || l === "c++" || l === "csharp" || l === "cs") return "c"
        if (l === "html" || l === "xml" || l === "svg" || l === "markup") return "markup"
        if (l === "yaml" || l === "yml") return "yaml"
        if (l === "json") return "json"
        if (l === "toml") return "toml"
        if (l === "ini") return "ini"
        if (l === "dockerfile") return "dockerfile"
        if (l === "plaintext" || l === "text" || l === "txt" || l === "log" || l === "diff") return ""
        return l
    }

    function keywordSet(lang) {
        var id = langId(lang)
        var words = "if else for while do return function class new this true false null undefined var let const import from export try catch finally throw break continue switch case default static public private protected"
        if (id === "bash") words = "if then else elif fi for while until do done in case esac function select return local export readonly declare unset set shopt alias exit break continue test true false"
        else if (id === "python") words = "def class return if elif else for while try except finally with as import from lambda pass break continue yield global nonlocal assert raise del in not and or is None True False async await match case self"
        else if (id === "js" || id === "ts") words = "var let const function return if else for while do switch case break continue new class extends super this typeof instanceof delete in of void null undefined true false async await yield import from export default try catch finally throw static get set"
        else if (id === "ts") words += " interface type enum namespace readonly public private protected implements keyof infer never any string number boolean object symbol unknown"
        else if (id === "c") words = "auto break case char const continue default do double else enum extern float for goto if inline int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while true false"
        else if (id === "rust") words = "fn let mut const static if else match for while loop break continue return struct enum trait impl mod use pub self crate super type where as in ref move async await dyn unsafe extern macro_rules true false"
        else if (id === "go") words = "func var const type struct interface map chan go defer return if else for range switch case break continue default package import select goto true false iota nil"
        else if (id === "java") words = "public private protected class interface extends implements import package static final void int long float double boolean char byte short new return if else for while do switch case break continue try catch finally throw throws this super instanceof enum true false null volatile synchronized abstract native strictfp transient"
        else if (id === "sql") words = "select from where insert into values update set delete create table index view drop alter add column primary key foreign references join inner left right outer on group by order having limit offset union distinct as and or not null true false default unique check constraint trigger procedure function begin end case when then else exists like between in is"
        else if (id === "lua") words = "and break do else elseif end false for function goto if in local nil not or repeat return then true until while"
        else if (id === "ruby") words = "def end if elsif else unless while until for do in return yield begin rescue ensure raise class module require include extend attr_reader attr_writer attr_accessor new true false nil self super"
        else if (id === "php") words = "function class interface extends implements public private protected static final const return if else elseif foreach for while do switch case break continue try catch finally throw new this parent self namespace use require require_once include include_once echo print true false null isset empty array"
        else if (id === "kotlin") words = "fun val var class object interface data sealed enum when if else for while do return break continue try catch finally throw null true false this super is in as private public protected internal override open abstract final companion init constructor lateinit by lazy"
        else if (id === "dockerfile") words = "FROM RUN CMD ENTRYPOINT COPY ADD WORKDIR ENV ARG EXPOSE VOLUME USER LABEL MAINTAINER ONBUILD STOPSIGNAL HEALTHCHECK SHELL"
        else if (id === "cmake") words = "cmake_minimum_required project add_executable add_library target_link_libraries include_directories add_subdirectory set if else endif foreach endforeach function endfunction find_package option message install"
        else if (id === "json") words = "true false null"
        else if (id === "yaml") words = "true false null yes no"
        else if (id === "toml" || id === "ini") words = "true false"
        return words
    }

    // Tokenizes a single line into HTML spans.
    function tokenizeLine(line, kwSet, id, capTypes, hashComment, dataKeys, dollarVars, pal) {
        var out = []
        var i = 0
        var n = line.length
        var c, nextNonSpace, color, close, word

        function emit(text, color) {
            if (text.length === 0) return
            if (color) out.push('<span style="color:' + color + '">' + escapeHtml(text) + "</span>")
            else out.push(escapeHtml(text))
        }

        while (i < n) {
            c = line.charAt(i)

            if (c === "/" && line.charAt(i + 1) === "/") {
                emit(line.slice(i), pal.comment)
                i = n
                continue
            }
            if (c === "#" && hashComment) {
                emit(line.slice(i), pal.comment)
                i = n
                continue
            }
            if (c === "/" && line.charAt(i + 1) === "*") {
                emit(line.slice(i), pal.comment)
                i = n
                continue
            }

            if (c === '"' || c === "'" || c === "`") {
                var quote = c
                var sStart = i
                i += 1
                while (i < n) {
                    var sc = line.charAt(i)
                    if (sc === "\\") { i += 2; continue }
                    if (sc === quote) { i += 1; break }
                    i += 1
                }
                emit(line.slice(sStart, i), pal.string)
                continue
            }

            if (c === "<" && id === "markup") {
                var tagEnd = line.indexOf(">", i)
                var tagStop = tagEnd === -1 ? n : tagEnd + 1
                emit(line.slice(i, tagStop), pal.type)
                i = tagStop
                continue
            }

            if (isDigit(c) || (c === "." && isDigit(line.charAt(i + 1)))) {
                var numStart = i
                if (c === "0" && (line.charAt(i + 1) === "x" || line.charAt(i + 1) === "X")) {
                    i += 2
                    while (i < n && /[0-9a-fA-F_]/.test(line.charAt(i))) i += 1
                } else {
                    while (i < n) {
                        var nc = line.charAt(i)
                        if (isDigit(nc) || nc === "_" || nc === "." || nc === "e" || nc === "E" ||
                            ((nc === "+" || nc === "-") && (line.charAt(i - 1) === "e" || line.charAt(i - 1) === "E"))) i += 1
                        else break
                    }
                }
                emit(line.slice(numStart, i), pal.number)
                continue
            }

            if (isIdentStart(c)) {
                var wordStart = i
                while (i < n && isIdentChar(line.charAt(i))) i += 1
                word = line.slice(wordStart, i)
                nextNonSpace = i
                while (nextNonSpace < n && (line.charAt(nextNonSpace) === " " || line.charAt(nextNonSpace) === "\t")) nextNonSpace += 1

                color = null
                if (kwSet[word]) color = pal.keyword
                else if (word.charAt(0) === "$") color = pal.variable
                else if (nextNonSpace < n && line.charAt(nextNonSpace) === "(") color = pal.function
                else if (capTypes && word.charAt(0) >= "A" && word.charAt(0) <= "Z") color = pal.type
                else if (dataKeys && nextNonSpace < n && line.charAt(nextNonSpace) === ":") color = pal.type
                emit(word, color)
                continue
            }

            if (c === "$" && dollarVars) {
                var varStart = i
                i += 1
                if (line.charAt(i) === "{") {
                    var braceEnd = line.indexOf("}", i)
                    if (braceEnd !== -1) i = braceEnd + 1
                } else if (isIdentStart(line.charAt(i))) {
                    while (i < n && isIdentChar(line.charAt(i))) i += 1
                } else {
                    i += 1
                }
                emit(line.slice(varStart, i), pal.variable)
                continue
            }

            emit(c, null)
            i += 1
        }

        return out.join("")
    }

    function highlight(code, lang, pal) {
        code = String(code || "").replace(/\n+$/, "")
        var id = langId(lang)
        var kw = keywordSet(lang)
        var kwSet = {}
        var parts = kw.split(/\s+/)
        for (var k = 0; k < parts.length; k++) kwSet[parts[k]] = true

        var capTypes = (id === "c" || id === "go" || id === "java" || id === "kotlin" ||
                        id === "rust" || id === "ts" || id === "js" || id === "python" || id === "php")
        var hashComment = (id === "bash" || id === "python" || id === "ruby" || id === "yaml" ||
                           id === "dockerfile" || id === "cmake" || id === "lua" || id === "ini" || id === "toml")
        var dataKeys = (id === "json" || id === "yaml" || id === "toml" || id === "ini")
        var dollarVars = (id === "bash" || id === "ruby")

        var lines = code.split("\n")
        var total = lines.length
        var digits = 1
        var t = total
        while (t >= 10) { digits += 1; t = Math.floor(t / 10) }
        if (digits < 2) digits = 2

        var out = []
        for (var li = 0; li < total; li++) {
            var num = String(li + 1)
            while (num.length < digits) num = " " + num
            var padded = num.replace(/ /g, "&nbsp;") + "&nbsp;&nbsp;"
            out.push('<span style="color:' + (pal.lineNumber || pal.comment) + '">' + padded + "</span>")
            out.push(tokenizeLine(lines[li], kwSet, id, capTypes, hashComment, dataKeys, dollarVars, pal))
            if (li < total - 1) out.push("\n")
        }

        return '<pre style="margin:0; white-space:pre">' + out.join("") + "</pre>"
    }
}