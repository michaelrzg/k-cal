//
//  WelcomeView.swift
//  k-cal
//
//  Created by Michael Rizig on 2/16/25.
//

import SwiftUI

struct WelcomeView: View {
    @Binding private var welcome_complete: Bool
    @State private var button_opacity = 0.0
    @State private var currentStep = 0
    @State private var next_disabled: Bool = false
        let totalSteps = 3
    var body: some View {
        ZStack{
            Color("Background").ignoresSafeArea()

            VStack{
                TabView(selection: $currentStep){
                    landing_page(welcome_complete: $welcome_complete).ignoresSafeArea().tag(0)
                    WeightScale(next_disabled: $next_disabled).tag(1)
                    
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .gesture(DragGesture().onChanged { _ in })
                Button(action: {
                    if currentStep < totalSteps - 1 {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                }) {
                    Text(currentStep < 0 ? "Get Started" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                }.opacity(button_opacity)
                    
            }.onAppear(){
                withAnimation(.easeInOut(duration: 1)){
                    button_opacity = 1.0
                }
            }
            
        }
    }
    
    init(welcome_complete: Binding<Bool>)
    {
        self._welcome_complete = welcome_complete
    }
}



struct landing_page: View {
    @Environment(\.dismiss) var dismiss
    @State private var isAnimating = false
    @State private var opacity = 0.0
    @State private var welcome_opacity = 0.0
    @State private var logo_opacity = 0.0
    @State private var tap_below_opacity = 0.0
    @State private var button_opacity = 0.0
    @State private var free_opacy = 0.0
    @State private var free_opacy2 = 0.0
    @State private var free_opacy3 = 0.0
    @State private var showingCreateUser = false
    @Binding private var welcome_complete: Bool
    @State private var welcome_complete_buffer: Bool = false
    @State private var loading_opacity: Double = 0.0


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
                            }.scaleEffect(3.0)
                        }.frame(maxWidth: .infinity, alignment: .center)
                        
                    }.padding(.bottom, 10).opacity(opacity)
                    Spacer()
                    Spacer()
                    Spacer()
                }
                VStack{
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()
                    ZStack{
                        
                        Text("Welcome to k-cal.").opacity(welcome_opacity).foregroundStyle(Color("k-cal"))
                        Text("\n 100% Free.").opacity(free_opacy).foregroundStyle(Color("k-cal")).offset(y:10)
                        Text("\n No Ads. ").opacity(free_opacy2).foregroundStyle(Color("k-cal")).offset(y:30)
                        Text("\n No Subscriptions. ").opacity(free_opacy3).foregroundStyle(Color("k-cal")).offset(y:50)
                    }
                    Spacer()
                    
                    
                    
                    
                    
                    
                }
                
                .onAppear {
                    loading_opacity = 0.0
                    withAnimation(.easeInOut(duration: 1.5)) {
                        opacity = 1.0
                    } completion: {
                        
                        
                        withAnimation(.easeInOut(duration: 1.0)) { // Opacity animation
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
                                    }
                                }
                            }
                            
                        }
                    }
                }
                .onChange(of: welcome_complete){
                    withAnimation(.easeInOut(duration: 1.0)){
                        dismiss()
                    }
                    
                }
            }
        }.fullScreenCover(isPresented: $showingCreateUser) { // Present the view
            
        }
        
    }
    init(welcome_complete: Binding<Bool>)
    {
        self._welcome_complete = welcome_complete
    }
}
#Preview {
    @State var sh = false
    WelcomeView(welcome_complete: $sh)
}
