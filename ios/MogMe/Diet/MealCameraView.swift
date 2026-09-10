import AVFoundation
import SwiftUI
import UIKit

/// Live camera for meal (and chat) photos. Does not silently fall back to the library.
struct MealCameraView: View {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    @StateObject private var camera = LiveCameraController()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if camera.unavailable {
                status(
                    "Camera is not available on this device.",
                    "Use a physical iPhone to take a live meal photo."
                )
            } else if camera.denied {
                status(
                    "Camera access is off.",
                    "Settings → MogMe → Camera, then come back and try again."
                )
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                VStack {
                    HStack {
                        Button("Cancel", action: onCancel)
                            .foregroundStyle(.white)
                            .padding()
                        Spacer()
                    }
                    Spacer()
                    Text(camera.ready ? "Line up the meal, then tap" : "Starting live camera…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.bottom, 12)
                    Button {
                        camera.capture { image in
                            if let image { onCapture(image) }
                        }
                    } label: {
                        ZStack {
                            Circle().fill(.white.opacity(0.25)).frame(width: 84, height: 84)
                            Circle().fill(.white).frame(width: 64, height: 64)
                        }
                    }
                    .disabled(!camera.ready)
                    .padding(.bottom, 36)
                }
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private func status(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 12) {
            Text(title).font(.headline).foregroundStyle(.white)
            Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            Button("Close", action: onCancel).buttonStyle(GoldButtonStyle()).padding(.horizontal, 40)
        }
        .padding(24)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

@MainActor
final class LiveCameraController: NSObject, ObservableObject {
    @Published var ready = false
    @Published var denied = false
    @Published var unavailable = false

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.mogme.live-camera")
    private var continuation: ((UIImage?) -> Void)?

    func start() {
        guard !unavailable else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                Task { @MainActor in
                    if ok { self?.configureAndRun() } else { self?.denied = true }
                }
            }
        default:
            denied = true
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        ready = false
    }

    func capture(completion: @escaping (UIImage?) -> Void) {
        continuation = completion
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        sessionQueue.async { [output] in
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureAndRun() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            if self.session.inputs.isEmpty {
                guard
                    let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                        ?? AVCaptureDevice.default(for: .video),
                    let input = try? AVCaptureDeviceInput(device: device),
                    self.session.canAddInput(input)
                else {
                    Task { @MainActor in self.unavailable = true }
                    self.session.commitConfiguration()
                    return
                }
                self.session.addInput(input)
            }
            if self.session.outputs.isEmpty, self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()
            if !self.session.isRunning { self.session.startRunning() }
            Task { @MainActor in self.ready = true }
        }
    }
}

extension LiveCameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor [weak self] in
            self?.continuation?(image)
            self?.continuation = nil
        }
    }
}
