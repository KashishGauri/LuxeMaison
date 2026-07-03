import SwiftUI
import AVFoundation
import UIKit
import Combine

// MARK: - Capture Store screen

/// Full-screen store-capture flow opened from the "Capture Store" quick action.
/// The associate snaps as many boutique/display photos as they want from a live
/// camera, then taps "Send Report" to turn them into a single PDF that is uploaded
/// to Supabase Storage and recorded in the `planogram` table.
struct CaptureStoreView: View {
    /// The logged-in associate's id — stored as `planogram.created_by`.
    let associateID: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = StoreCameraModel()

    @State private var capturedImages: [UIImage] = []
    @State private var phase: Phase = .capturing
    @State private var errorMessage: String?

    private enum Phase: Equatable { case capturing, submitting, success }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                switch phase {
                case .capturing, .submitting:
                    captureLayout
                case .success:
                    successView
                }
            }
            .navigationTitle("Capture Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.muted)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .onAppear {
            camera.onImageCaptured = { image in
                // Keep memory + PDF size sane by downscaling before storing.
                capturedImages.append(image.resizedToMaxDimension(1600))
            }
            camera.requestAndStart()
        }
        .onDisappear { camera.stop() }
    }

    // MARK: Capture layout

    private var captureLayout: some View {
        VStack(spacing: 18) {
            cameraArea
                .frame(maxWidth: .infinity)
                .frame(minHeight: 260)
                .layoutPriority(1)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.68, green: 0.22, blue: 0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            thumbnailStrip

            sendReportButton
        }
        .padding(20)
        .disabled(phase == .submitting)
    }

    private var cameraArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.9))

            switch camera.status {
            case .running:
                CameraPreviewView(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            case .configuring, .idle:
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text("Preparing camera…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            case .denied:
                cameraMessage(
                    icon: "camera.metering.none",
                    title: "Camera access is off",
                    message: "Enable camera access in Settings to capture store photos.",
                    showSettings: true
                )
            case .unavailable:
                cameraMessage(
                    icon: "video.slash.fill",
                    title: "Camera unavailable",
                    message: "No camera is available on this device.",
                    showSettings: false
                )
            }

            // Shutter button overlay
            if camera.status == .running {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        shutterButton
                        Spacer()
                    }
                    .padding(.bottom, 22)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if !capturedImages.isEmpty {
                Text("\(capturedImages.count) captured")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.goldGradient, in: Capsule())
                    .padding(14)
            }
        }
    }

    private var shutterButton: some View {
        Button {
            camera.capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 74, height: 74)
                Circle()
                    .fill(.white)
                    .frame(width: 60, height: 60)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture photo")
    }

    private func cameraMessage(icon: String, title: String, message: String, showSettings: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            if showSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.gold)
                .padding(.top, 4)
            }
        }
        .padding(28)
    }

    private var thumbnailStrip: some View {
        Group {
            if capturedImages.isEmpty {
                Text("Tap the shutter to capture store photos. Snap as many as you need, then send the report.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Theme.line, lineWidth: 1)
                                )
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        capturedImages.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.body.weight(.bold))
                                            .foregroundStyle(.white, .black.opacity(0.55))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(4)
                                    .accessibilityLabel("Remove photo \(index + 1)")
                                }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: 92)
            }
        }
    }

    private var sendReportButton: some View {
        Button {
            sendReport()
        } label: {
            HStack(spacing: 10) {
                if phase == .submitting {
                    ProgressView().tint(.white)
                    Text("Sending report…")
                } else {
                    Image(systemName: "doc.badge.arrow.up.fill")
                        .font(.headline.weight(.black))
                    Text("Send Report")
                }
            }
            .font(.headline.weight(.black))
            .tracking(0.4)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                (capturedImages.isEmpty ? AnyShapeStyle(Theme.muted.opacity(0.4)) : AnyShapeStyle(Theme.goldGradient)),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(capturedImages.isEmpty || phase == .submitting)
    }

    // MARK: Success

    private var successView: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 66, weight: .bold))
                .foregroundStyle(Theme.gold)
            Text("Report Sent")
                .font(.title.weight(.black))
                .foregroundStyle(Theme.ink)
            Text("Your store capture PDF has been submitted for review.")
                .font(.headline.weight(.medium))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .padding(30)
    }

    // MARK: Submit

    private func sendReport() {
        guard !capturedImages.isEmpty else { return }
        phase = .submitting
        errorMessage = nil

        let images = capturedImages
        let title = "Store Capture — \(Self.timestampString())"

        Task {
            let pdfData = PlanogramPDFBuilder.makePDF(images: images, title: title)
            do {
                // Mock/demo associates use non-uuid ids ("…-id"); `created_by` is a
                // foreign key to a real User row, so skip the DB write in demo mode
                // (the PDF is still generated and the flow reports success).
                if associateID.hasSuffix("-id") {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                } else {
                    try await SupabaseDBService.shared.submitPlanogramReport(
                        pdfData: pdfData,
                        title: title,
                        createdBy: associateID
                    )
                }
                camera.stop()
                phase = .success
            } catch {
                phase = .capturing
                errorMessage = "Couldn't send the report. Check your connection and try again."
            }
        }
    }

    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, h:mm a"
        return formatter.string(from: Date())
    }
}

