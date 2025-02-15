//
//  Diary.swift
//  k-cal
//
//  Created by Michael Rizig on 2/11/25.
//

import SwiftUI

struct Diary: View {
    var body: some View {
        Text("Diary")
        ZStack(alignment: .top){
            SlideOverCard {
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
