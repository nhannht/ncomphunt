#!/usr/bin/env swift
//
// Real mouse events for screenshot staging.
//
// Why this exists: System Events' `click at {x, y}` does NOT land on SwiftUI
// controls. It reports success, reports hitting the static text under the
// control, and nothing gains focus or selection. Accessibility actions are the
// wrong layer for a SwiftUI view that never published one.
//
// CGEvent posts at the HID layer instead, which is indistinguishable from a
// real mouse to everything above it. Once a click from here has landed, focus
// is genuine and AppleScript `keystroke` works normally.
//
// Requires Accessibility permission for the CALLING process (the terminal),
// not for this script. `uiclick check` reports whether that is granted -
// without it every post is silently dropped and staging fails with no error.
//
// Coordinates are global, origin top-left, same convention AppleScript uses for
// window position, so a window at {50, 60} has its own origin at exactly that.
//
//   swift scripts/uiclick.swift check
//   swift scripts/uiclick.swift move  640 400
//   swift scripts/uiclick.swift click 640 400
//   swift scripts/uiclick.swift click 640 400 --double
//
import ApplicationServices
import CoreGraphics
import Foundation

/// Long enough for the target to process each phase, short enough that staging
/// stays snappy. A down/up posted in the same run loop turn reads as a glitch
/// to some views and gets dropped.
let phaseDelay: UInt32 = 60_000  // microseconds

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("uiclick: \(message)\n".utf8))
    exit(1)
}

func post(_ type: CGEventType, _ point: CGPoint, clickState: Int64) {
    guard let event = CGEvent(
        mouseEventSource: nil, mouseType: type,
        mouseCursorPosition: point, mouseButton: .left)
    else { fail("could not create \(type) event") }
    // Without an explicit click state a synthesized down/up is not recognised
    // as a click by views that distinguish single from double.
    event.setIntegerValueField(.mouseEventClickState, value: clickState)
    event.post(tap: .cghidEventTap)
}

func move(to point: CGPoint) {
    post(.mouseMoved, point, clickState: 0)
    usleep(phaseDelay)
}

func click(at point: CGPoint, double: Bool) {
    // Move first. A click posted at a position the cursor never travelled to
    // leaves hover state stale, so menus and popovers that open on hover do
    // not arm before the press lands.
    move(to: point)
    for state in double ? [1, 2] : [1] {
        post(.leftMouseDown, point, clickState: Int64(state))
        usleep(phaseDelay)
        post(.leftMouseUp, point, clickState: Int64(state))
        usleep(phaseDelay)
    }
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    fail("usage: uiclick check | move <x> <y> | click <x> <y> [--double]")
}

if command == "check" {
    let trusted = AXIsProcessTrusted()
    print("accessibility: \(trusted ? "granted" : "DENIED")")
    // Non-zero on denial so a staging script can stop before it stages a
    // window it will never be able to click.
    exit(trusted ? 0 : 1)
}

guard args.count >= 3, let x = Double(args[1]), let y = Double(args[2]) else {
    fail("usage: uiclick check | move <x> <y> | click <x> <y> [--double]")
}
guard AXIsProcessTrusted() else {
    fail("accessibility permission denied for the calling process - every "
         + "event would be silently dropped. Grant it to the terminal in "
         + "System Settings > Privacy & Security > Accessibility.")
}

let point = CGPoint(x: x, y: y)
switch command {
case "move":  move(to: point)
case "click": click(at: point, double: args.contains("--double"))
default:      fail("unknown command '\(command)'")
}
