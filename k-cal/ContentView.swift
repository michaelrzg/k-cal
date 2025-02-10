//
//  ScanPage.swift
//  k-cal
//
//  Created by Michael Rizig on 2/10/25.
//

import SwiftUI

struct ContentView: View {
    @State var todays_calories: Int  = 0
    @State var todays_progress: Float = 0.0
    var body: some View {
    @State  var degress: Double = -110
        NavigationStack{
            // top bar with scan icon and  'kcal' title
            HStack{
            Image(systemName: "barcode.viewfinder").foregroundStyle(Color("PrimaryColor"))
                Text("k-cal").font(.headline).foregroundStyle(Color("PrimaryColor"))
            }
            // text header todo: add rotating prompts
            Form{
                
                VStack {
                    ZStack{
                        ProgressBar(progress: self.$todays_progress, calories: self.$todays_calories)
                            .frame(width: 250.0, height: 250.0)
                            .padding(40.0)
                        
                        ProgressBarTriangle(progress: self.$todays_progress).frame(width: 280.0, height: 290.0).rotationEffect(.degrees(degress), anchor: .bottom)
                            .offset(x: 0, y: -150)
                        //Spacer()
                    }
                }
                
            }
           
      
        }
        
    }
    
}
func scale_progress(progress:Int)-> Float {
    var output: Float=0
    output = Float(progress) * 0.6
    output+=0.3
    return output
}
#Preview {
    ContentView()
}
