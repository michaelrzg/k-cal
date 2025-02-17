//  BarcodeScannerViewController.swift
//  k-cal
//
//  Created by Michael Rizig on 2/12/25.
//

import AVFoundation
import SwiftData
import SwiftUI

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var captureOutput: AVCaptureMetadataOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var isScanning = false {
        didSet {
            if isScanning {
                startScanning()
            } else {
                stopScanning()
            }
        }
    }

    let dataFetcher: OpenFoodFactsFetcher
    let context: ModelContext
    let day: Day

    weak var delegate: BarcodeScannerView.Coordinator?

    init(dataFetcher: OpenFoodFactsFetcher, context: ModelContext, day: Day) {
        self.dataFetcher = dataFetcher
        self.context = context
        self.day = day
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        captureSession = AVCaptureSession()
        captureOutput = AVCaptureMetadataOutput()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }

        if captureSession.canAddOutput(captureOutput) {
            captureSession.addOutput(captureOutput)

            captureOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
            captureOutput.metadataObjectTypes = [.ean8, .ean13, .qr, .pdf417]
        } else {
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill

        // *** KEY CHANGES START HERE ***
        view.backgroundColor = .black // Fill behind safe area

        // Set video orientation (CRUCIAL!)
        if let connection = previewLayer.connection {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait // Or your desired orientation
            }
        }

        view.layer.addSublayer(previewLayer) // Add *before* setting frame

        previewLayer.frame = view.layer.bounds // Initial frame

        view.setNeedsLayout()
        view.layoutIfNeeded()
        previewLayer.frame = view.layer.bounds // Frame after layout

        // *** KEY CHANGES END HERE ***

        startScanning()
    }

    func startScanning() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    func stopScanning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // *** KEY CHANGE: Ensure frame is updated ***
        previewLayer.frame = view.layer.bounds // Update in case of layout changes
    }
}
