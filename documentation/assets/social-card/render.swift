// Renders an HTML page to PNG with the system WebKit (no browser install needed).
// Usage: swift render.swift <html> <readAccessRoot> <width> <height> <out.png>
import AppKit
import WebKit

let args = CommandLine.arguments
let html = URL(fileURLWithPath: args[1]), root = URL(fileURLWithPath: args[2])
let width = Double(args[3])!, height = Double(args[4])!, out = args[5]

final class Delegate: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.documentElement.style.setProperty('--h','\(Int(height))px'); Promise.all([...document.images].map(i=>i.decode())).then(()=>1)") { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let config = WKSnapshotConfiguration()
                config.rect = CGRect(x: 0, y: 0, width: width, height: height)
                config.snapshotWidth = NSNumber(value: width)
                webView.takeSnapshot(with: config) { image, error in
                    guard let image, let tiff = image.tiffRepresentation,
                          let rep = NSBitmapImageRep(data: tiff),
                          let png = rep.representation(using: .png, properties: [:]) else {
                        FileHandle.standardError.write("snapshot failed: \(String(describing: error))\n".data(using: .utf8)!); exit(1)
                    }
                    try! png.write(to: URL(fileURLWithPath: out)); exit(0)
                }
            }
        }
    }
}

let app = NSApplication.shared
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
let webView = WKWebView(frame: window.contentView!.bounds)
let delegate = Delegate()
webView.navigationDelegate = delegate
window.contentView!.addSubview(webView)
webView.loadFileURL(html, allowingReadAccessTo: root)
DispatchQueue.main.asyncAfter(deadline: .now() + 20) { FileHandle.standardError.write("timeout\n".data(using: .utf8)!); exit(2) }
app.run()
