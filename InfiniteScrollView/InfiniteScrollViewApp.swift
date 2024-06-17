//
//  InfiniteScrollViewApp.swift
//  InfiniteScrollView
//
//  Created by Евгений Коузов on 17.06.2024.
//

import SwiftUI

struct Item: Hashable {
    let color: Color
    let opacity: Double
    var text: String {
        "\(Int(opacity * 10))"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(text)
    }
}

@main
struct InfiniteScrollViewApp: App {

    @State private var elements: [Item] = [
        .init(color: .red, opacity: 0.1),
        .init(color: .red, opacity: 0.2),
        .init(color: .red, opacity: 0.3),
        .init(color: .red, opacity: 0.4),
        .init(color: .red, opacity: 0.5),
        .init(color: .red, opacity: 0.6),
        .init(color: .red, opacity: 0.7),
        .init(color: .red, opacity: 0.8),
        .init(color: .red, opacity: 0.9),
        .init(color: .red, opacity: 1.0)
    ]

    var body: some Scene {
        WindowGroup {
            DSInfiniteZoomScroll(items: $elements) { item in
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(item.color)
                        .opacity(item.opacity)
                    Text(item.text)
                        .font(.system(size: 30))
                        .foregroundStyle(.black)
                }
            }
        }
    }
}
