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
    @Binding var protein_progress: Float
    @Binding var carb_progress: Float
    @Binding var fat_progress: Float
    @Binding var total_fat: Int
    @Binding var total_carbs: Int
    @Binding var total_protein: Int
    
    let small_bar_count_text_size:CGFloat = 15.0
    let calorie_count_text_size:CGFloat = 44.0
    
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.3, to: 0.9)
                .stroke(style: StrokeStyle(lineWidth: 13.0, lineCap: .round, lineJoin: .round))
                .opacity(0.3)
                .foregroundColor(Color.black)
                .rotationEffect(.degrees(54.5))
                .position(x:126, y:55)
            
            Circle()
                .trim(from: 0.3, to: CGFloat(self.progress))
                .stroke(style: StrokeStyle(lineWidth: 13.0, lineCap: .round, lineJoin: .round))
                .fill(Color("PrimaryColor"))
                .rotationEffect(.degrees(54.5))
                .position(x:126, y:55)
            
            VStack{
                Text("\(calories)").font(Font.system(size: calorie_count_text_size)).bold().foregroundColor(Color("PrimaryColor"))
                Text("kcal").bold().foregroundColor(.black)
                
            }.position(x:126, y:55)
        }
        Spacer()
        // Horizontal line holding p, c , f bars
        HStack{
            // protein bar to the far left
            ZStack {
                Circle()
                    .trim(from: 0.3, to: 0.9)
                    .stroke(style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
                    .opacity(0.3)
                    .foregroundColor(Color.black)
                    .rotationEffect(.degrees(54.5))
                    .position(x:10,y:110)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0.3, to: CGFloat(self.protein_progress))
                    .stroke(style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
                    .fill(Color("Protein"))
                    .rotationEffect(.degrees(54.5))
                    .position(x:10,y:110)
                    .frame(width: 50, height: 50)
                VStack{
                    Text("\(total_protein)").font(Font.system(size: small_bar_count_text_size)).bold().foregroundColor(Color("Protein"))
                    Text("p").foregroundColor(.black)
                    
                }.position(x:23,y:170)
            }
            ZStack {
                Circle()
                    .trim(from: 0.3, to: 0.9)
                    .stroke(style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
                    .opacity(0.3)
                    .foregroundColor(Color.black)
                    .rotationEffect(.degrees(54.5))
                    .position(x:15,y:110)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0.3, to: CGFloat(self.carb_progress))
                    .stroke(style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
                    .fill(Color("Carbohydrate"))
                    .rotationEffect(.degrees(54.5))
                    .position(x:15,y:110)
                    .frame(width: 50, height: 50)
                VStack{
                    Text("\(total_carbs)").font(Font.system(size: small_bar_count_text_size)).bold().foregroundColor(Color("Carbohydrate"))
                    Text("c").foregroundColor(.black)
                    
                }.position(x:28,y:170)
            }
            ZStack {
                Circle()
                    .trim(from: 0.3, to: 0.9)
                    .stroke(style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
                    .opacity(0.3)
                    .foregroundColor(Color.black)
                    .rotationEffect(.degrees(54.5))
                    .position(x:13,y:110)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0.3, to: CGFloat(self.fat_progress))
                    .stroke(style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
                    .fill(Color("Fat"))
                    .rotationEffect(.degrees(54.5))
                    .position(x:13,y:110)
                    .frame(width: 50, height: 50)
                VStack{
                    Text("\(total_fat)").font(Font.system(size: small_bar_count_text_size)).bold().foregroundColor(Color("Fat"))
                    Text("f").foregroundColor(.black)
                    
                }.position(x:25,y:170)
            }
           
        }.position(x:138,y:70)
        Spacer()
                
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
