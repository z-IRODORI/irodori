//
//  WebView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/24.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL?

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = url else { return }

        let request = URLRequest(url: url)
        webView.load(request)
    }
}
