//
//  WelcomeView.swift
//  k-cal
//
//  Created by Michael Rizig on 2/16/25.
//

import SwiftUI

struct WelcomeView: View {
    @State private var isAnimating = false
    @State private var opacity = 0.0
    @State private var welcome_opacity = 0.0
    @State private var logo_opacity = 0.0
    @State private var tap_below_opacity = 0.0
    @State private var free_opacy = 0.0
    @State private var free_opacy2 = 0.0
    @State private var free_opacy3 = 0.0
    @State private var showingCreateUser = false
    var body: some View {


        ZStack{
            Color("Background").ignoresSafeArea()

                ZStack {
                         VStack {
                             Spacer()

                             HStack {
                                 HStack {
                                     HStack {
                                         Image(systemName: "barcode.viewfinder").foregroundStyle(Color("k-cal")).padding(.top, 10)
                                         Text("k-cal").font(.headline).foregroundStyle(Color("k-cal")).padding(.top, 10)
                                     }.scaleEffect(2.5)
                                 }.frame(maxWidth: .infinity, alignment: .center)
                                 
                             }.padding(.bottom, 10).opacity(opacity)
                            Spacer()
                             Spacer()
                         }
                    VStack{
                        Spacer()
                        Spacer()
                        Spacer()
                        Spacer()
                        ZStack{
                            
                            Text("Welcome to k-cal.").opacity(welcome_opacity).foregroundStyle(Color("k-cal"))
                            Text("\n 100% Free").opacity(free_opacy).foregroundStyle(Color("k-cal")).offset(y:10)
                            Text("\n No Ads ").opacity(free_opacy2).foregroundStyle(Color("k-cal")).offset(y:30)
                            Text("\n No Subscriptions ").opacity(free_opacy3).foregroundStyle(Color("k-cal")).offset(y:50)
                        }
                        Spacer()
                        Text("Tap below to get started").opacity(tap_below_opacity).foregroundStyle(Color("k-cal"))
                        Button(action: {
                            showingCreateUser = true
                        }) {
                                    Text("Set Up Your Account")
                                        .font(.system(size: 18, weight: .semibold)) // Adjust font size as needed
                                        .foregroundColor(.white)
                                         // Adjust padding for width
                                        .frame(maxWidth: .infinity, maxHeight: 45) // Make button fill width
                                        .background(Color.blue)
                                        .cornerRadius(12) // Match Apple's corner radius
                                }.padding(.vertical, 2) // Adjust padding for height
                            .padding(.horizontal, 24)
                            .opacity(tap_below_opacity)
                            .fullScreenCover(isPresented: $showingCreateUser) { // Present the view
                                        CreateUserView()
                                    }
                        
                         }
                        
                    }
                    
                     .onAppear {
                         withAnimation(.easeInOut(duration: 1.5)) {
                             opacity = 1.0
                         } completion: {
                             
                             
                             withAnimation(.easeInOut(duration: 1.5)) { // Opacity animation
                                 welcome_opacity = 1.0
                             } completion: {
                                 withAnimation(.easeInOut(duration: 1.2)) { // Opacity animation
                                     free_opacy = 1.0
                                 } completion: {
                                     withAnimation(.easeInOut(duration: 1.2)) { // Opacity animation
                                         free_opacy2 = 1.0
                                     } completion: {
                                         withAnimation(.easeInOut(duration: 1.2)) { // Opacity animation
                                             free_opacy3 = 1.0
                                         } completion: {
                                             withAnimation(.easeInOut(duration: 2.5)) { // Opacity animation
                                                 tap_below_opacity = 1.0
                                             }
                                         }
                                     }
                                 }
                                 
                             }
                         }
                        
                         withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { // Scale animation
                             isAnimating = true
                         }
                         print("ani")
                     }
                 
            }
        
    }
}

#Preview {
    WelcomeView()
}
