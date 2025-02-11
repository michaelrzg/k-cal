//
//  ProgressBar.swift
//  k-cal
//
//  Created by Michael Rizig on 2/10/25.
//
import SwiftUI
struct ProgressBar: View {
    @Binding var progress: Float
    @Binding var calories: Int
    @Binding var protein: Int
    @Binding var carbs: Int
    @Binding var fat: Int
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.3, to: 0.9)
                .stroke(style: StrokeStyle(lineWidth: 12.0, lineCap: .round, lineJoin: .round))
                .opacity(0.3)
                .foregroundColor(Color.gray)
                .rotationEffect(.degrees(54.5))
            
            Circle()
                .trim(from: 0.3, to: CGFloat(self.progress))
                .stroke(style: StrokeStyle(lineWidth: 12.0, lineCap: .round, lineJoin: .round))
                .fill(Color("PrimaryColor"))
                .rotationEffect(.degrees(54.5))
            
            VStack{
                Text("\(calories)").font(Font.system(size: 44)).bold().foregroundColor(Color("PrimaryColor"))
                Text("kcal").bold().foregroundColor(.black)
            }
        }
    }
}

struct ProgressBarTriangle: View {
    @Binding var progress: Float
    
    
    var body: some View {
        ZStack {
            Image("triangle").resizable().frame(width: 10, height: 10, alignment: .center)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
static var previews: some View {
    ContentView()
}
}
