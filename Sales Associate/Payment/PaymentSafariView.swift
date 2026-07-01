//
//  PaymentSafariView.swift
//  Sales Associate
//
//  Presents the Razorpay hosted checkout (payment link) inside the app using
//  SFSafariViewController — the customer pays by card / UPI / QR on Razorpay's
//  secure page, then returns to the app.
//

import SwiftUI
import SafariServices

struct PaymentSafariView: UIViewControllerRepresentable {
    let url: URL
    var onFinish: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onFinish()
        }
    }
}
