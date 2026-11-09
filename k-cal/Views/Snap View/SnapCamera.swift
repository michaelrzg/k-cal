//
//  SnapCamera.swift
//  k-cal
//
//  The in-app camera for photographing food, one or more shots in a row. Each shot is taken the moment the shutter
//  is pressed, with no review in between, and the next prompt appears straight away while the photo is still being
//  processed. The camera is on only while this screen is open.
//

import AVFoundation
import SwiftUI

/// One photo to ask for.
struct SnapCameraStep: Equatable {
    let title: String
    let detail: String
    /// The guide's width over its height.
    let aspect: CGFloat
    /// The thumbnail's caption once this shot is taken.
    let shortName: String
    /// Offered for a shot that can be left out.
    var skipTitle: String?

    static let packageFront = SnapCameraStep(
        title: "Front of the package", detail: "Get the brand and product name in the frame.",
        aspect: 3 / 4, shortName: "Front"
    )
    static let nutritionLabel = SnapCameraStep(
        title: "Now the nutrition label", detail: "Fill the frame with the Nutrition Facts panel.",
        aspect: 2 / 3, shortName: "Label", skipTitle: "No label"
    )
    static let plate = SnapCameraStep(
        title: "Your plate", detail: "Get the whole plate in, from a little above.",
        aspect: 1, shortName: "Plate"
    )
}

struct SnapCameraScreen: View {
    let steps: [SnapCameraStep]
    /// Each photo as soon as it's ready, with the index of its step, so work on it can start while the next is taken.
    let onPhoto: (Int, UIImage) -> Void
    /// Every photo taken, in step order, once the last one is ready. Shorter than `steps` if one was skipped.
    let onFinish: ([UIImage]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var camera = SnapCameraHandle()
    @State private var access = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var step = 0
    @State private var photos: [Int: UIImage] = [:]
    /// The number of steps done, counting shots still being processed.
    @State private var taken = 0
    @State private var isFinishing = false
    @State private var isTorchOn = false
    @State private var flash = false
    /// The latest shot asked for at each step, so a photo that arrives after a retake is dropped.
    @State private var shots: [Int: UUID] = [:]

    private var hasCamera: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    private var current: SnapCameraStep {
        steps[min(step, steps.count - 1)]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !hasCamera {
                message("No camera on this device", detail: "Choose a photo from your library instead.")
            } else if access == .denied || access == .restricted {
                message("Camera access is off", detail: "Turn it on in Settings to photograph your food.", settings: true)
            } else {
                SnapCameraView(handle: camera, isTorchOn: isTorchOn).ignoresSafeArea()
                SnapGuide(aspect: current.aspect)
                Color.white.opacity(flash ? 0.75 : 0).ignoresSafeArea().allowsHitTesting(false)
            }
            VStack(spacing: 0) {
                topBar
                if hasCamera, access != .denied, access != .restricted {
                    instructions.padding(.top, 2)
                    Spacer()
                    bottomBar
                } else {
                    Spacer()
                }
            }
            .padding()
        }
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .task {
            if access == .notDetermined {
                await AVCaptureDevice.requestAccess(for: .video)
                access = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }

    private var topBar: some View {
        HStack {
            circleButton("xmark", label: "Close") { dismiss() }
            Spacer()
            if steps.count > 1 {
                Text("\(min(step, steps.count - 1) + 1) of \(steps.count)")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .contentTransition(.numericText())
            }
            Spacer()
            if hasCamera {
                circleButton(isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill", label: "Flashlight") {
                    isTorchOn.toggle()
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.white)
    }

    private var instructions: some View {
        VStack(spacing: 6) {
            Text(current.title)
                .font(.title3.weight(.bold))
            Text(current.detail)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.4), radius: 6)
        .id(step)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    private var bottomBar: some View {
        HStack {
            // The shots already taken, newest last. Tapping one takes it again.
            HStack(spacing: 8) {
                ForEach(0 ..< min(taken, steps.count), id: \.self) { index in
                    thumbnail(index)
                }
            }
            .frame(width: 96, alignment: .leading)
            Spacer()
            Button(action: shoot) {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 78, height: 78)
                    Circle().fill(.white).frame(width: 64, height: 64)
                }
            }
            .buttonStyle(ShutterStyle())
            .disabled(isFinishing)
            .accessibilityLabel("Take photo of the \(current.shortName.lowercased())")
            Spacer()
            Group {
                if let skip = current.skipTitle, !isFinishing {
                    Button(skip, action: skipStep)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .frame(width: 96, alignment: .trailing)
        }
        .foregroundStyle(.white)
        .padding(.bottom, 8)
    }

    private func thumbnail(_ index: Int) -> some View {
        Button {
            retake(from: index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.15))
                if let photo = photos[index] {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 44, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white, lineWidth: 1.5))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.white, Theme.brand)
                    .offset(x: 6, y: -6)
            }
        }
        .disabled(isFinishing)
        .transition(.scale(scale: 0.3, anchor: .center).combined(with: .opacity))
        .accessibilityLabel("Retake the \(steps[index].shortName.lowercased())")
    }

