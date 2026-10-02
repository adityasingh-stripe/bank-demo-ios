#!/usr/bin/env swift

import AppKit
import Foundation

enum RenderError: Error, CustomStringConvertible {
    case usage
    case invalidColor(String)
    case invalidTreatment(String)
    case unreadableImage(String)
    case renderFailed
    case writeFailed(String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: render-brand-assets.swift <logo> <background-hex> <original|white> <app-icon-output> <launch-logo-output>"
        case .invalidColor(let value):
            return "Invalid six-digit RGB colour: \(value)"
        case .invalidTreatment(let value):
            return "Invalid logo treatment: \(value)"
        case .unreadableImage(let path):
            return "Unable to read logo image: \(path)"
        case .renderFailed:
            return "Unable to create the rendered bitmap"
        case .writeFailed(let path):
            return "Unable to write rendered image: \(path)"
        }
    }
}

func color(from hex: String) throws -> NSColor {
    let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard value.count == 6, let rgb = Int(value, radix: 16) else {
        throw RenderError.invalidColor(hex)
    }
    return NSColor(
        red: CGFloat((rgb >> 16) & 0xff) / 255,
        green: CGFloat((rgb >> 8) & 0xff) / 255,
        blue: CGFloat(rgb & 0xff) / 255,
        alpha: 1
    )
}

func aspectFit(source: NSSize, in bounds: NSRect) -> NSRect {
    let scale = min(bounds.width / source.width, bounds.height / source.height)
    let size = NSSize(width: source.width * scale, height: source.height * scale)
    return NSRect(
        x: bounds.midX - size.width / 2,
        y: bounds.midY - size.height / 2,
        width: size.width,
        height: size.height
    )
}

func bitmap(size: Int, alpha: Bool) throws -> NSBitmapImageRep {
    guard let result = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: alpha ? 4 : 3,
        hasAlpha: alpha,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw RenderError.renderFailed
    }
    result.size = NSSize(width: size, height: size)
    return result
}

func logoLayer(image: NSImage, treatment: String, canvasSize: Int, inset: CGFloat) throws -> NSBitmapImageRep {
    let result = try bitmap(size: canvasSize, alpha: true)
    let context = NSGraphicsContext(bitmapImageRep: result)!
    let canvas = NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
    let target = aspectFit(source: image.size, in: canvas.insetBy(dx: inset, dy: inset))

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    NSColor.clear.setFill()
    NSBezierPath(rect: canvas).fill()
    image.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)

    switch treatment {
    case "original":
        break
    case "white":
        context.compositingOperation = .sourceIn
        NSColor.white.setFill()
        NSBezierPath(rect: canvas).fill()
    default:
        NSGraphicsContext.restoreGraphicsState()
        throw RenderError.invalidTreatment(treatment)
    }

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return result
}

func appIcon(logo: NSBitmapImageRep, background: NSColor, size: Int) throws -> NSBitmapImageRep {
    let result = try bitmap(size: size, alpha: true)
    let context = NSGraphicsContext(bitmapImageRep: result)!
    let canvas = NSRect(x: 0, y: 0, width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    background.setFill()
    NSBezierPath(rect: canvas).fill()
    let logoImage = NSImage(size: canvas.size)
    logoImage.addRepresentation(logo)
    logoImage.draw(in: canvas, from: .zero, operation: .sourceOver, fraction: 1)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return result
}

func write(_ image: NSBitmapImageRep, to path: String) throws {
    guard let data = image.representation(using: .png, properties: [:]) else {
        throw RenderError.renderFailed
    }
    do {
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    } catch {
        throw RenderError.writeFailed(path)
    }
}

do {
    guard CommandLine.arguments.count == 6 else { throw RenderError.usage }
    let logoPath = CommandLine.arguments[1]
    let background = try color(from: CommandLine.arguments[2])
    let treatment = CommandLine.arguments[3]
    let iconPath = CommandLine.arguments[4]
    let launchPath = CommandLine.arguments[5]

    guard let source = NSImage(contentsOfFile: logoPath), source.size.width > 0, source.size.height > 0 else {
        throw RenderError.unreadableImage(logoPath)
    }

    let launchLogo = try logoLayer(image: source, treatment: treatment, canvasSize: 1024, inset: 162)
    let iconLogo = try logoLayer(image: source, treatment: treatment, canvasSize: 1024, inset: 162)
    let icon = try appIcon(logo: iconLogo, background: background, size: 1024)
    try write(icon, to: iconPath)
    try write(launchLogo, to: launchPath)
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
