import SwiftUI
import WebKit

struct DUPRWebView: UIViewRepresentable {
    let onResult: (DUPRAuthResult) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult, onError: onError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let ucc = WKUserContentController()

        let js = """
        (function() {
            function send(handler, data) {
                try {
                    window.webkit.messageHandlers[handler].postMessage(
                        typeof data === 'string' ? data : JSON.stringify(data)
                    );
                } catch(e) {}
            }

            // ── 1. Fake parent/top/opener so DUPR thinks it's in an iframe ──
            var fakeParent = {
                postMessage: function(msg) {
                    try {
                        var d = typeof msg === 'string' ? JSON.parse(msg) : msg;
                        if (d && d.userToken) { send('duprAuth', msg); return; }
                    } catch(e) {}
                    send('duprRaw', {source:'fakeParent', msg: typeof msg === 'string' ? msg : JSON.stringify(msg)});
                },
                location: window.location
            };
            ['parent','top','opener'].forEach(function(k) {
                try { Object.defineProperty(window, k, {get: function(){return fakeParent;}, configurable:true}); } catch(e) {}
            });

            // ── 2. Intercept all localStorage / sessionStorage writes ──
            var _set = Storage.prototype.setItem;
            Storage.prototype.setItem = function(key, value) {
                _set.call(this, key, value);
                send('duprStorage', {key: key, value: value});
            };

            // ── 3. Intercept fetch responses ──
            var _fetch = window.fetch;
            window.fetch = function(input, init) {
                var url = (typeof input === 'string') ? input : (input && input.url) || '';
                var p = _fetch.apply(this, arguments);
                p.then(function(resp) {
                    try {
                        resp.clone().text().then(function(body) {
                            send('duprNetwork', {url: url, body: body.substring(0, 1000)});
                        });
                    } catch(e) {}
                }).catch(function(){});
                return p;
            };

            // ── 4. Intercept XHR responses ──
            var _open = XMLHttpRequest.prototype.open;
            var _send = XMLHttpRequest.prototype.send;
            XMLHttpRequest.prototype.open = function(m, u) { this._u = u; return _open.apply(this, arguments); };
            XMLHttpRequest.prototype.send = function() {
                this.addEventListener('load', function() {
                    try { send('duprNetwork', {url: this._u || '', body: (this.responseText||'').substring(0, 1000)}); } catch(e) {}
                });
                return _send.apply(this, arguments);
            };

            // ── 5. postMessage event listener ──
            window.addEventListener('message', function(e) {
                try {
                    var d = typeof e.data === 'string' ? JSON.parse(e.data) : e.data;
                    if (d && d.userToken) { send('duprAuth', e.data); return; }
                } catch(e2) {}
                send('duprRaw', {source:'messageEvent', data: typeof e.data === 'string' ? e.data : JSON.stringify(e.data)});
            }, false);
        })();
        """

        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        ucc.addUserScript(script)
        ucc.add(context.coordinator, name: "duprAuth")
        ucc.add(context.coordinator, name: "duprStorage")
        ucc.add(context.coordinator, name: "duprNetwork")
        ucc.add(context.coordinator, name: "duprRaw")

        let config = WKWebViewConfiguration()
        config.userContentController = ucc

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: DUPRConfig.ssoURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onResult: (DUPRAuthResult) -> Void
        let onError: (String) -> Void
        private var didReceiveResult = false

        // Accumulate storage writes to reconstruct auth result
        private var storedTokens: [String: String] = [:]

        init(onResult: @escaping (DUPRAuthResult) -> Void, onError: @escaping (String) -> Void) {
            self.onResult = onResult
            self.onError = onError
        }

        // MARK: Script messages

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard !didReceiveResult else { return }

