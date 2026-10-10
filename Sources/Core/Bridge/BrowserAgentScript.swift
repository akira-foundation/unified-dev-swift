import Foundation

public enum BrowserScriptValue: Sendable, Equatable {
    case text(String)
    case number(Int)
    case flag(Bool)
}

public enum BrowserAgentScript: Sendable, Equatable {
    case outline
    case click(BrowserAgentReference)
    case fill(BrowserAgentReference, String)
    case press(BrowserKeyPress, BrowserAgentReference?)
    case settled(BrowserWaitCondition)

    public static let world = "unified-dev-agent"

    public static let labelLimit = 80

    public var arguments: [String: BrowserScriptValue] {
        switch self {
        case .outline:
            [
                "chars": .number(BrowserPageOutline.nameLimit),
                "limit": .number(BrowserPageOutline.elementLimit),
            ]
        case .click(let reference):
            ["index": .number(reference.index), "chars": .number(Self.labelLimit)]
        case .fill(let reference, let written):
            [
                "index": .number(reference.index),
                "text": .text(written),
                "chars": .number(Self.labelLimit),
            ]
        case .press(let key, let reference):
            [
                "key": .text(key.rawValue),
                "index": .number(reference?.index ?? 0),
                "chars": .number(Self.labelLimit),
            ]
        case .settled(.load):
            [:]
        case .settled(.text(let wanted)):
            ["text": .text(wanted)]
        case .settled(.gone(let unwanted)):
            ["gone": .text(unwanted)]
        }
    }

    public var reference: BrowserAgentReference? {
        switch self {
        case .click(let reference): reference
        case .fill(let reference, _): reference
        case .press(_, let reference): reference
        case .outline, .settled: nil
        }
    }

    public var body: String {
        switch self {
        case .outline: Self.prelude + Self.labelling + Self.secrecy + Self.surveying + Self.outlining
        case .click: Self.prelude + Self.labelling + Self.pointing + Self.clicking
        case .fill: Self.prelude + Self.labelling + Self.secrecy + Self.pointing + Self.filling
        case .press: Self.prelude + Self.labelling + Self.pointing + Self.pressing
        case .settled(.load): Self.prelude + Self.loaded
        case .settled(.text): Self.prelude + Self.appearing
        case .settled(.gone): Self.prelude + Self.leaving
        }
    }

    static let prelude = #"""
        var agent = window.__unifieddevAgent;
        if (!agent) {
          agent = { elements: [], href: "" };
          window.__unifieddevAgent = agent;
        }
        if (agent.href !== location.href) {
          agent.elements = [];
          agent.href = location.href;
        }

        """#

    static let labelling = #"""
        function words(node) {
          var label = node.getAttribute("aria-label");
          if (!label && node.labels && node.labels.length > 0) label = node.labels[0].innerText;
          if (!label) label = node.getAttribute("placeholder");
          if (!label) label = node.getAttribute("title");
          if (!label) label = node.getAttribute("alt");
          if (!label) label = node.innerText;
          if (!label) label = node.getAttribute("name");
          return String(label || "").replace(/\s+/g, " ").trim().slice(0, chars);
        }

        """#

    static let secrecy = #"""
        function secret(node) {
          if (node.tagName.toLowerCase() !== "input") return false;
          var kind = String(node.getAttribute("type") || "").toLowerCase();
          if (kind === "password") return true;
          var fills = String(node.getAttribute("autocomplete") || "").toLowerCase();
          if (fills.indexOf("password") >= 0) return true;
          var style = typeof window.getComputedStyle === "function"
            ? window.getComputedStyle(node)
            : null;
          if (!style) return false;
          var masked = style.getPropertyValue("-webkit-text-security") || "";
          return masked !== "" && masked !== "none";
        }

        """#

    static let pointing = #"""
        function pointedAt() {
          if (index <= 0) return null;
          var node = agent.elements[index - 1];
          return node && node.isConnected ? node : null;
        }
        function blocked(node) {
          return node.disabled === true || node.getAttribute("aria-disabled") === "true";
        }

        """#

    static let surveying = #"""
        var groups = ["form", "fieldset", "nav", "section", "aside", "table", "ul", "ol", "dialog"];
        function naming(node) {
          var given = node.getAttribute("role");
          if (given) return given;
          var tag = node.tagName.toLowerCase();
          if (tag === "a") return "link";
          if (tag === "select") return "combobox";
          if (tag === "textarea") return "textbox";
          if (tag === "summary") return "disclosure";
          if (tag !== "input") return tag;
          var kind = String(node.getAttribute("type") || "text").toLowerCase();
          if (kind === "checkbox" || kind === "radio") return kind;
          if (kind === "submit" || kind === "button" || kind === "reset") return "button";
          if (kind === "password" || kind === "text") return "textbox";
          return kind;
        }
        function nesting(node) {
          var levels = 0;
          var parent = node.parentElement;
          while (parent && parent !== document.body) {
            if (groups.indexOf(parent.tagName.toLowerCase()) >= 0) levels += 1;
            parent = parent.parentElement;
          }
          return levels;
        }
        function drawn(node) {
          if (node.hidden) return false;
          var style = typeof window.getComputedStyle === "function"
            ? window.getComputedStyle(node)
            : null;
          if (style && (style.visibility === "hidden" || style.display === "none")) return false;
          return node.getClientRects().length > 0;
        }

