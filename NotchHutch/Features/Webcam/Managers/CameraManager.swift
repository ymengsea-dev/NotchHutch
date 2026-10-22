import SwiftUI
import AVFoundation
import Combine

class CameraManager: ObservableObject {
    static let shared = CameraManager()

    @Published var session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    func checkPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession(completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupSession(completion: completion)
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        default:
            completion(false)
        }
    }

    private func setupSession(completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // If we already have inputs, just start running and exit
            if !self.session.inputs.isEmpty {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                let didStart = self.session.isRunning
                DispatchQueue.main.async {
                    completion(didStart)
                }
                return
            }

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            self.session.beginConfiguration()
            guard self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            self.session.addInput(input)
            self.session.commitConfiguration()
            self.session.startRunning()
            let didStart = self.session.isRunning
            DispatchQueue.main.async {
                completion(didStart)
            }
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}
