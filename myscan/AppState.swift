//
//  AppState.swift
//  myscan
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import Foundation

enum AppTab: Hashable {
    case home
    case scan
    case settings
}

@Observable
final class AppState {
    var selectedTab: AppTab = .home
}
