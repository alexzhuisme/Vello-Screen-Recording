import CoreGraphics
import Testing
@testable import VelloUI

@Suite("SelectionGeometry")
struct SelectionGeometryTests {
    private let display = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let minimum = CGSize(width: 32, height: 32)

    // MARK: - Creating

    @Test("Dragging in any direction produces a normalized rectangle")
    func normalizesDragDirection() {
        let downRight = SelectionGeometry.normalized(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 300, y: 250),
            in: display
        )
        let upLeft = SelectionGeometry.normalized(
            from: CGPoint(x: 300, y: 250),
            to: CGPoint(x: 100, y: 100),
            in: display
        )
        #expect(downRight == CGRect(x: 100, y: 100, width: 200, height: 150))
        #expect(downRight == upLeft)
    }

    @Test("A drag beyond the display is clipped to it")
    func clipsToDisplay() {
        let rect = SelectionGeometry.normalized(
            from: CGPoint(x: 1500, y: 900),
            to: CGPoint(x: 2200, y: 1400),
            in: display
        )
        #expect(rect == CGRect(x: 1500, y: 900, width: 100, height: 100))
    }

    // MARK: - Moving

    @Test("Moving keeps the size unchanged")
    func movePreservesSize() {
        let rect = CGRect(x: 100, y: 100, width: 400, height: 300)
        let moved = SelectionGeometry.move(rect, by: CGSize(width: 50, height: -40), in: display)
        #expect(moved == CGRect(x: 150, y: 60, width: 400, height: 300))
    }

    @Test("Moving stops at the display edges instead of leaving the screen")
    func moveClampsToDisplay() {
        let rect = CGRect(x: 100, y: 100, width: 400, height: 300)

        let pastRight = SelectionGeometry.move(rect, by: CGSize(width: 5000, height: 0), in: display)
        #expect(pastRight.maxX == display.maxX)
        #expect(pastRight.size == rect.size)

        let pastTopLeft = SelectionGeometry.move(rect, by: CGSize(width: -5000, height: -5000), in: display)
        #expect(pastTopLeft.origin == .zero)
    }

    // MARK: - Resizing

    @Test("Dragging the bottom-right handle grows both dimensions")
    func resizeBottomRight() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
        let resized = SelectionGeometry.resize(
            rect,
            handle: .bottomRight,
            translation: CGSize(width: 100, height: 50),
            in: display,
            minimumSize: minimum
        )
        #expect(resized == CGRect(x: 100, y: 100, width: 300, height: 250))
    }

    @Test("Dragging the top-left handle moves the origin and keeps the far corner")
    func resizeTopLeft() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
        let resized = SelectionGeometry.resize(
            rect,
            handle: .topLeft,
            translation: CGSize(width: -40, height: -60),
            in: display,
            minimumSize: minimum
        )
        #expect(resized == CGRect(x: 60, y: 40, width: 240, height: 260))
        #expect(resized.maxX == rect.maxX)
        #expect(resized.maxY == rect.maxY)
    }

    @Test("An edge handle only affects its own axis")
    func edgeHandleIsSingleAxis() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
        let resized = SelectionGeometry.resize(
            rect,
            handle: .right,
            translation: CGSize(width: 60, height: 999),
            in: display,
            minimumSize: minimum
        )
        #expect(resized.height == rect.height)
        #expect(resized.width == 260)
    }

    @Test("Resizing cannot collapse the region below the minimum size")
    func respectsMinimumSize() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
        let collapsed = SelectionGeometry.resize(
            rect,
            handle: .topLeft,
            translation: CGSize(width: 500, height: 500),
            in: display,
            minimumSize: minimum
        )
        #expect(collapsed.width == minimum.width)
        #expect(collapsed.height == minimum.height)
    }

    @Test("Resizing stays inside the display")
    func resizeClampsToDisplay() {
        let rect = CGRect(x: 1400, y: 800, width: 100, height: 100)
        let resized = SelectionGeometry.resize(
            rect,
            handle: .bottomRight,
            translation: CGSize(width: 500, height: 500),
            in: display,
            minimumSize: minimum
        )
        #expect(resized.maxX == display.maxX)
        #expect(resized.maxY == display.maxY)
    }

    @Test("Locking the aspect ratio keeps the original proportions")
    func aspectRatioLock() {
        let rect = CGRect(x: 100, y: 100, width: 400, height: 200) // 2:1
        let resized = SelectionGeometry.resize(
            rect,
            handle: .bottomRight,
            translation: CGSize(width: 200, height: 0),
            lockAspectRatio: true,
            in: display,
            minimumSize: minimum
        )
        #expect(resized.width == 600)
        #expect(abs(resized.height - 300) < 0.001)
    }

    // MARK: - Handles

    @Test("Each handle sits on its own corner or edge midpoint")
    func handlePositions() {
        let rect = CGRect(x: 100, y: 200, width: 400, height: 300)
        #expect(ResizeHandle.topLeft.position(in: rect) == CGPoint(x: 100, y: 200))
        #expect(ResizeHandle.bottomRight.position(in: rect) == CGPoint(x: 500, y: 500))
        #expect(ResizeHandle.top.position(in: rect) == CGPoint(x: 300, y: 200))
        #expect(ResizeHandle.left.position(in: rect) == CGPoint(x: 100, y: 350))
    }

    @Test("Corner handles are distinguished from edge handles")
    func cornerClassification() {
        #expect(ResizeHandle.allCases.filter(\.isCorner).count == 4)
        #expect(!ResizeHandle.top.isCorner)
    }

    // MARK: - Defaults and rounding

    @Test("The default selection is centred and fits the display")
    func defaultSelection() {
        let rect = SelectionGeometry.defaultSelection(in: display)
        #expect(display.contains(rect))
        #expect(abs(rect.midX - display.midX) <= 1)
        #expect(abs(rect.midY - display.midY) <= 1)
    }

    @Test("Odd dimensions are rounded down to even ones for the encoder")
    func evenSizing() {
        let rect = SelectionGeometry.evenSized(CGRect(x: 10.4, y: 20.6, width: 301.2, height: 199.8))
        #expect(rect.width.truncatingRemainder(dividingBy: 2) == 0)
        #expect(rect.height.truncatingRemainder(dividingBy: 2) == 0)
        #expect(rect.origin == CGPoint(x: 10, y: 21))
    }

    @Test("Tiny regions still round up to the encoder minimum")
    func evenSizingFloor() {
        let rect = SelectionGeometry.evenSized(CGRect(x: 0, y: 0, width: 1, height: 1))
        #expect(rect.width == 2)
        #expect(rect.height == 2)
    }
}