    private func shoot() {
        guard taken < steps.count, !isFinishing else { return }
        let index = taken, shot = UUID()
        shots[index] = shot
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.06)) { flash = true }
        withAnimation(.easeIn(duration: 0.25).delay(0.06)) { flash = false }
        camera.capture { photo in
            guard let photo, shots[index] == shot else { return }
            photos[index] = photo
            onPhoto(index, photo)
            finishIfReady()
        }
        // Moves on at once: the photo is already captured, and processing it doesn't need you to wait.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            taken += 1
            if taken < steps.count { step = taken } else { isFinishing = true }
        }
        finishIfReady()
    }

    private func skipStep() {
        withAnimation { isFinishing = true }
        finishIfReady()
    }

    private func retake(from index: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            for later in index ..< steps.count {
                photos[later] = nil
                shots[later] = nil
            }
            taken = index
            step = index
            isFinishing = false
        }
    }

    private func finishIfReady() {
        guard isFinishing, (0 ..< taken).allSatisfy({ photos[$0] != nil }) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onFinish((0 ..< taken).compactMap { photos[$0] })
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }

    private func message(_ title: String, detail: String, settings: Bool = false) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill").font(.largeTitle)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).multilineTextAlignment(.center)
            if settings, let url = URL(string: UIApplication.openSettingsURLString) {
                Button { openURL(url) } label: { Text("Open Settings").foregroundStyle(Theme.onBrand) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .foregroundStyle(.white)
        .padding()
    }
}

private struct ShutterStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Corner marks showing where to put the food, dimming what's outside them.
private struct SnapGuide: View {
    let aspect: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width - 56, (geometry.size.height * 0.52) * aspect)
            let height = width / aspect
            let frame = CGRect(
                x: (geometry.size.width - width) / 2, y: geometry.size.height * 0.5 - height / 2,
                width: width, height: height
            )
            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geometry.size))
                    path.addRoundedRect(in: frame, cornerSize: CGSize(width: 24, height: 24))
                }
                .fill(Color.black.opacity(0.35), style: FillStyle(eoFill: true))
                Corners()
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: aspect)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private struct Corners: Shape {
        func path(in rect: CGRect) -> Path {
            let length = min(rect.width, rect.height) * 0.16, radius: CGFloat = 24
            var path = Path()
            for (corner, x, y) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0), (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                   (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0), (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
                path.move(to: CGPoint(x: corner.x, y: corner.y + y * (radius + length)))
                path.addLine(to: CGPoint(x: corner.x, y: corner.y + y * radius))
                path.addQuadCurve(to: CGPoint(x: corner.x + x * radius, y: corner.y), control: corner)
                path.addLine(to: CGPoint(x: corner.x + x * (radius + length), y: corner.y))
            }
            return path
        }
    }
}

