import SwiftUI
import AVFoundation
import SwiftData

struct FoodBarcodeScanner: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var days: [Day]
    
    let dataFetcher: OpenFoodFactsFetcher
    @State private var isScanning = true
    @State private var barcode: String?
    @State private var food: Food?
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    @State private var addFoodSheetOpen: Bool = false
    @State private var isLoading: Bool = false
    
    @Binding var selectedTab: Int  // Bind to ContentView's tab selection

    init(selectedTab: Binding<Int>) {
        self.dataFetcher = OpenFoodFactsFetcher()
        self._selectedTab = selectedTab
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)

            VStack {
                if isScanning {
                    BarcodeScannerView(barcode: $barcode, isScanning: $isScanning, dataFetcher: dataFetcher, context: context, day: fetchTodayDay(context: context))
                        .overlay(
                            Rectangle()
                                .frame(width: 40, height: 3)
                                .foregroundColor(.white)
                                .padding(.top, 0)
                        )
                        .overlay(
                            Rectangle()
                                .frame(width: 3, height: 40)
                                .foregroundColor(.white)
                        )
                }
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(title: Text("Error"), message: Text(errorMessage ?? "An error occurred."), dismissButton: .default(Text("OK")))
            }

            // Show loading animation when fetching data
            if isLoading {
                ZStack {
                    Color("Background")
                        .edgesIgnoringSafeArea(.all)
                        .opacity(0.9) // Slight transparency for better visual effect
                    
                    VStack {
                        ProgressView("Fetching food data...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
            }
        }
        .onAppear {
            startScanningIfNeeded()
        }
        .onChange(of: barcode) { newValue in
            if let barcode = newValue {
                print("Barcode scanned: \(barcode)")
                isLoading = true // Show loading indicator

                dataFetcher.fetchFoodData(forBarcode: barcode, context: context, day: fetchTodayDay(context: context)) { fetchedFood, error in
                    DispatchQueue.main.async {
                        isLoading = false // Hide loading indicator
                        if let fetchedFood = fetchedFood {
                            food = fetchedFood
                            addFoodSheetOpen = true // Open sheet *after* fetching data
                            isScanning = false // Stop scanning *after* opening sheet
                        } else if let error = error {
                            errorMessage = error
                            showErrorAlert = true
                            isScanning = true // Restart scanning on error
                            self.barcode = nil // Clear barcode on error
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $addFoodSheetOpen) {
                    if let food = food {
                        AddFoodSheet(food: food, selectedTab: $selectedTab)
                            .onDisappear {
                                isScanning = true
                                barcode = nil
                                dismiss()
                            }
                    }
                }    }

    func startScanningIfNeeded() {
        if isScanning {
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


