//
//  OnboardingView.swift
//  k-cal
//
//  Created by Michael Rizig on 2/19/25.
//

import SwiftUI
struct OnboardingView: View {
  let title: String
  let image: String
  let description: String

  var body: some View {
    VStack {
      Image(systemName: image)
        .font(.largeTitle)
        .padding()
      Text(title)
        .font(.headline)
      Text(description)
        .multilineTextAlignment(.center)
        .padding()
    }
  }
}

struct OnboardingView_Previews: PreviewProvider {
  static var previews: some View {
    OnboardingView(title: "Fun Fact", image: "paperplane.fill", description: "Space travel isn't for the faint-hearted.")
  }
}
