//
//  SnapMealView.swift
//  k-cal
//
//  Photograph a package (its front, then its nutrition label) or a plate, review what was read or estimated, and
//  hand it on to AddFoodSheet.
//

import AVFoundation
import PhotosUI
import SwiftUI

struct SnapMealView: View {
    /// Called with the reviewed meal just before the view dismisses itself.
    let onUse: (MealEstimate, String) -> Void
    /// Called instead for anything identified from its packaging.
    let onProduct: (FoodProduct) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var estimator = MealEstimator()
    @State private var stage = Stage.choosing
    @State private var camera: CameraMode?
    /// The last camera used, so that retaking goes straight back to it.
    @State private var lastMode: CameraMode?
    /// Started on each package photo the moment it's taken.
    @State private var frontReading: Task<FrontReading, Never>?
    @State private var labelReading: Task<PrintedText, Never>?
    @State private var libraryItem: PhotosPickerItem?
    @State private var packageItems: [PhotosPickerItem] = []
    @State private var plateItems: [PhotosPickerItem] = []
    @State private var problem: Problem?

    private enum Stage {
        case choosing
        case analyzing([UIImage], String)
        case reviewing(UIImage, MealPhotoResult)
        case label(UIImage, NutritionLabel, name: String, choices: [FoodProduct])
        case package(UIImage, [FoodProduct], fromPackage: Bool)
    }

    private enum CameraMode: Identifiable {
        case package, plate

        var id: Self { self }

        var steps: [SnapCameraStep] {
            switch self {
            case .package: [.packageFront, .nutritionLabel]
            case .plate: [.plate]
            }
        }
    }

    private struct Problem {
        let title: String
        let message: String
    }