// MARK: - Live camera (AVFoundation)

/// Owns the `AVCaptureSession` for the store-capture screen and delivers each
/// captured photo back to SwiftUI via `onImageCaptured`. Session configuration and
/// start/stop run on a dedicated queue so the main thread is never blocked.
final class StoreCameraModel: NSObject, ObservableObject {
    enum Status: Equatable { case idle, configuring, running, denied, unavailable }

    @Published var status: Status = .idle

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.salesassociate.storecamera.session")
    private var isConfigured = false

    /// Called on the main thread with each captured photo.
    var onImageCaptured: ((UIImage) -> Void)?

    /// Requests camera permission (if needed) and starts the live preview.
    func requestAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndStart()
                    } else {
                        self?.status = .denied
                    }
                }
            }
        default:
            status = .denied
        }
    }

    private func configureAndStart() {
        status = .configuring
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                    ?? AVCaptureDevice.default(for: .video)

                guard let camera = device,
                      let input = try? AVCaptureDeviceInput(device: camera),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.status = .unavailable }
                    return
                }
                self.session.addInput(input)

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }
                self.session.commitConfiguration()
                self.isConfigured = true
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async { self.status = .running }
        }
    }

    /// Captures a single still photo; delivered via `onImageCaptured`.
    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, self.session.isRunning else { return }
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }
}

extension StoreCameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onImageCaptured?(image)
        }
    }
}

/// Hosts the `AVCaptureVideoPreviewLayer` for the live camera feed.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - PDF builder

/// Renders captured store photos into a single multi-page PDF — one photo per A4
/// page with a title/date header.
enum PlanogramPDFBuilder {
    static func makePDF(images: [UIImage], title: String) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
        let margin: CGFloat = 28
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let stamp = dateFormatter.string(from: Date())

        return renderer.pdfData { context in
            for (index, image) in images.enumerated() {
                context.beginPage()

                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 15),
                    .foregroundColor: UIColor(white: 0.15, alpha: 1)
                ]
                (title as NSString).draw(at: CGPoint(x: margin, y: margin - 6), withAttributes: titleAttrs)

                let subtitle = "\(stamp)   •   Photo \(index + 1) of \(images.count)"
                let subtitleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor(white: 0.45, alpha: 1)
                ]
                (subtitle as NSString).draw(at: CGPoint(x: margin, y: margin + 16), withAttributes: subtitleAttrs)

                let contentTop = margin + 40
                let area = CGRect(
                    x: margin,
                    y: contentTop,
                    width: pageRect.width - margin * 2,
                    height: pageRect.height - contentTop - margin
                )
                let imageSize = image.size
                guard imageSize.width > 0, imageSize.height > 0 else { continue }
                let scale = min(area.width / imageSize.width, area.height / imageSize.height)
                let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                let origin = CGPoint(x: area.midX - drawSize.width / 2, y: area.midY - drawSize.height / 2)
                image.draw(in: CGRect(origin: origin, size: drawSize))
            }
        }
    }
}

// MARK: - Helpers

fileprivate extension UIImage {
    /// Returns a copy scaled so its longest side is at most `maxDimension` points,
    /// with orientation normalized. Returns self when already small enough.
    func resizedToMaxDimension(_ maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
