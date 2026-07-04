//
//  PaymentSafariView.swift
//  Sales Associate
//
//  Presents the Razorpay hosted checkout inside an app-owned WKWebView. Keeping
//  the web surface in our view hierarchy avoids the iPad simulator/mirroring
//  orientation bug where SFSafariViewController rendered correctly but mapped
//  taps to the wrong coordinates.
//

import SwiftUI
import WebKit

struct PaymentSafariView: View {
    let url: URL
    var onFinish: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onFinish) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.black))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Razorpay")

                Spacer()
                Label("Secure Razorpay checkout", systemImage: "lock.shield.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 12)
            .background(.regularMaterial)

            RazorpayWebView(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

private struct RazorpayWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let targetURL = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            // Keep Razorpay/HTTPS pages in the secure web view. Hand UPI/app deep
            // links to iOS so installed payment apps can open on real devices.
            if targetURL.scheme == "https" || targetURL.scheme == "http" {
                decisionHandler(.allow)
            } else {
                UIApplication.shared.open(targetURL)
                decisionHandler(.cancel)
            }
        }
    }
}
