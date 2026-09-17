import SwiftUI

struct TabItemOutline: InsettableShape {
    var radius: CGFloat
    var skipsLeadingEdge = false
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        var path = Path()

        if skipsLeadingEdge {
            path.move(to: CGPoint(x: rect.minX, y: box.minY))
        } else {
            path.move(to: CGPoint(x: box.minX, y: rect.maxY))
            path.addArc(
                tangent1End: CGPoint(x: box.minX, y: box.minY),
                tangent2End: CGPoint(x: box.maxX, y: box.minY),
                radius: radius
            )
        }

        path.addArc(
            tangent1End: CGPoint(x: box.maxX, y: box.minY),
            tangent2End: CGPoint(x: box.maxX, y: box.maxY),
            radius: radius
        )
        path.addLine(to: CGPoint(x: box.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: box.minX, y: rect.maxY))
        if !skipsLeadingEdge {
            path.closeSubpath()
        }
        return path
    }

    func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.inset += amount
        return copy
    }
}
