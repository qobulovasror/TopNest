import SwiftUI

enum CompactStyle: String, CaseIterable, Identifiable {
    case standard, island, blended

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: L10n.tr("Standart")
        case .island: L10n.tr("Orolcha")
        case .blended: L10n.tr("Birlashgan")
        }
    }
}

enum ExpandedStyle: String, CaseIterable, Identifiable {
    case blended, attached, floating

    var id: Self { self }

    var title: String {
        switch self {
        case .blended: L10n.tr("Birlashgan")
        case .attached: L10n.tr("Yopishgan")
        case .floating: L10n.tr("Suzuvchi")
        }
    }

    // Ekran tepasiga yopishgan uslublar notch bilan qo'shilib ketishi uchun qora fonda.
    var attachedToTop: Bool { self != .floating }
}

enum PanelSize: String, CaseIterable, Identifiable {
    case compact, standard, large

    var id: Self { self }

    var title: String {
        switch self {
        case .compact: L10n.tr("Ixcham")
        case .standard: L10n.tr("Standart")
        case .large: L10n.tr("Katta")
        }
    }

    // Kontent maydoni (sarlavha va tablar hisobga olinmagan).
    var contentSize: CGSize {
        switch self {
        case .compact: CGSize(width: 600, height: 170)
        case .standard: CGSize(width: 680, height: 210)
        case .large: CGSize(width: 760, height: 270)
        }
    }
}

enum TabPlacement: String, CaseIterable, Identifiable {
    case bottom, top

    var id: Self { self }

    var title: String {
        switch self {
        case .bottom: L10n.tr("Panel ostida")
        case .top: L10n.tr("Panel tepasida")
        }
    }
}

enum TabLabelStyle: String, CaseIterable, Identifiable {
    case iconAndText, icon, text

    var id: Self { self }

    var title: String {
        switch self {
        case .iconAndText: L10n.tr("Ikonka va matn")
        case .icon: L10n.tr("Faqat ikonka")
        case .text: L10n.tr("Faqat matn")
        }
    }
}

// Notch shakli: tepada ekranga qo'shiladigan botiq "qanotcha" (flare) va pastki yumaloq burchaklar.
// flare > 0 bo'lsa shakl kengligiga har ikki tomondan flare qo'shiladi; flare va topRadius birga ishlatilmaydi.
struct NotchShape: InsettableShape {
    var flare: CGFloat
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> NotchShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(flare, AnimatablePair(topRadius, bottomRadius)) }
        set {
            flare = newValue.first
            topRadius = newValue.second.first
            bottomRadius = newValue.second.second
        }
    }

    func path(in fullRect: CGRect) -> Path {
        let rect = fullRect.insetBy(dx: insetAmount, dy: insetAmount)
        guard rect.width > 0, rect.height > 0 else { return Path() }
        let f = max(0, min(flare - insetAmount, rect.width / 4, rect.height / 2))
        let bodyMinX = rect.minX + f, bodyMaxX = rect.maxX - f
        let top = max(0, min(topRadius - insetAmount, (bodyMaxX - bodyMinX) / 2, rect.height / 2))
        let bottom = max(0, min(bottomRadius - insetAmount, (bodyMaxX - bodyMinX) / 2, rect.height - f))
        var path = Path()
        if f > 0 || top == 0 { path.move(to: CGPoint(x: rect.minX, y: rect.minY)) }
        if f > 0 {
            path.addQuadCurve(to: CGPoint(x: bodyMinX, y: rect.minY + f), control: CGPoint(x: bodyMinX, y: rect.minY))
        } else if top > 0 {
            path.move(to: CGPoint(x: bodyMinX, y: rect.minY + top))
            path.addQuadCurve(to: CGPoint(x: bodyMinX + top, y: rect.minY), control: CGPoint(x: bodyMinX, y: rect.minY))
            path.addLine(to: CGPoint(x: bodyMaxX - top, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: bodyMaxX, y: rect.minY + top), control: CGPoint(x: bodyMaxX, y: rect.minY))
            path.addLine(to: CGPoint(x: bodyMaxX, y: rect.maxY - bottom))
            path.addQuadCurve(to: CGPoint(x: bodyMaxX - bottom, y: rect.maxY), control: CGPoint(x: bodyMaxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: bodyMinX + bottom, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: bodyMinX, y: rect.maxY - bottom), control: CGPoint(x: bodyMinX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
        path.addLine(to: CGPoint(x: bodyMinX, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: bodyMinX + bottom, y: rect.maxY), control: CGPoint(x: bodyMinX, y: rect.maxY))
        path.addLine(to: CGPoint(x: bodyMaxX - bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: bodyMaxX, y: rect.maxY - bottom), control: CGPoint(x: bodyMaxX, y: rect.maxY))
        if f > 0 {
            path.addLine(to: CGPoint(x: bodyMaxX, y: rect.minY + f))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: bodyMaxX, y: rect.minY))
        } else {
            path.addLine(to: CGPoint(x: bodyMaxX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}
