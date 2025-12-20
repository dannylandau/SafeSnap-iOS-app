//
//  PresentationCoordinator.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 05/09/2025.
//

import Foundation

final class PresentationCoordinator: ObservableObject {
    @Published var route: Route? = nil

    enum Route: Identifiable {
        case progress       // analysis running
        case error(String)  // error message
        var id: String {
            switch self {
            case .progress: return "progress"
            case .error(let msg): return "error:\(msg)"
            }
        }
    }
}
