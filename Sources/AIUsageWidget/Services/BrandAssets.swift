import AppKit
import SwiftUI

class BrandAssets {
    static let shared = BrandAssets()
    
    let claudeRaw: NSImage?
    let codexRaw: NSImage?
    let antigravityRaw: NSImage?
    
    let claudeIcon14: NSImage?
    let codexIcon14: NSImage?
    let antigravityIcon14: NSImage?
    
    private init() {
        let claude = Self.loadRawImage(named: "claude_logo") ?? Self.loadRawImage(named: "claude")
        let codex = Self.loadRawImage(named: "openai_logo") ?? Self.loadRawImage(named: "codex")
        let antigravity = Self.loadRawImage(named: "antigravity_logo")
            ?? Self.installedApplicationIcon(paths: ["/Applications/Antigravity.app", "/Applications/Antigravity IDE.app"])
        
        self.claudeRaw = claude
        self.codexRaw = codex
        self.antigravityRaw = antigravity
        
        self.claudeIcon14 = claude != nil ? Self.resizeImage(claude!, targetSize: NSSize(width: 14, height: 14)) : nil
        self.codexIcon14 = codex != nil ? Self.resizeImage(codex!, targetSize: NSSize(width: 14, height: 14)) : nil
        self.antigravityIcon14 = antigravity != nil ? Self.resizeImage(antigravity!, targetSize: NSSize(width: 14, height: 14)) : nil
    }
    
    private static func loadRawImage(named name: String) -> NSImage? {
        // 1. Try Bundle.main resource
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            return img
        }
        
        // 2. Try current directory assets/
        let currentDirPath = FileManager.default.currentDirectoryPath + "/assets/\(name).png"
        if FileManager.default.fileExists(atPath: currentDirPath),
           let img = NSImage(contentsOfFile: currentDirPath) {
            return img
        }
        
        // 3. Try home developer path fallback
        let homeDevPath = NSString(string: "~/Developer/mac/ai_usage_widget/assets/\(name).png").expandingTildeInPath
        if FileManager.default.fileExists(atPath: homeDevPath),
           let img = NSImage(contentsOfFile: homeDevPath) {
            return img
        }
        
        return nil
    }

    private static func installedApplicationIcon(paths: [String]) -> NSImage? {
        guard let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }
    
    static func resizeImage(_ image: NSImage, targetSize: NSSize) -> NSImage {
        guard targetSize.width > 0 && targetSize.height > 0 && image.size.width > 0 && image.size.height > 0 else {
            return image
        }
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }
    
    func createMenuBarImage(
        totalTokensText: String,
        claudeText: String?,
        codexText: String?,
        antigravityText: String?,
        showQuota: Bool
    ) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .bold)
        let iconSize: CGFloat = 13.0
        let padding: CGFloat = 3.5
        let itemSpacing: CGFloat = 8.0
        let height: CGFloat = 18.0
        
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        let boltImg = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
        
        var elements: [(image: NSImage?, text: String)] = [
            (boltImg, totalTokensText)
        ]
        
        if showQuota, let cText = claudeText {
            elements.append((claudeRaw, cText))
        }
        
        if showQuota, let xText = codexText {
            elements.append((codexRaw, xText))
        }
        if showQuota, let aText = antigravityText {
            let fallback = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            elements.append((antigravityRaw ?? fallback, aText))
        }
        
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        
        var totalWidth: CGFloat = 0
        var drawnElements: [(img: NSImage?, text: String, imgSize: NSSize, textSize: NSSize)] = []
        
        for (index, elem) in elements.enumerated() {
            if index > 0 {
                totalWidth += itemSpacing
            }
            
            var imgSize = NSSize.zero
            if let img = elem.image, img.size.width > 0 && img.size.height > 0 {
                let aspect = img.size.width / max(1.0, img.size.height)
                imgSize = NSSize(width: max(1.0, iconSize * aspect), height: iconSize)
                totalWidth += imgSize.width + padding
            }
            
            let textSize = (elem.text as NSString).size(withAttributes: textAttrs)
            totalWidth += max(1.0, textSize.width)
            
            drawnElements.append((elem.image, elem.text, imgSize, textSize))
        }
        
        let finalWidth = max(20.0, totalWidth)
        let composite = NSImage(size: NSSize(width: finalWidth, height: height))
        composite.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        
        var currentX: CGFloat = 0
        
        for elem in drawnElements {
            if let img = elem.img, elem.imgSize.width > 0 && elem.imgSize.height > 0 {
                let yOffset = (height - elem.imgSize.height) / 2.0
                let rect = NSRect(x: currentX, y: yOffset, width: elem.imgSize.width, height: elem.imgSize.height)
                
                if img == boltImg {
                    let tinted = NSImage(size: elem.imgSize)
                    tinted.lockFocus()
                    NSColor.labelColor.set()
                    let symbolRect = NSRect(origin: .zero, size: elem.imgSize)
                    img.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                    symbolRect.fill(using: .sourceIn)
                    tinted.unlockFocus()
                    tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                } else {
                    img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                }
                currentX += elem.imgSize.width + padding
            }
            
            let textY = (height - elem.textSize.height) / 2.0
            let textRect = NSRect(x: currentX, y: textY, width: elem.textSize.width, height: elem.textSize.height)
            (elem.text as NSString).draw(in: textRect, withAttributes: textAttrs)
            
            currentX += elem.textSize.width + itemSpacing
        }
        
        composite.unlockFocus()
        return composite
    }
}
