//
//  BarcodeScannerViewController.swift
//  k-cal
//
//  Created by Michael Rizig on 2/12/25.
//
import SwiftUI
import AVFoundation
import SwiftData

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

    required init?(coder aDecoder: NSCoder) {
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

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            return
        }

        if (captureSession.canAddOutput(captureOutput)) {
            captureSession.addOutput(captureOutput)

            captureOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
            captureOutput.metadataObjectTypes = [.ean8, .ean13, .qr, .pdf417]
        } else {
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)

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
        previewLayer.frame = view.layer.bounds
    }
}
