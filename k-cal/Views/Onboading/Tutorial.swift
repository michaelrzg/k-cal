//
//  Tutorial.swift
//  k-cal
//
//  Created by Michael Rizig on 2/19/25.
//

import SwiftUI

struct Tutorial: View {
    @State private var opacity1: Double = 0
    @State private var opacity2: Double = 0
    @State private var opacity3: Double = 0
    var body: some View {
        VStack{
            OnboardingView(title: "Effortless Tracking", image: "chart.line.uptrend.xyaxis", description: "Monitor your daily intake and progress with simple, intuitive tracking.").opacity(opacity1)
            OnboardingView(title: "Quick Scan & Search", image: "barcode.viewfinder", description: "Instantly scan barcodes or search for foods to log your meals.").opacity(opacity2)
            OnboardingView(title: "Achieve Long-Term Goals", image: "flag.checkered", description: "Set and reach your health goals with personalized insights and progress tracking.").opacity(opacity3)
                .onAppear() {
                    withAnimation(.easeInOut(duration: 1)){
                        opacity1 = 1
                    } completion: {
                        withAnimation(.easeInOut(duration: 1)){
                            opacity2 = 1
                        } completion: {
                            withAnimation(.easeInOut(duration: 1)){
                                opacity3 = 1
                            }
                        }
                    }
                }
        }
    }
}

#Preview {
    Tutorial()
}
