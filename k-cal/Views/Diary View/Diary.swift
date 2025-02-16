//
//  Diary.swift
//  k-cal
//
//  Created by Michael Rizig on 2/11/25.
//

import SwiftUI

struct Diary: View {
    @State private var position: CardPosition = .bottom
    var body: some View {
        Text("Diary")
        ZStack(alignment: .top){
            SlideOverCard(position: $position) {
                VStack {
                    
                    HStack{
                        RoundedRectangle(cornerRadius: 25)
                                        .fill(Color("Foreground"))
                                        .frame(width:50,height: 50)
                        Image(systemName: "magnifyingglass")
                            .onTapGesture {
                               
                            }
                        TextField("Search", text: .constant(""))
                        
                    }
                    Spacer()
                }
            }.edgesIgnoringSafeArea(.vertical)  .frame(maxWidth: .infinity)
        }
    }
                
    }



#Preview {
    Diary()
}
