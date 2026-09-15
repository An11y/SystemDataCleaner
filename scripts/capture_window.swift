#!/usr/bin/env swift
import Foundation

/// Обёртка: реальные скрины рендерит само приложение (без Screen Recording).
/// Использование:
///   swift scripts/capture_window.swift [output-dir]
/// или после сборки:
///   .build/release/SystemDataCleaner --export-screenshots docs/screenshots

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : root.appendingPathComponent("docs/screenshots").path

let bin = root.appendingPathComponent(".build/release/SystemDataCleaner").path
let fm = FileManager.default

if !fm.isExecutableFile(atPath: bin) {
    fputs("Соберите release: swift build -c release\n", stderr)
    exit(1)
}

let proc = Process()
proc.executableURL = URL(fileURLWithPath: bin)
proc.arguments = ["--export-screenshots", outDir]
proc.currentDirectoryURL = root
try proc.run()
proc.waitUntilExit()
exit(proc.terminationStatus)