    private var hasCamera: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                switch stage {
                case .choosing:
                    choosing
                case let .analyzing(photos, message):
                    analyzing(photos, message: message)
                case let .reviewing(photo, result):
                    SnapMealReview(photo: photo, result: result, onRetake: retake) { estimate, name in
                        onUse(estimate, name)
                        dismiss()
                    }
                case let .label(photo, label, name, choices):
                    NutritionLabelReview(photo: photo, label: label, name: name, choices: choices, onRetake: retake, onUse: use)
                case let .package(photo, products, fromPackage):
                    if fromPackage {
                        PackageChoices(photo: photo, products: products, onPick: use, otherTitle: "None of these, retake the photos", onOther: retake)
                    } else {
                        PackageChoices(photo: photo, products: products, onPick: use) { estimate(photo) }
                    }
                }
            }
            .navigationTitle("Snap Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .fullScreenCover(item: $camera) { mode in
            SnapCameraScreen(steps: mode.steps) { index, photo in
                took(photo, step: index, in: mode)
            } onFinish: { photos in
                camera = nil
                finish(mode, photos: photos)
            }
        }
        .onChange(of: libraryItem) {
            guard let item = libraryItem else { return }
            libraryItem = nil
            Task { if let photo = await load([item]).first { analyze(photo) } }
        }
        .onChange(of: packageItems) {
            let items = packageItems
            guard !items.isEmpty else { return }
            packageItems = []
            lastMode = nil
            Task {
                let photos = await load(items)
                for (index, photo) in photos.enumerated() { took(photo, step: index, in: .package) }
                finish(.package, photos: photos)
            }
        }
        .onChange(of: plateItems) {
            let items = plateItems
            guard !items.isEmpty else { return }
            plateItems = []
            lastMode = nil
            Task { if let photo = await load(items).first { estimate(photo) } }
        }
        .alert(problem?.title ?? "", isPresented: Binding(
            get: { problem != nil },
            set: { if !$0 { problem = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem?.message ?? "")
        }
    }

    // MARK: Choosing

    private var choosing: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What are you logging?")
                        .font(.title2.bold())
                    Text("Your photos stay on your phone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
                option(.package) {
                    SnapOptionCard(
                        symbol: "shippingbox.fill", title: "Packaged food",
                        detail: "Two quick photos: the front, then the nutrition label. Logs the exact numbers on the package."
                    ) {
                        HStack(spacing: 6) {
                            SnapStepChip(number: 1, title: "Front")
                            Image(systemName: "arrow.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
                            SnapStepChip(number: 2, title: "Label")
                        }
                    }
                }
                .accessibilityIdentifier("snap-package")
                option(.plate) {
                    SnapOptionCard(
                        symbol: "fork.knife", title: "Plate",
                        detail: "One photo of your meal. Estimates calories and macros from what's on the plate."
                    ) {
                        SnapStepChip(number: 1, title: "Whole plate")
                    }
                }
                .accessibilityIdentifier("snap-plate")
                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Label("Choose a photo from your library", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .tint(Theme.brand)
                .padding(.top, 4)
            }
            .padding()
        }
    }

    /// Opens the camera, or the photo library on a device without one.
    @ViewBuilder
    private func option(_ mode: CameraMode, @ViewBuilder card: () -> some View) -> some View {
        if hasCamera {
            Button {
                lastMode = mode
                camera = mode
            } label: {
                card()
            }
            .buttonStyle(SnapCardStyle())
        } else {
            PhotosPicker(
                selection: mode == .package ? $packageItems : $plateItems,
                maxSelectionCount: mode == .package ? 2 : 1, selectionBehavior: .ordered, matching: .images
            ) {
                card()
            }
            .buttonStyle(SnapCardStyle())
        }
    }

    private func analyzing(_ photos: [UIImage], message: String) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                ForEach(photos.indices, id: \.self) { index in
                    Image(uiImage: photos[index])
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: photos.count > 1 ? 240 : 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            ProgressView()
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: Photos

    private func took(_ photo: UIImage, step: Int, in mode: CameraMode) {
        guard mode == .package else { return }
        if step == 0 {
            frontReading = Task { await PhotoIdentifier.readFront(photo) }
        } else {
            labelReading = Task { await PhotoIdentifier.readLabel(photo) }
        }
    }

    private func finish(_ mode: CameraMode, photos: [UIImage]) {
        guard let first = photos.first else { return }
        switch mode {
        case .plate:
            estimate(first)
        case .package:
            readPackage(front: first, label: photos.count > 1 ? photos[1] : nil)
        }
    }

    private func readPackage(front: UIImage, label: UIImage?) {
        stage = .analyzing([front] + (label.map { [$0] } ?? []), label == nil ? "Reading the package..." : "Reading the label...")
        let frontTask = frontReading, labelTask = label == nil ? nil : labelReading
        Task {
            let frontRead: FrontReading = if let frontTask { await frontTask.value } else { await PhotoIdentifier.readFront(front) }
            var labelRead: PrintedText?
            if let label { labelRead = if let labelTask { await labelTask.value } else { await PhotoIdentifier.readLabel(label) } }
            switch await PhotoIdentifier.package(front: frontRead, label: labelRead) {
            case let .product(product):
                use(product)
            case let .label(panel, name, choices):
                stage = .label(label ?? front, panel, name: name, choices: choices)
            case let .choices(products):
                stage = .package(front, products, fromPackage: true)
            case .unread:
                problem = Problem(
                    title: "Couldn't read that package",
                    message: label == nil
                        ? "Try again and take a photo of the nutrition label too."
                        : "Try again with the nutrition label filling the frame, in good light."
                )
                stage = .choosing
            }
        }
    }

    private func load(_ items: [PhotosPickerItem]) async -> [UIImage] {
        var photos: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let photo = UIImage(data: data) {
                photos.append(photo)
            }
        }
        if photos.count < items.count {
            problem = Problem(title: "Couldn't open that photo", message: MealEstimatorError.unreadablePhoto.localizedDescription)
        }
        return photos
    }

    /// Back to the camera you were using, or to the start for a photo from the library.
    private func retake() {
        stage = .choosing
        if let lastMode, hasCamera { camera = lastMode }
    }

    private func use(_ product: FoodProduct) {
        onProduct(product)
        dismiss()
    }

    /// Any one photo, from the library: works out whether it's a package, a label or a meal.
    private func analyze(_ photo: UIImage) {
        lastMode = nil
        stage = .analyzing([photo], "Taking a look...")
        Task {
            switch await PhotoIdentifier.identify(photo) {
            case let .product(product): use(product)
            case let .label(label): stage = .label(photo, label, name: "", choices: [])
            case let .package(products): stage = .package(photo, products, fromPackage: false)
            case .meal: estimate(photo)
            }
        }
    }

    private func estimate(_ photo: UIImage) {
        stage = .analyzing([photo], "Estimating your plate...")
        Task {
            do {
                let result = try await estimator.analyze(photo)
                stage = .reviewing(photo, result)
            } catch {
                problem = Problem(title: "Couldn't estimate that photo", message: error.localizedDescription)
                stage = .choosing
            }
        }
    }
}

/// One of the ways to snap food, as a large card.
private struct SnapOptionCard<Extra: View>: View {
    let symbol: String
    let title: String
    let detail: String
    @ViewBuilder let extra: Extra

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.brand)
                .frame(width: 54, height: 54)
                .background(Theme.brand.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                extra.padding(.top, 4)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

/// A numbered photo in a card's sequence.
private struct SnapStepChip: View {
    let number: Int
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.onBrand)
                .frame(width: 16, height: 16)
                .background(Theme.brand, in: Circle())
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brand)
        }
        .padding(.leading, 4)
        .padding(.trailing, 9)
        .padding(.vertical, 4)
        .background(Theme.brand.opacity(0.12), in: Capsule())
    }
}

