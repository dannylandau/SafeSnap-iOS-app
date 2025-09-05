//
//  AlertPresenter.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 05/09/2025.
//

import SwiftUI

struct AlertPresenter: ViewModifier {
    @ObservedObject var center: AlertCenter

    func body(content: Content) -> some View {
        content.alert(
            center.current?.title ?? "",
            isPresented: Binding(
                get: { center.current != nil },
                set: { isPresented in
                    if !isPresented { center.dismiss() }
                }
            ),
            actions: {
                let actions = (center.current?.actions).nonEmpty ?? [AlertAction(title: "OK")]
                ForEach(actions) { action in
                    switch action.role {
                    case .normal:
                        Button(action.title) {
                            action.perform()
                            center.dismiss()
                        }
                    case .cancel:
                        Button(action.title, role: .cancel) {
                            action.perform()
                            center.dismiss()
                        }
                    case .destructive:
                        Button(action.title, role: .destructive) {
                            action.perform()
                            center.dismiss()
                        }
                    }
                }
            },
            message: {
                if let message = center.current?.message {
                    Text(message)
                }
            }
        )
    }
}

extension View {
    func alerts(using center: AlertCenter) -> some View {
        modifier(AlertPresenter(center: center))
    }
}

// Small convenience so we can do `.nonEmpty ?? [...]`
private extension Optional where Wrapped: Collection {
    var nonEmpty: Wrapped? { self?.isEmpty == false ? self : nil }
}
