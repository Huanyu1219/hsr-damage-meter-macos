import AppKit

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let bitmap = NSBitmapImageRep(data: try Data(contentsOf: source))!
var minX = bitmap.pixelsWide, minY = bitmap.pixelsHigh, maxX = 0, maxY = 0
var mask = [UInt8](repeating: 0, count: bitmap.pixelsWide * bitmap.pixelsHigh)
for y in 0..<bitmap.pixelsHigh {
  for x in 0..<bitmap.pixelsWide {
    let c = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    let light = (c.redComponent + c.greenComponent + c.blueComponent) / 3
    let alpha = min(1, max(0, (0.94 - light) / 0.76))
    mask[y * bitmap.pixelsWide + x] = UInt8(alpha * 255)
    if alpha > 0.25 {
      minX = min(minX, x); maxX = max(maxX, x)
      minY = min(minY, y); maxY = max(maxY, y)
    }
  }
}
let side = max(maxX - minX + 1, maxY - minY + 1) + 32
let result = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
  colorSpaceName: .deviceRGB, bytesPerRow: side * 4, bitsPerPixel: 32)!
let pixels = result.bitmapData!
pixels.initialize(repeating: 0, count: side * side * 4)
let offsetX = (side - (maxX - minX + 1)) / 2
let offsetY = (side - (maxY - minY + 1)) / 2
for y in minY...maxY {
  for x in minX...maxX {
    let index = ((y - minY + offsetY) * side + x - minX + offsetX) * 4
    pixels[index + 3] = mask[y * bitmap.pixelsWide + x]
  }
}
try result.representation(using: .png, properties: [:])!.write(to: output)
