//
//  SnapMealView.swift
//  k-cal
//
//  Photograph a meal, review the estimate, and hand it on to AddFoodSheet.
//

import PhotosUI
import SwiftUI

struct SnapMealView: View {
    /// Called with the reviewed meal just before the view dismisses itself.
    let onUse: (MealEstimate, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var estimator = MealEstimator()
    @State private var stage = Stage.choosing
    @State private var showingCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var errorMessage: String?

    private enum Stage {
        case choosing
        case analyzing(UIImage)
        case reviewing(UIImage, MealPhotoResult)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()
                switch stage {
                case .choosing:
                    choosing
                case let .analyzing(photo):
                    analyzing(photo)
                case let .reviewing(photo, result):
                    SnapMealReview(photo: photo, result: result, onRetake: reset) { estimate, name in
                        onUse(estimate, name)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Snap a Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { photo in analyze(photo) }.ignoresSafeArea()
        }
        .onChange(of: libraryItem) {
            guard let item = libraryItem else { return }
            libraryItem = nil
            Task { await loadFromLibrary(item) }
        }
        .alert("Couldn't estimate that photo", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var choosing: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 72))
                .foregroundStyle(Color("k-cal"))
            Text("Estimate calories from a photo")
                .font(.title3).bold()
            Text("Shoot straight down from above with the whole plate in frame. The photo stays on your phone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            if CameraPicker.isAvailable {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            PhotosPicker(selection: $libraryItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
    }

    private func analyzing(_ photo: UIImage) -> some View {
        VStack(spacing: 20) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            ProgressView()
            Text("Estimating your meal...")
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func reset() {
        stage = .choosing
    }

    private func loadFromLibrary(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let photo = UIImage(data: data) else {
                throw MealEstimatorError.unreadablePhoto
            }
            analyze(photo)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func analyze(_ photo: UIImage) {
        stage = .analyzing(photo)
        Task {
            do {
                let result = try await estimator.analyze(photo)
                stage = .reviewing(photo, result)
            } catch {
                errorMessage = error.localizedDescription
                stage = .choosing
            }
        }
    }
}

private struct SnapMealReview: View {
    let photo: UIImage
    let result: MealPhotoResult
    let onRetake: () -> Void
    let onUse: (MealEstimate, String) -> Void

    @State private var name: String
    @State private var grams: Double

    init(photo: UIImage, result: MealPhotoResult, onRetake: @escaping () -> Void, onUse: @escaping (MealEstimate, String) -> Void) {
        self.photo = photo
        self.result = result
        self.onRetake = onRetake
        self.onUse = onUse
        _name = State(initialValue: result.estimate.suggestedName)
        _grams = State(initialValue: result.estimate.grams.rounded())
    }

    private var estimate: MealEstimate {
        result.estimate.scaled(toGrams: grams)
    }

    var body: some View {
        Form {
            Section {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .listRowBackground(Color.clear)
            }
            if !result.looksLikeFood {
                Section {
                    Label("This doesn't look like food, so the numbers below may be meaningless.", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
            Section("Meal") {
                TextField("Name", text: $name)
                if !result.estimate.suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(result.estimate.suggestions) { dish in
                                Button(dish.name) { name = dish.name }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(name == dish.name ? Color("k-cal") : .secondary)
                            }
                        }
                    }
                }
            }
            Section {
                VStack(spacing: 4) {
                    Text("\(Int(estimate.calories.rounded()))")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Color("k-cal"))
                        .accessibilityIdentifier("snap-calories")
                    Text("estimated calories")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                HStack {
                    macro("Protein", estimate.protein, color: "Protein")
                    macro("Carbs", estimate.carbohydrates, color: "Carbohydrate")
                    macro("Fat", estimate.fat, color: "Fat")
                }
            }
            Section {
                Stepper(value: $grams, in: MealEstimate.gramsRange, step: 10) {
                    HStack {
                        Text("Portion")
                        Spacer()
                        TextField("g", value: $grams, format: .number.precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("g")
                    }
                }
            } footer: {
                Text("Photo estimates can easily be off by 20% or more, and hidden oil, butter and sauces are hard to see. If you know the weight of your food, enter it here.")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Retake", action: onRetake)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button {
                    onUse(estimate, name)
                } label: {
                    Text("Use Estimate").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!MealEstimate.gramsRange.contains(grams))
            }
            .padding()
            .background(Color("Background"))
        }
    }

    private func macro(_ title: String, _ value: Double, color: String) -> some View {
        VStack {
            Text(title).foregroundStyle(Color(color))
            Text("\(Int(value.rounded())) g")
        }
        .frame(maxWidth: .infinity)
    }
}
