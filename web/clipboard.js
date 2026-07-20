// Shared clipboard bridge for macroquad-toolkit games.
//
// Provides clipboard_write_text_extern, declared by games that expose a
// "copy to clipboard" action (see the_enchanters_ledger/src/browser_clipboard.rs).
// Loaded after mq_js_bundle.js and before the game wasm, alongside storage.js.
//
// Return codes, matching the Rust side:
//   2 = copied synchronously   1 = async copy attempted   0 = unavailable
//
// It takes a raw (ptr, len) rather than a JsObject, so it needs no sapp_jsutils
// helpers. Registering it for every game is harmless: a game that never calls
// the extern simply never triggers it.

(function () {
    function installClipboardBridge(imports) {
        const copyFromTextArea = (textArea) => {
            textArea.focus();
            textArea.select();
            textArea.setSelectionRange(0, textArea.value.length);
            let copied = false;
            try {
                copied = document.execCommand("copy");
            } catch (error) {
                console.error("clipboard execCommand failed:", error);
            }
            return copied;
        };
        const copyTextNow = (text) => {
            let textArea = document.getElementById("wh-hidden-clipboard");
            if (!textArea) {
                textArea = document.createElement("textarea");
                textArea.id = "wh-hidden-clipboard";
                textArea.setAttribute("readonly", "readonly");
                textArea.style.position = "fixed";
                textArea.style.left = "-10000px";
                textArea.style.top = "0";
                textArea.style.width = "1px";
                textArea.style.height = "1px";
                textArea.style.opacity = "0";
                document.body.appendChild(textArea);
            }
            textArea.value = text;
            const copied = copyFromTextArea(textArea);
            const canvas = document.getElementById("glcanvas");
            if (canvas) {
                canvas.focus();
            }
            return copied;
        };
        const showDiagnosticCopyPanel = (text) => {
            let panel = document.getElementById("wh-diagnostic-panel");
            if (!panel) {
                panel = document.createElement("div");
                panel.id = "wh-diagnostic-panel";
                panel.style.position = "fixed";
                panel.style.right = "16px";
                panel.style.bottom = "16px";
                panel.style.width = "min(640px, calc(100vw - 32px))";
                panel.style.maxHeight = "72vh";
                panel.style.padding = "12px";
                panel.style.background = "#11100d";
                panel.style.border = "1px solid #b78a32";
                panel.style.boxShadow = "0 16px 40px rgba(0, 0, 0, 0.45)";
                panel.style.zIndex = "9999";
                panel.style.color = "#f2dfb2";
                panel.style.fontFamily = "monospace";

                const title = document.createElement("div");
                title.textContent = "Diagnostic Log";
                title.style.fontWeight = "700";
                title.style.marginBottom = "8px";
                panel.appendChild(title);

                const textArea = document.createElement("textarea");
                textArea.id = "wh-diagnostic-text";
                textArea.setAttribute("readonly", "readonly");
                textArea.style.boxSizing = "border-box";
                textArea.style.width = "100%";
                textArea.style.height = "260px";
                textArea.style.maxHeight = "46vh";
                textArea.style.resize = "vertical";
                textArea.style.background = "#f1dfad";
                textArea.style.color = "#1c1307";
                textArea.style.border = "1px solid #6d4f1f";
                textArea.style.padding = "8px";
                textArea.style.font = "12px monospace";
                panel.appendChild(textArea);

                const status = document.createElement("div");
                status.id = "wh-diagnostic-status";
                status.textContent = "Browser blocked automatic copy. Use Copy or Download.";
                status.style.marginTop = "8px";
                status.style.fontSize = "12px";
                status.style.color = "#d8bd82";
                panel.appendChild(status);

                const row = document.createElement("div");
                row.style.display = "flex";
                row.style.gap = "8px";
                row.style.marginTop = "10px";
                panel.appendChild(row);

                const copyButton = document.createElement("button");
                copyButton.type = "button";
                copyButton.textContent = "Copy";
                copyButton.onclick = () => {
                    const currentText = textArea.value;
                    if (copyFromTextArea(textArea)) {
                        status.textContent = "Copied diagnostic log.";
                        return;
                    }
                    if (
                        window.isSecureContext &&
                        navigator.clipboard &&
                        typeof navigator.clipboard.writeText === "function"
                    ) {
                        navigator.clipboard.writeText(currentText)
                            .then(() => status.textContent = "Copied diagnostic log.")
                            .catch((error) => {
                                console.error("clipboard_write failed:", error);
                                status.textContent = "Copy was blocked. The text is selected.";
                            });
                    } else {
                        status.textContent = "Copy was blocked. The text is selected.";
                    }
                };
                row.appendChild(copyButton);

                const downloadButton = document.createElement("button");
                downloadButton.type = "button";
                downloadButton.textContent = "Download";
                downloadButton.onclick = () => {
                    const blob = new Blob([textArea.value], { type: "text/plain" });
                    const url = URL.createObjectURL(blob);
                    const link = document.createElement("a");
                    link.href = url;
                    link.download = "diagnostic_log.txt";
                    link.click();
                    URL.revokeObjectURL(url);
                };
                row.appendChild(downloadButton);

                const closeButton = document.createElement("button");
                closeButton.type = "button";
                closeButton.textContent = "Close";
                closeButton.onclick = () => {
                    panel.remove();
                    const canvas = document.getElementById("glcanvas");
                    if (canvas) {
                        canvas.focus();
                    }
                };
                row.appendChild(closeButton);

                document.body.appendChild(panel);
            }

            const textArea = document.getElementById("wh-diagnostic-text");
            textArea.value = text;
            textArea.focus();
            textArea.select();
            textArea.setSelectionRange(0, text.length);
        };
        imports.env.clipboard_write_text_extern = (ptr, len) => {
            const text = UTF8ToString(ptr, len);
            if (copyTextNow(text)) {
                return 2;
            }
            showDiagnosticCopyPanel(text);
            if (
                window.isSecureContext &&
                navigator.clipboard &&
                typeof navigator.clipboard.writeText === "function"
            ) {
                navigator.clipboard.writeText(text).catch((error) => {
                    console.error("clipboard_write failed:", error);
                });
                return 1;
            }
            console.error("clipboard_write failed: browser clipboard API unavailable");
            return 0;
        };
    }

    miniquad_add_plugin({
        register_plugin: installClipboardBridge,
        version: 1,
        name: "clipboard_bridge"
    });
})();
