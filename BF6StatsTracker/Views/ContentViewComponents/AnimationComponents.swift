//
// This file is part of BF6StatsTracker.
//
// BF6StatsTracker is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 or later.
//
// Copyright (c) 2026 CitizenCoder
//

//
//  AnimationComponents.swift
//  BF6StatsTracker
//
//  Custom animations and AppKit integrations
//

import SwiftUI
import AppKit

// MARK: - Pulsating Circle (Core Animation)

struct PulsatingCircle: NSViewRepresentable {
    let color: Color

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true

        let shapeLayer = CAShapeLayer()
        let size: CGFloat = 28
        let circlePath = NSBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size))
        shapeLayer.path = circlePath.cgPath
        shapeLayer.fillColor = NSColor(color).withAlphaComponent(0.4).cgColor
        shapeLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)

        // Core Animation - runs entirely on GPU
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.4
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        shapeLayer.add(pulseAnimation, forKey: "pulse")

        view.layer?.addSublayer(shapeLayer)

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed - animation is continuous
    }
}

// MARK: - NSBezierPath to CGPath Extension

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            default:
                break
            }
        }

        return path
    }
}
