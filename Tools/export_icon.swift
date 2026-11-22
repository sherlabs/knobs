// Copies the 1024px icon PNG into Assets/AppIcon.png (run make_icon.swift first).
import Foundation
let fm = FileManager.default
try? fm.createDirectory(atPath: "Assets", withIntermediateDirectories: true)
try? fm.removeItem(atPath: "Assets/AppIcon.png")
try fm.copyItem(atPath: "build/AppIcon.iconset/icon_512x512@2x.png", toPath: "Assets/AppIcon.png")
print("Assets/AppIcon.png")