private struct SnapCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct SnapMealReview: View {
    let photo: UIImage
    let result: MealPhotoResult
    let onRetake: () -> Void
    let onUse: (MealEstimate, String) -> Void

    @State private var name: String
    /// A share of the photo's estimate.
    @State private var portion = 1.0
    /// The database food behind the numbers, or nil for the photo model's own estimate.
    @State private var match: DishMatch?

    init(photo: UIImage, result: MealPhotoResult, onRetake: @escaping () -> Void, onUse: @escaping (MealEstimate, String) -> Void) {
        self.photo = photo
        self.result = result
        self.onRetake = onRetake
        self.onUse = onUse
        _name = State(initialValue: result.estimate.suggestedName)
        _match = State(initialValue: result.preferredMatch)
        if let preferred = result.preferredMatch { _name = State(initialValue: preferred.dish.name) }
    }

    private var estimate: MealEstimate {
        (match.flatMap { result.estimate.matched(to: $0) } ?? result.estimate).scaled(by: portion)
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
            Group {
            if !result.looksLikeFood {
                Section {
                    Label("This doesn't look like food, so the numbers below may be meaningless.", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(Theme.brand)
                }
            }
            Section {
                TextField("Name", text: $name)
                if !result.estimate.suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(result.estimate.suggestions) { dish in
                                Button(dish.name) { choose(dish) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(match?.dish == dish ? Theme.brand : .secondary)
                            }
                            if result.preferredMatch?.itemGrams != nil {
                                Button("It's a Full Meal", action: usePhotoEstimate)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(match == nil ? Theme.brand : .secondary)
                            }
                        }
                    }
                }
            } footer: {
                if let match, let itemGrams = match.itemGrams {
                    Text("Nutrition for one, about \(Int(itemGrams)) g, from \(match.food.name) (\(match.food.source.rawValue)). Change the portion if you have more.")
                } else if let match {
                    Text("Macros and portion from \(match.food.name) (\(match.food.source.rawValue)). Calories from your photo.")
                } else {
                    Text("Estimated from your photo. Tap a dish to use its real macros.")
                }
            }
            .listRowBackground(Theme.card)
            Section {
                VStack(spacing: 4) {
                    Text("\(Int(estimate.calories.rounded()))")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.brand)
                        .accessibilityIdentifier("snap-calories")
                    Text("estimated calories")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                HStack {
                    macro("Protein", estimate.protein, color: Theme.protein)
                    macro("Carbs", estimate.carbohydrates, color: Theme.carbohydrate)
                    macro("Fat", estimate.fat, color: Theme.fat)
                }
            }
            Section {
                Picker("Portion", selection: $portion) {
                    ForEach(MealEstimate.portions, id: \.self) { portion in
                        Text(portionLabel(portion)).tag(portion)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Portion")
            } footer: {
                Text(portionNote)
            }
            }
            .listRowBackground(Theme.card)
        }
        .themedList()
        .scrollDismissesKeyboard(.interactively)
        .task { await suggestName() }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Retake", action: onRetake)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button {
                    onUse(estimate, name)
                } label: {
                    Text("Use Estimate").foregroundStyle(Theme.onBrand).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .background(Theme.background.ignoresSafeArea())
        }
    }

    /// Fills in a better name once one arrives, unless a dish was recognised or you've picked or typed your own.
    private func suggestName() async {
        let first = name
        guard match == nil, (result.estimate.dishes.first?.confidence ?? 0) < MealEstimate.minimumNameConfidence,
              let suggestion = await PhotoFoodNamer.suggestion(for: photo), name == first, match == nil else { return }
        name = suggestion
    }

    private func choose(_ dish: DishGuess) {
        name = dish.name
        match = result.matches.first { $0.dish == dish }
        portion = 1
    }

    /// For when the fruit was only part of the meal.
    private func usePhotoEstimate() {
        name = MealEstimate.fallbackName
        match = nil
        portion = 1
    }

    private func portionLabel(_ value: Double) -> String {
        switch value {
        case 0.5: "½"
        case 0.75: "¾"
        case 1.25: "1¼"
        case 1.5: "1½"
        default: value.formatted()
        }
    }

    private var portionNote: String {
        if let grams = estimate.grams {
            return "About \(Int(grams.rounded())) g. Change this if you had more or less."
        }
        return "Meal photos are usually within a quarter of the real calories, but can be further out. Oil, butter and sauces are hard to see, so go up a size if your meal was rich."
    }

    private func macro(_ title: String, _ value: Double, color: Color) -> some View {
        VStack {
            Text(title).foregroundStyle(color)
            Text("\(Int(value.rounded())) g")
        }
        .frame(maxWidth: .infinity)
    }
}
