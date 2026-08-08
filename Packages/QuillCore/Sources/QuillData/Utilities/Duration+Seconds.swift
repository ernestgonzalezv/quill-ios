//
//  Duration+Seconds.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
