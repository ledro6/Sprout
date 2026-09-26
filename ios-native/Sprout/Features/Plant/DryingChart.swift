import Charts
import SwiftUI

/// Как сохнет земля — линией: полив поднимает её к ста процентам, дальше она
/// ползёт вниз по сроку растения, пока не польют снова. Пила ровная —
/// поливают вовремя; зубья до самого дна — растение пересыхало. Жёлтая и
/// красная полосы — где карточка начинает просить воды.
struct DryingChart: View {
    let points: [Diary.Point]

    private static let timeAxis = LocalizedStringKey(Lang.key("Когда"))
    private static let levelAxis = LocalizedStringKey(Lang.key("Вода в земле"))

    var body: some View {
        Chart {
            if let first = points.first?.when, let last = points.last?.when {
                RectangleMark(xStart: .value(Self.timeAxis, first),
                              xEnd: .value(Self.timeAxis, last),
                              yStart: .value(Self.levelAxis, 0),
                              yEnd: .value(Self.levelAxis, Thirst.alarmBelow))
                    .foregroundStyle(Palette.alarm.opacity(0.08))
                RectangleMark(xStart: .value(Self.timeAxis, first),
                              xEnd: .value(Self.timeAxis, last),
                              yStart: .value(Self.levelAxis, Thirst.alarmBelow),
                              yEnd: .value(Self.levelAxis, Thirst.warnBelow))
                    .foregroundStyle(Palette.warn.opacity(0.06))
            }
            ForEach(points) { point in
                AreaMark(x: .value(Self.timeAxis, point.when),
                         y: .value(Self.levelAxis, point.level))
                    .interpolationMethod(.linear)
                    .foregroundStyle(LinearGradient(
                        colors: [Palette.water.opacity(0.32),
                                 Palette.water.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom))
                LineMark(x: .value(Self.timeAxis, point.when),
                         y: .value(Self.levelAxis, point.level))
                    .interpolationMethod(.linear)
                    .foregroundStyle(Palette.water)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round,
                                           lineJoin: .round))
            }
            ForEach(points.filter(\.poured)) { point in
                PointMark(x: .value(Self.timeAxis, point.when),
                          y: .value(Self.levelAxis, point.level))
                    .symbol {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Palette.water)
                            .offset(y: -9)
                    }
            }
            if let now = points.last, !now.poured {
                PointMark(x: .value(Self.timeAxis, now.when),
                          y: .value(Self.levelAxis, now.level))
                    .foregroundStyle(Palette.level(now.level))
                    .symbolSize(60)
            }
        }
        .chartYScale(domain: 0 ... 1.08)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 0.5, 1]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let level = value.as(Double.self) {
                        Text(Stats.percent(level))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)
                    .locale(Lang.locale))
            }
        }
        .frame(height: 168)
        .accessibilityElement()
        .accessibilityLabel("Как сохнет земля")
        .accessibilityValue(Lang.format("Поливов на графике: %lld",
                                        points.filter(\.poured).count))
    }
}
