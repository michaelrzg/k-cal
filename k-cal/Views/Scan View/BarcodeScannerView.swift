//
//  BarcodeScannerView.swift
//  k-cal
//
//  Created by Michael Rizig on 2/12/25.
//

import AVFoundation
import SwiftUI

struct BarcodeScannerView: UIViewControllerRepresentable {
    @Binding var barcode: String?
    @Binding var isScanning: Bool

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let viewController = BarcodeScannerViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context _: Context) {
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

        func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {
            guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let codeValue = metadataObject.stringValue else { return }

            // UPC-E is an abbreviation that no food database stores.
            let code = metadataObject.type == .upce ? Barcode.expandUPCE(codeValue) ?? codeValue : codeValue

            DispatchQueue.main.async {
                self.parent.barcode = code
                self.parent.isScanning = false
            }
        }
    }
}
