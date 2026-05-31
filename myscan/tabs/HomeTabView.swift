//
//  HomeTabView.swift
//  myscan
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import SwiftUI

struct HomeTabView: View {
    var body: some View {
        NavigationStack {
            Home()
                .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeTabView()
}
