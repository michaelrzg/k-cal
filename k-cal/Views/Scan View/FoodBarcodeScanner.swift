import SwiftUI
import AVFoundation
import SwiftData

struct FoodBarcodeScanner: View {
    @Environment(\.modelContext) private var context
    @Query private var days: [Day]
    let dataFetcher: OpenFoodFactsFetcher
    @State private var isScanning = true
    @State private var barcode: String?
    @State private var food: Food?
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    @State private var addFoodSheetOpen: Bool = false
    init() {
        self.dataFetcher = OpenFoodFactsFetcher()
    }

    var body: some View {
        ZStack {
            
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)

            VStack {
                // Barcode scanning view is shown only when isScanning is true
                if isScanning {
                    BarcodeScannerView(barcode: $barcode, isScanning: $isScanning, dataFetcher: dataFetcher, context: context, day: fetchTodayDay(context: context))
                        .overlay(
                            Rectangle()
                               .frame(width: 40, height: 3) // Width and thickness of the horizontal line
                               .foregroundColor(.white) // Color of the cross
                               .padding(.top, 0) // Adjust vertical position
                        ).overlay( Rectangle()
                            .frame(width: 3, height: 40) // Height and thickness of the vertical line
                            .foregroundColor(.white) // Color of the cross
)
                       
                }

                // A button to manually stop scanning (not needed for auto scan but added for debugging)
//                Button(isScanning ? "Stop Scanning" : "Start Scanning") {
//                    isScanning.toggle()
//                }
//                .padding()

                // Display scanned barcode if available
                if let barcode = barcode {
                    Text("Barcode: \(barcode)")
                }

                // Display food information if available
                if let food = food {
                    //UpdateFoodSheet(food: food)
                }
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(title: Text("Error"), message: Text(errorMessage ?? "An error occurred."), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear {
            // Start scanning automatically when the view appears
            startScanningIfNeeded()
        }
        .onChange(of: barcode) { newValue in
            if let barcode = newValue {
                print("Barcode scanned: \(barcode)")
                dataFetcher.fetchFoodData(forBarcode: barcode, context: context, day: fetchTodayDay(context: context)) { fetchedFood,error in
                    if let fetchedFood = fetchedFood {
                        food = fetchedFood
                    }
                }
                addFoodSheetOpen = true
                // Stop scanning once a barcode is detected
                isScanning = false
            }
        }.sheet(isPresented: $addFoodSheetOpen){
            if let food = food{
                UpdateFoodSheet(food: food)
            }
        }
    }

    func startScanningIfNeeded() {
        if isScanning {
            // Trigger the start of barcode scanning immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isScanning = true
            }
        }
    }

    func fetchTodayDay(context: ModelContext) -> Day {
        let todayStart = Calendar.current.startOfDay(for: Date())

        let fetchDescriptor = FetchDescriptor<Day>(
            predicate: #Predicate { $0.date == todayStart }
        )

        do {
            if let existingDay = try context.fetch(fetchDescriptor).first {
                return existingDay
            } else {
                let newDay = Day(date: todayStart)
                context.insert(newDay)
                try context.save()
                return newDay
            }
        } catch {
            fatalError("Error fetching or creating today's Day: \(error)")
        }
    }
}

#Preview {
    FoodBarcodeScanner()
}
