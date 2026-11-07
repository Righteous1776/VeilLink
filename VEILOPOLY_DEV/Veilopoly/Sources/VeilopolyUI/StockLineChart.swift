#if os(iOS) && canImport(SwiftUI)
import Foundation
import SwiftUI
import VeilopolyEngine

/// Lightweight, dependency-free chart inspired by common finance chart APIs.
/// It uses the authoritative quote history and never synthesizes display-only prices.
public struct VeilopolyStockLineChart: View {
 public let quote: StockQuote
 @State private var inspectionFraction: Double?
 public init(quote: StockQuote) { self.quote = quote }

 public var body: some View {
  let points = Array(quote.history.suffix(60))
  let accent = quote.changeBasisPoints >= 0
   ? Color(red: 0.96, green: 0.39, blue: 0.31)
   : Color(red: 0.20, green: 0.77, blue: 0.60)
  ZStack(alignment: .topLeading) {
   Canvas { context, size in
    guard points.count > 1,
          let rawMinimum = points.map(\.priceCents).min(),
          let rawMaximum = points.map(\.priceCents).max() else { return }
    let minimum = min(rawMinimum, quote.previousCloseCents)
    let maximum = max(rawMaximum, quote.previousCloseCents)
    let spread = max(1, maximum - minimum)
    let priceHeight = size.height * 0.76
    let volumeTop = size.height * 0.82
    func location(_ index: Int, _ point: StockPricePoint) -> CGPoint {
     let x = size.width * CGFloat(index) / CGFloat(points.count - 1)
     let normalized = CGFloat(point.priceCents - minimum) / CGFloat(spread)
     return CGPoint(x: x, y: priceHeight - normalized * (priceHeight - 12) + 6)
    }
    for row in 1...3 {
     let y = priceHeight * CGFloat(row) / 4
     var grid = Path(); grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
     context.stroke(grid, with: .color(.white.opacity(0.07)),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
    }
    let closeY = priceHeight - CGFloat(quote.previousCloseCents - minimum) / CGFloat(spread) * (priceHeight - 12) + 6
    var closeLine = Path(); closeLine.move(to: CGPoint(x: 0, y: closeY))
    closeLine.addLine(to: CGPoint(x: size.width, y: closeY))
    context.stroke(closeLine, with: .color(.white.opacity(0.22)),
                   style: StrokeStyle(lineWidth: 1, dash: [5, 4]))

    let maximumVolume = max(1, points.map(\.volume).max() ?? 1)
    let barWidth = max(1, size.width / CGFloat(points.count) * 0.58)
    for (index, point) in points.enumerated() {
     let x = size.width * CGFloat(index) / CGFloat(points.count - 1)
     let height = CGFloat(point.volume) / CGFloat(maximumVolume) * (size.height - volumeTop)
     let rect = CGRect(x: x - barWidth / 2, y: size.height - height,
                       width: barWidth, height: height)
     var bar = Path(); bar.addRect(rect)
     context.fill(bar, with: .color(accent.opacity(0.24)))
    }

    var line = Path()
    for (index, point) in points.enumerated() {
     let p = location(index, point)
     index == 0 ? line.move(to: p) : line.addLine(to: p)
    }
    var area = line
    area.addLine(to: CGPoint(x: size.width, y: priceHeight))
    area.addLine(to: CGPoint(x: 0, y: priceHeight))
    area.closeSubpath()
    context.fill(area, with: .linearGradient(
     Gradient(colors: [accent.opacity(0.28), accent.opacity(0.015)]),
     startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: priceHeight)))
    context.stroke(line, with: .color(accent),
                   style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
    if let last = points.last {
     let dot = location(points.count - 1, last)
     context.fill(Path(ellipseIn: CGRect(x: dot.x - 3.5, y: dot.y - 3.5, width: 7, height: 7)),
                  with: .color(accent))
     context.stroke(Path(ellipseIn: CGRect(x: dot.x - 5.5, y: dot.y - 5.5, width: 11, height: 11)),
                    with: .color(accent.opacity(0.28)), lineWidth: 2)
    }
   }
   HStack {
    Text("近 60 tick").font(.system(size: 8, weight: .semibold))
    Spacer()
    Text("虚线 · 昨收").font(.system(size: 8, weight: .medium))
   }
   .foregroundStyle(.white.opacity(0.38)).padding(7)
  }
  .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
  .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.09)) }
  .overlay {
   GeometryReader { geometry in
    ZStack(alignment: .topLeading) {
     Color.clear.contentShape(Rectangle())
     if let fraction = inspectionFraction,
        let index = StockTerminalState.chartIndex(fraction: fraction, count: points.count) {
      let point = points[index]
      let x = geometry.size.width * CGFloat(index) / CGFloat(max(1, points.count - 1))
      Path { path in
       path.move(to: CGPoint(x: x, y: 0))
       path.addLine(to: CGPoint(x: x, y: geometry.size.height))
      }
      .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
      Text("T+\(point.tick)  ¥\(point.priceCents / 100).\(String(format: "%02d", point.priceCents % 100))\n成交量 \(point.volume)")
       .font(.system(size: 10, weight: .semibold, design: .monospaced))
       .padding(7).background(Color.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 7))
       .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: x > geometry.size.width / 2 ? .topLeading : .topTrailing)
       .padding(5)
       .allowsHitTesting(false)
     }
    }
    .gesture(
     LongPressGesture(minimumDuration: 0.25)
      .sequenced(before: DragGesture(minimumDistance: 0))
      .onChanged { value in
       if case .second(true, let drag?) = value, geometry.size.width > 0 {
        inspectionFraction = Double(drag.location.x / geometry.size.width)
       }
      }
      .onEnded { _ in inspectionFraction = nil }
    )
   }
  }
  .onChange(of: quote.symbol) { _ in inspectionFraction = nil }
  .accessibilityElement(children: .ignore)
  .accessibilityLabel("\(quote.name)价格走势，当前每股\(quote.currentPriceCents / 100)元\(quote.currentPriceCents % 100)分")
  .accessibilityHint("长按并拖动可查看历史价格与成交量")
  .accessibilityValue(inspectionDescription(points))
  .accessibilityAdjustableAction { direction in
   let step = 1.0 / Double(max(1, points.count - 1))
   switch direction {
   case .increment: inspectionFraction = min(1, (inspectionFraction ?? 0) + step)
   case .decrement: inspectionFraction = max(0, (inspectionFraction ?? 1) - step)
   @unknown default: break
   }
  }
 }

 private func inspectionDescription(_ points: [StockPricePoint]) -> String {
  guard let fraction = inspectionFraction,
        let index = StockTerminalState.chartIndex(fraction: fraction, count: points.count) else {
   return "历史走势"
  }
  let point = points[index]
  return "第\(point.tick)时点，\(point.priceCents / 100)元\(point.priceCents % 100)分，成交量\(point.volume)"
 }
}
#endif