/// Lets the SwiftUI screen ask the camera for a photo.
@MainActor
final class SnapCameraHandle {
    fileprivate weak var controller: SnapCameraController?

    func capture(_ completion: @escaping @MainActor (UIImage?) -> Void) {
        guard let controller else { return completion(nil) }
        controller.capture(completion)
    }
}

private struct SnapCameraView: UIViewControllerRepresentable {
    let handle: SnapCameraHandle
    let isTorchOn: Bool

    func makeUIViewController(context _: Context) -> SnapCameraController {
        let controller = SnapCameraController()
        handle.controller = controller
        return controller
    }

    func updateUIViewController(_ controller: SnapCameraController, context _: Context) {
        handle.controller = controller
        controller.setTorch(isTorchOn)
    }
}

/// Runs the capture session on a queue of its own, because starting one blocks, and stops it when the screen goes.
final class SnapCameraController: UIViewController, AVCapturePhotoCaptureDelegate {
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "rizig.k-cal.snap-camera")
    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var preview: AVCaptureVideoPreviewLayer?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    /// Waiting for their photos, by capture ID. Only touched on the main thread.
    private var pending: [Int64: @MainActor (UIImage?) -> Void] = [:]

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
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focus(_:))))
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
            guard let device else { return }
            DispatchQueue.main.async { [self] in
                if rotation == nil { rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview) }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setTorch(false)
        queue.async { [session] in session.stopRunning() }
    }

    func setTorch(_ isOn: Bool) {
        queue.async { [self] in
            guard let device, device.hasTorch, device.isTorchAvailable, (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        }
    }

    func capture(_ completion: @escaping @MainActor (UIImage?) -> Void) {
        let angle = rotation?.videoRotationAngleForHorizonLevelCapture ?? 90
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .balanced
        pending[settings.uniqueID] = completion
        queue.async { [self] in
            guard session.isRunning, let connection = output.connection(with: .video) else {
                return DispatchQueue.main.async { self.pending.removeValue(forKey: settings.uniqueID)?(nil) }
            }
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    nonisolated func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error _: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        let id = photo.resolvedSettings.uniqueID
        DispatchQueue.main.async { self.pending.removeValue(forKey: id)?(image) }
    }

    /// Focuses where you tap, which matters for small print up close.
    @objc private func focus(_ tap: UITapGestureRecognizer) {
        guard let preview else { return }
        let point = preview.captureDevicePointConverted(fromLayerPoint: tap.location(in: view))
        queue.async { [self] in
            guard let device, (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        }
    }

    @objc private func subjectAreaChanged() {
        queue.async { [self] in
            guard let device, (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.isSubjectAreaChangeMonitoringEnabled = false
            device.unlockForConfiguration()
        }
    }

    /// A camera that switches to its macro lens by itself when you get close to a label, where the phone has one.
    private static func bestCamera() -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
            mediaType: .video, position: .back
        ).devices.first
    }

    private func configureIfNeeded() {
        guard !isConfigured, let device = Self.bestCamera(),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        isConfigured = true
        self.device = device
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.addInput(input)
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.maxPhotoQualityPrioritization = .balanced
            if output.isResponsiveCaptureSupported {
                output.isResponsiveCaptureEnabled = true
                output.isFastCapturePrioritizationEnabled = output.isFastCapturePrioritizationSupported
            }
        }
        session.commitConfiguration()
        if (try? device.lockForConfiguration()) != nil {
            // A virtual camera starts on its ultra wide; this is the normal 1× view, which still swaps lenses up close.
            if let wide = device.virtualDeviceSwitchOverVideoZoomFactors.first {
                device.videoZoomFactor = CGFloat(truncating: wide)
            }
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            device.unlockForConfiguration()
        }
        DispatchQueue.main.async { [self] in
            NotificationCenter.default.addObserver(
                self, selector: #selector(subjectAreaChanged), name: AVCaptureDevice.subjectAreaDidChangeNotification, object: device
            )
        }
    }
}
