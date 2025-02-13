//
//  BarcodeScannerView.swift
//  k-cal
//
//  Created by Michael Rizig on 2/12/25.
//

import SwiftUI
import AVFoundation
import SwiftData


struct BarcodeScannerView: UIViewControllerRepresentable {
    @Binding var barcode: String?
    @Binding var isScanning: Bool
    let dataFetcher: OpenFoodFactsFetcher
    let context: ModelContext  // Add ModelContext property
    let day: Day

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let viewController = BarcodeScannerViewController(dataFetcher: dataFetcher, context: self.context, day: day) // Use self.context
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        uiViewController.isScanning = isScanning
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let parent: BarcodeScannerView

        init(_ parent: BarcodeScannerView) {
            self.parent = parent
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let codeValue = metadataObject.stringValue else { return }

            DispatchQueue.main.async {
                self.parent.barcode = codeValue
                self.parent.isScanning = false
            }
        }
    }
}

