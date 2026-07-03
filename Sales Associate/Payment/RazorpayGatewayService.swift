//
//  RazorpayGatewayService.swift
//  Sales Associate
//
//  Thin client for the Razorpay UPI QR backend (Supabase Edge Functions). The
//  app never sees the Razorpay secret — it only calls these functions with the
//  Supabase anon key.
//

import Foundation

enum PaymentGatewayConfig {
    /// Supabase Edge Functions base for project `zfengirsvsjikrhxrfit`.
    static let functionsBaseURL = "https://zfengirsvsjikrhxrfit.supabase.co/functions/v1"
    /// Same public anon key the app already uses for the REST API.
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmZW5naXJzdnNqaWtyaHhyZml0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0MTg5NTIsImV4cCI6MjA5Nzk5NDk1Mn0.rk57GzYVJDkHtEH649eXekzqox0s3O3nH3u8f5KHY5M"
}

struct QRCreateResult {
    let qrID: String
    let imageURL: URL?
    let closeBy: Date
    let amountPaise: Int
}

struct QRStatusResult {
    enum Status: String { case created, paid, expired, failed, unknown }
    let status: Status
    let amountPaidPaise: Int?
    let paymentID: String?
}

struct PaymentLinkResult {
    let linkID: String
    let shortURL: URL
    let amountPaise: Int
}

enum GatewayError: LocalizedError {
    case badURL
    case server(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid gateway URL."
        case .server(let message): return message
        case .decoding: return "Unexpected response from the payment gateway."
        }
    }
}

struct RazorpayGatewayService {
    static let shared = RazorpayGatewayService()

    func createQR(localOrderID: String, amountPaise: Int, description: String, closeBySeconds: Int) async throws -> QRCreateResult {
        let payload: [String: Any] = [
            "localOrderId": localOrderID,
            "amountPaise": amountPaise,
            "description": description,
            "closeBySeconds": closeBySeconds,
        ]
        let json = try await post("razorpay-create-qr", body: payload)

        guard let qrID = json["qrId"] as? String,
              let closeByUnix = json["closeBy"] as? Double else {
            throw GatewayError.decoding
        }
        let imageURL = (json["imageUrl"] as? String).flatMap(URL.init(string:))
        return QRCreateResult(
            qrID: qrID,
            imageURL: imageURL,
            closeBy: Date(timeIntervalSince1970: closeByUnix),
            amountPaise: (json["amountPaise"] as? Int) ?? amountPaise
        )
    }

    /// Creates a Razorpay Payment Link (hosted checkout: card / UPI / QR).
    func createPaymentLink(localOrderID: String, amountPaise: Int, description: String) async throws -> PaymentLinkResult {
        let payload: [String: Any] = [
            "localOrderId": localOrderID,
            "amountPaise": amountPaise,
            "description": description,
        ]
        let json = try await post("razorpay-create-link", body: payload)
        guard let linkID = json["linkId"] as? String,
              let urlString = json["shortUrl"] as? String,
              let url = URL(string: urlString) else {
            throw GatewayError.decoding
        }
        return PaymentLinkResult(linkID: linkID, shortURL: url, amountPaise: (json["amountPaise"] as? Int) ?? amountPaise)
    }

    func fetchStatus(qrID: String) async throws -> QRStatusResult {
        let json = try await post("razorpay-payment-status", body: ["qrId": qrID])
        let status = QRStatusResult.Status(rawValue: (json["status"] as? String) ?? "unknown") ?? .unknown
        return QRStatusResult(
            status: status,
            amountPaidPaise: json["amountPaidPaise"] as? Int,
            paymentID: json["paymentId"] as? String
        )
    }

    // MARK: - Transport

    private func post(_ function: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(PaymentGatewayConfig.functionsBaseURL)/\(function)") else {
            throw GatewayError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(PaymentGatewayConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(PaymentGatewayConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GatewayError.decoding }

        let object = try? JSONSerialization.jsonObject(with: data)
        let dictionary = object as? [String: Any] ?? [:]

        guard (200...299).contains(http.statusCode) else {
            // Prefer Razorpay's own reason (detail.error.description, e.g. "test mode
            // limit of 30 reached for payment_link") over the generic wrapper message.
            var message = (dictionary["error"] as? String) ?? "Gateway error (\(http.statusCode))."
            if let detail = dictionary["detail"] as? [String: Any],
               let razorpayError = detail["error"] as? [String: Any],
               let description = razorpayError["description"] as? String,
               !description.isEmpty {
                message = description
            }
            throw GatewayError.server(message)
        }
        return dictionary
    }
}