        """#

    static let outlining = #"""
        var reach = [
          "a[href]", "button", "input", "select", "textarea", "summary",
          "[role]", "[contenteditable=\"true\"]"
        ].join(", ");
        var nodes = document.querySelectorAll(reach);
        var listed = [];
        var total = 0;
        agent.elements = [];
        agent.href = location.href;
        for (var i = 0; i < nodes.length; i += 1) {
          var node = nodes[i];
          if (!drawn(node)) continue;
          total += 1;
          if (total > limit) continue;
          var kind = String(node.getAttribute("type") || "").toLowerCase();
          var held = typeof node.value === "string" ? node.value : null;
          var ticked = null;
          var ticks = kind === "checkbox" || kind === "radio";
          if (ticks) ticked = node.checked === true;
          if (ticked === null && node.hasAttribute("aria-checked")) {
            ticked = node.getAttribute("aria-checked") === "true";
          }
          if (ticks) held = null;
          var hidden = secret(node);
          agent.elements.push(node);
          listed.push({
            role: naming(node),
            name: words(node),
            value: hidden ? null : held,
            isPassword: hidden,
            valueLength: held === null ? 0 : held.length,
            isDisabled: node.disabled === true
              || node.getAttribute("aria-disabled") === "true",
            isChecked: ticked,
            depth: nesting(node)
          });
        }
        return JSON.stringify({ elements: listed, total: total });
        """#

    static let clicking = #"""
        var node = pointedAt();
        if (!node) return ["gone"];
        var label = words(node);
        if (blocked(node)) return ["disabled", label];
        if (typeof node.scrollIntoView === "function") node.scrollIntoView({ block: "center" });
        if (typeof node.focus === "function") node.focus({ preventScroll: true });
        node.click();
        return ["done", label];
        """#

    static let filling = #"""
        var node = pointedAt();
        if (!node) return ["gone"];
        var label = words(node);
        if (blocked(node) || node.readOnly === true) return ["disabled", label];
        var typable = [
          "", "text", "email", "search", "tel", "url", "password",
          "number", "date", "time", "month", "week", "datetime-local"
        ];
        var tag = node.tagName.toLowerCase();
        var kind = String(node.getAttribute("type") || "").toLowerCase();
        var editable = node.isContentEditable === true;
        var field = tag === "textarea" || (tag === "input" && typable.indexOf(kind) >= 0);
        if (!editable && !field) return ["unwritable", label];
        if (typeof node.focus === "function") node.focus({ preventScroll: true });
        if (editable) {
          node.textContent = text;
        } else {
          node.value = text;
        }
        node.dispatchEvent(new Event("input", { bubbles: true }));
        node.dispatchEvent(new Event("change", { bubbles: true }));
        var after = editable
          ? String(node.textContent || "").length
          : String(node.value || "").length;
        return [
          "done", label, String(after), secret(node) ? "password" : "field", String(text.length)
        ];
        """#

    static let pressing = #"""
        var spelling = {
          enter: ["Enter", 13], tab: ["Tab", 9], escape: ["Escape", 27],
          backspace: ["Backspace", 8], up: ["ArrowUp", 38], down: ["ArrowDown", 40],
          left: ["ArrowLeft", 37], right: ["ArrowRight", 39]
        };
        var spelt = spelling[key];
        if (!spelt) return ["unknown"];
        var node = pointedAt();
        if (index > 0 && !node) return ["gone"];
        var label = node ? words(node) : "";
        var target = node || document.activeElement || document.body;
        if (node && typeof node.focus === "function") node.focus({ preventScroll: true });
        var detail = {
          key: spelt[0], code: spelt[0], keyCode: spelt[1], which: spelt[1],
          bubbles: true, cancelable: true
        };
        target.dispatchEvent(new KeyboardEvent("keydown", detail));
        target.dispatchEvent(new KeyboardEvent("keyup", detail));
        return ["done", label];
        """#

    static let loaded = #"""
        return document.readyState === "complete" ? ["met"] : ["waiting"];
        """#

    static let appearing = #"""
        if (document.readyState === "loading") return ["waiting"];
        var body = document.body;
        var seen = body ? String(body.innerText || "") : "";
        return seen.indexOf(text) >= 0 ? ["met"] : ["waiting"];
        """#

    static let leaving = #"""
        if (document.readyState === "loading") return ["waiting"];
        var body = document.body;
        var seen = body ? String(body.innerText || "") : "";
        return seen.indexOf(gone) < 0 ? ["met"] : ["waiting"];
        """#
}
