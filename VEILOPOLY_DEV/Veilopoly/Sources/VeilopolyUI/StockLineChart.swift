#if os(iOS) && canImport(SwiftUI)
import SwiftUI
import VeilopolyEngine

/// Lightweight, dependency-free chart inspired by common finance chart APIs.
/// It uses the authoritative quote history and never synthesizes display-only prices.
public struct VeilopolyStockLineChart: View {
 public let quote: StockQuote
 public init(quote: StockQuote) { self.quote = quote }

 public var body: some View {
  let points = Array(quote.history.suffix(60))
  let rising = quote.currentPriceCents >= quote.previousCloseCents
  let accent = rising ? Color.green : Color.red
  Canvas { context, size in
   guard points.count > 1,
         let minimum = points.map(\.priceCents).min(),
         let maximum = points.map(\.priceCents).max() else { return }
   let spread = max(1, maximum - minimum)
   func location(_ index: Int, _ point: StockPricePoint) -> CGPoint {
    let x = size.width * CGFloat(index) / CGFloat(points.count - 1)
    let normalized = CGFloat(point.priceCents - minimum) / CGFloat(spread)
    return CGPoint(x: x, y: size.height - normalized * (size.height - 12) - 6)
   }
   for row in 1...3 {
    let y = size.height * CGFloat(row) / 4
    var grid = Path(); grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
    context.stroke(grid, with: .color(.white.opacity(0.08)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
   }
   var line = Path()
   for (index, point) in points.enumerated() {
    let p = location(index, point)
    index == 0 ? line.move(to: p) : line.addLine(to: p)
   }
   var area = line
   area.addLine(to: CGPoint(x: size.width, y: size.height))
   area.addLine(to: CGPoint(x: 0, y: size.height))
   area.closeSubpath()
   context.fill(area, with: .linearGradient(
    Gradient(colors: [accent.opacity(0.30), accent.opacity(0.01)]),
    startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
   context.stroke(line, with: .color(accent), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
  }
  .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
  .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10)) }
  .accessibilityElement(children: .ignore)
  .accessibilityLabel("\(quote.name)价格走势，当前每股\(quote.currentPriceCents / 100)元\(quote.currentPriceCents % 100)分")
 }
}
#endif