            switch message.name {

            case "duprAuth":
                // Direct postMessage hit — parse immediately
                guard let str = message.body as? String,
                      let data = str.data(using: .utf8),
                      let result = try? JSONDecoder().decode(DUPRAuthResult.self, from: data) else { return }
                deliver(result)

            case "duprStorage":
                // A key/value was written to localStorage/sessionStorage
                guard let dict = message.body as? [String: Any] else { return }
                let key   = (dict["key"]   as? String) ?? ""
                let value = (dict["value"] as? String) ?? ""
                handleStorageWrite(key: key, value: value)

            case "duprNetwork":
                // An XHR/fetch response body
                guard let dict = message.body as? [String: Any],
                      let body = dict["body"] as? String else { return }
                tryParseAuthJSON(body)

            case "duprRaw":
                // Raw postMessage content that didn't match — try parsing anyway
                if let dict = message.body as? [String: Any],
                   let raw = dict["msg"] as? String ?? dict["data"] as? String {
                    tryParseAuthJSON(raw)
                }

            default: break
            }
        }

        // MARK: Storage accumulation

        private func handleStorageWrite(key: String, value: String) {
            // Store the raw key/value
            storedTokens[key] = value

            // Try parsing the value itself as a full auth result
            tryParseAuthJSON(value)

            // Try to find token-like values under common key names
            let lowerKey = key.lowercased()
            let tokenKeys = ["usertoken", "accesstoken", "access_token", "token"]
            let refreshKeys = ["refreshtoken", "refresh_token"]
            let duprIdKeys = ["duprid", "dupr_id"]
            let idKeys = ["id", "userid", "user_id"]

            if tokenKeys.contains(lowerKey)  { storedTokens["userToken"]    = value }
            if refreshKeys.contains(lowerKey) { storedTokens["refreshToken"] = value }
            if duprIdKeys.contains(lowerKey)  { storedTokens["duprId"]       = value }
            if idKeys.contains(lowerKey)      { storedTokens["id"]            = value }

            // Check if we have enough pieces
            if let userToken    = storedTokens["userToken"],
               let refreshToken = storedTokens["refreshToken"],
               let duprId       = storedTokens["duprId"] {
                let result = DUPRAuthResult(
                    userToken: userToken,
                    refreshToken: refreshToken,
                    id: storedTokens["id"] ?? "",
                    duprId: duprId,
                    stats: nil
                )
                deliver(result)
            }
        }

        private func tryParseAuthJSON(_ text: String) {
            guard !didReceiveResult else { return }
            guard let data = text.data(using: .utf8) else { return }

            // Try direct decode
            if let result = try? JSONDecoder().decode(DUPRAuthResult.self, from: data) {
                deliver(result); return
            }

            // Try as a dictionary and look for auth fields at any depth
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                extractFromDict(dict)
            }
        }

        private func extractFromDict(_ dict: [String: Any]) {
            // Flatten nested JSON (Redux Persist serializes sub-slices as JSON strings)
            var flat = dict
            for (key, value) in dict {
                if let str = value as? String,
                   let nested = try? JSONSerialization.jsonObject(with: str.data(using: .utf8) ?? Data()) as? [String: Any] {
                    for (k, v) in nested { flat[k] = v }
                }
            }

            // Look for token fields case-insensitively
            func find(_ keys: [String]) -> String? {
                for k in keys {
                    if let v = flat[k] as? String { return v }
                    if let v = flat[k.lowercased()] as? String { return v }
                    // camelCase variants
                    let camel = k.prefix(1).lowercased() + k.dropFirst()
                    if let v = flat[String(camel)] as? String { return v }
                }
                return nil
            }

            guard let userToken    = find(["userToken", "access_token", "accessToken", "token"]),
                  let refreshToken = find(["refreshToken", "refresh_token"]),
                  let duprId       = find(["duprId", "dupr_id", "DUPRId"]) else { return }

            let result = DUPRAuthResult(
                userToken: userToken,
                refreshToken: refreshToken,
                id: find(["id", "userId", "user_id"]) ?? "",
                duprId: duprId,
                stats: nil
            )
            deliver(result)
        }

        // MARK: Navigation delegate

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = action.request.url, !didReceiveResult {
                if let result = tokenResult(from: url) {
                    deliver(result)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !didReceiveResult else { return }

            // Dump all localStorage + sessionStorage content after each page load
            let dumpJS = """
            (function() {
                var out = {ls: {}, ss: {}};
                try { for (var i=0;i<localStorage.length;i++){var k=localStorage.key(i);out.ls[k]=localStorage.getItem(k);} } catch(e){}
                try { for (var i=0;i<sessionStorage.length;i++){var k=sessionStorage.key(i);out.ss[k]=sessionStorage.getItem(k);} } catch(e){}
                return JSON.stringify(out);
            })();
            """
            webView.evaluateJavaScript(dumpJS) { [weak self] result, _ in
                guard let self, !self.didReceiveResult,
                      let json = result as? String,
                      let data = json.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return }

                for storage in [dict["ls"], dict["ss"]].compactMap({ $0 as? [String: Any] }) {
                    for (k, v) in storage {
                        if let str = v as? String {
                            self.handleStorageWrite(key: k, value: str)
                        }
                    }
                }
            }
        }

        // MARK: Helpers

        private func tokenResult(from url: URL) -> DUPRAuthResult? {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let qItems = comps?.queryItems ?? []
            let fItems = URLComponents(string: "?\(url.fragment ?? "")")?.queryItems ?? []
            let params = Dictionary(uniqueKeysWithValues: (qItems + fItems).compactMap {
                guard let v = $0.value else { return nil as (String, String)? }
                return ($0.name, v)
            })
            guard let ut = params["userToken"] ?? params["access_token"],
                  let rt = params["refreshToken"] ?? params["refresh_token"],
                  let did = params["duprId"] else { return nil }
            return DUPRAuthResult(userToken: ut, refreshToken: rt, id: params["id"] ?? "", duprId: did, stats: nil)
        }

        private func deliver(_ result: DUPRAuthResult) {
            guard !didReceiveResult else { return }
            didReceiveResult = true
            DispatchQueue.main.async { self.onResult(result) }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard !didReceiveResult else { return }
            DispatchQueue.main.async { self.onError("Failed to load. Please check your connection.") }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard !didReceiveResult else { return }
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            DispatchQueue.main.async { self.onError("Failed to connect to DUPR. Please try again.") }
        }
    }
}
