//
//  Healpers.swift
//  InfiniteScrollView
//
//  Created by Евгений Коузов on 17.06.2024.
//

import Foundation

extension Collection {

    public subscript (safe index: Index) -> Iterator.Element? {
        guard self.indices.contains(index) else { return nil }
        return self[index]
    }
}
