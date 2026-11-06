//
//  BarcodeScannerScreen.swift
//  k-cal
//
//  The camera, for exactly as long as this screen is open. Nothing else in the app holds a capture session,
//  so closing the screen is what turns the camera off.
//

import AVFoundation
import SwiftUI

struct BarcodeScannerScreen: View {
    let onCode: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isTorchOn = false
    @State private var access = AVCaptureDevice.authorizationStatus(for: .video)

    private var hasCamera: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !hasCamera {
                message("No camera on this device", detail: "Barcode scanning needs a camera.")
            } else if access == .denied || access == .restricted {
                message("Camera access is off", detail: "Turn it on in Settings to scan barcodes.", settings: true)
            } else {
                BarcodeCamera(isTorchOn: isTorchOn, onCode: onCode).ignoresSafeArea()
                Viewfinder()
            }
            VStack {
                HStack {
                    circleButton("xmark", label: "Close") { dismiss() }
                    Spacer()
                    if hasCamera {
                        circleButton(isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill", label: "Flashlight") {
                            isTorchOn.toggle()
                        }
                    }
                }
                Spacer()
                Text("Line up the barcode in the frame")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
            }
            .padding()
        }
        .task {
            if access == .notDetermined {
                await AVCaptureDevice.requestAccess(for: .video)
                access = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .accessibilityLabel(label)
    }

    private func message(_ title: String, detail: String, settings: Bool = false) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill").font(.largeTitle)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).multilineTextAlignment(.center)
            if settings, let url = URL(string: UIApplication.openSettingsURLString) {
                Button { openURL(url) } label: { Text("Open Settings").foregroundStyle(Theme.onBrand) }.buttonStyle(.borderedProminent)
            }
        }
        .foregroundStyle(.white)
        .padding()
    }
}

/// Dims everything outside the scanning frame.
private struct Viewfinder: View {
    var body: some View {
        GeometryReader { geometry in
            let frame = CGRect(
                x: 32, y: geometry.size.height * 0.34,
                width: geometry.size.width - 64, height: 170
            )
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geometry.size))
                path.addRoundedRect(in: frame, cornerSize: CGSize(width: 20, height: 20))
            }
            .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct BarcodeCamera: UIViewControllerRepresentable {
    let isTorchOn: Bool
    let onCode: (String) -> Void

    func makeUIViewController(context _: Context) -> BarcodeCameraController {
        BarcodeCameraController(onCode: onCode)
    }

    func updateUIViewController(_ controller: BarcodeCameraController, context _: Context) {
        controller.setTorch(isTorchOn)
    }
}

/// Starts its session when it appears and stops it when it disappears, on a queue of its own because starting
/// a capture session blocks. iOS interrupts the session by itself if the app leaves the foreground.
final class BarcodeCameraController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "rizig.k-cal.camera")
    private let onCode: (String) -> Void
    private var isConfigured = false
    private var hasReported = false
    private var preview: AVCaptureVideoPreviewLayer?

    init(onCode: @escaping (String) -> Void) {
        self.onCode = onCode
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        let session = session
        queue.async { session.stopRunning() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.preview = preview
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        queue.async { [self] in
            configureIfNeeded()
            session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setTorch(false)
        queue.async { [session] in session.stopRunning() }
    }

    func setTorch(_ isOn: Bool) {
        queue.async {
            guard let device = AVCaptureDevice.default(for: .video), device.hasTorch, device.isTorchAvailable,
                  (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured, let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        isConfigured = true
        session.beginConfiguration()
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean8, .ean13, .upce]
        }
        session.commitConfiguration()
    }

    func metadataOutput(_: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from _: AVCaptureConnection) {
        guard !hasReported, let object = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        hasReported = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // UPC-E is an abbreviation that no food database stores.
        onCode(object.type == .upce ? Barcode.expandUPCE(value) ?? value : value)
    }
}
