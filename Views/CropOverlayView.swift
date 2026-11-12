import SwiftUI

struct CropOverlayView: View {
    let cropRect: CGRect
    let displaySize: CGSize
    let lockedAspectRatio: CGFloat?
    let onChange: (CGRect) -> Void

    @State private var dragStartCrop: CGRect?
    @State private var isDragging = false

    private enum Handle: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    var body: some View {
        GeometryReader { geometry in
            let viewSize = geometry.size
            let box = CGRect(
                x: cropRect.origin.x * viewSize.width,
                y: cropRect.origin.y * viewSize.height,
                width: cropRect.width * viewSize.width,
                height: cropRect.height * viewSize.height
            )

            ZStack(alignment: .topLeading) {
                // Ztmavení oblasti mimo výřez
                DimmedMaskShape(cutout: box)
                    .fill(Color.black.opacity(0.58), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)

                // Vnitřní mřížka třetin + ohraničení
                ZStack {
                    RuleOfThirdsGrid()
                        .stroke(Color.white.opacity(isDragging ? 0.55 : 0.28), lineWidth: 1)

                    Rectangle()
                        .strokeBorder(Color.white, lineWidth: 1.75)
                }
                .frame(width: max(1, box.width), height: max(1, box.height))
                .position(x: box.midX, y: box.midY)
                .contentShape(Rectangle())
                .gesture(moveGesture(in: viewSize))

                // Indikátor výsledných pixelů výřezu
                pixelBadge(for: cropRect)
                    .position(
                        x: min(max(52, box.minX + 52), max(52, viewSize.width - 52)),
                        y: max(18, box.minY + 18)
                    )
                    .allowsHitTesting(false)

                // Úchyty pro změnu velikosti (rohy + hrany)
                ForEach(Handle.allCases, id: \.self) { handle in
                    handleView(for: handle)
                        .position(handlePosition(for: handle, in: box))
                        .gesture(resizeGesture(for: handle, in: viewSize))
                }
            }
        }
    }

    private func pixelBadge(for normalized: CGRect) -> some View {
        let w = max(2, Int((normalized.width * displaySize.width / 2.0).rounded()) * 2)
        let h = max(2, Int((normalized.height * displaySize.height / 2.0).rounded()) * 2)
        return Text("\(w) × \(h)")
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.72), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.75))
    }

    @ViewBuilder
    private func handleView(for handle: Handle) -> some View {
        switch handle {
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            Circle()
                .fill(Color.white)
                .frame(width: 13, height: 13)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .padding(8)
                .contentShape(Rectangle())
        case .top, .bottom:
            Capsule()
                .fill(Color.white)
                .frame(width: 24, height: 5)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .padding(8)
                .contentShape(Rectangle())
        case .left, .right:
            Capsule()
                .fill(Color.white)
                .frame(width: 5, height: 24)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .padding(8)
                .contentShape(Rectangle())
        }
    }

    private func handlePosition(for handle: Handle, in box: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: return CGPoint(x: box.minX, y: box.minY)
        case .topRight: return CGPoint(x: box.maxX, y: box.minY)
        case .bottomLeft: return CGPoint(x: box.minX, y: box.maxY)
        case .bottomRight: return CGPoint(x: box.maxX, y: box.maxY)
        case .top: return CGPoint(x: box.midX, y: box.minY)
        case .bottom: return CGPoint(x: box.midX, y: box.maxY)
        case .left: return CGPoint(x: box.minX, y: box.midY)
        case .right: return CGPoint(x: box.maxX, y: box.midY)
        }
    }

    private func moveGesture(in viewSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard viewSize.width > 1, viewSize.height > 1 else { return }
                if dragStartCrop == nil {
                    dragStartCrop = cropRect
                    isDragging = true
                }
                guard let start = dragStartCrop else { return }

                let dxNorm = value.translation.width / viewSize.width
                let dyNorm = value.translation.height / viewSize.height

                let clampedX = max(0, min(1.0 - start.width, start.origin.x + dxNorm))
                let clampedY = max(0, min(1.0 - start.height, start.origin.y + dyNorm))
                onChange(CGRect(x: clampedX, y: clampedY, width: start.width, height: start.height))
            }
            .onEnded { _ in
                dragStartCrop = nil
                isDragging = false
            }
    }

    private func resizeGesture(for handle: Handle, in viewSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard viewSize.width > 1, viewSize.height > 1,
                      displaySize.width > 1, displaySize.height > 1 else { return }
                if dragStartCrop == nil {
                    dragStartCrop = cropRect
                    isDragging = true
                }
                guard let start = dragStartCrop else { return }

                let dxPx = value.translation.width * (displaySize.width / viewSize.width)
                let dyPx = value.translation.height * (displaySize.height / viewSize.height)

                let startPx = CGRect(
                    x: start.origin.x * displaySize.width,
                    y: start.origin.y * displaySize.height,
                    width: start.width * displaySize.width,
                    height: start.height * displaySize.height
                )

                let updatedPx: CGRect
                if let ratio = lockedAspectRatio {
                    updatedPx = resizeLockedAspect(
                        startPx: startPx,
                        handle: handle,
                        dx: dxPx,
                        dy: dyPx,
                        aspectRatio: ratio
                    )
                } else {
                    updatedPx = resizeFree(
                        startPx: startPx,
                        handle: handle,
                        dx: dxPx,
                        dy: dyPx
                    )
                }

                let normalized = CGRect(
                    x: updatedPx.origin.x / displaySize.width,
                    y: updatedPx.origin.y / displaySize.height,
                    width: updatedPx.width / displaySize.width,
                    height: updatedPx.height / displaySize.height
                )
                onChange(normalized)
            }
            .onEnded { _ in
                dragStartCrop = nil
                isDragging = false
            }
    }

    private func resizeFree(startPx: CGRect, handle: Handle, dx: CGFloat, dy: CGFloat) -> CGRect {
        let W = displaySize.width
        let H = displaySize.height
        let minW = min(W, max(24.0, min(W, H) * 0.1))
        let minH = min(H, max(24.0, min(W, H) * 0.1))

        var left = startPx.minX
        var right = startPx.maxX
        var top = startPx.minY
        var bottom = startPx.maxY

        switch handle {
        case .topLeft:
            left = min(right - minW, max(0, startPx.minX + dx))
            top = min(bottom - minH, max(0, startPx.minY + dy))
        case .topRight:
            right = max(left + minW, min(W, startPx.maxX + dx))
            top = min(bottom - minH, max(0, startPx.minY + dy))
        case .bottomLeft:
            left = min(right - minW, max(0, startPx.minX + dx))
            bottom = max(top + minH, min(H, startPx.maxY + dy))
        case .bottomRight:
            right = max(left + minW, min(W, startPx.maxX + dx))
            bottom = max(top + minH, min(H, startPx.maxY + dy))
        case .top:
            top = min(bottom - minH, max(0, startPx.minY + dy))
        case .bottom:
            bottom = max(top + minH, min(H, startPx.maxY + dy))
        case .left:
            left = min(right - minW, max(0, startPx.minX + dx))
        case .right:
            right = max(left + minW, min(W, startPx.maxX + dx))
        }

        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    private func resizeLockedAspect(
        startPx: CGRect,
        handle: Handle,
        dx: CGFloat,
        dy: CGFloat,
        aspectRatio ratio: CGFloat
    ) -> CGRect {
        let W = displaySize.width
        let H = displaySize.height
        let baseMin = max(24.0, min(W, H) * 0.1)

        var minW = max(baseMin, baseMin * ratio)
        var minH = minW / ratio
        if minH < baseMin {
            minH = baseMin
            minW = minH * ratio
        }
        if minW > W {
            minW = W
            minH = minW / ratio
        }
        if minH > H {
            minH = H
            minW = minH * ratio
        }

        func fitSize(proposedW: CGFloat, proposedH: CGFloat, maxW: CGFloat, maxH: CGFloat, preferWidth: Bool) -> CGSize {
            var w: CGFloat
            var h: CGFloat
            if preferWidth {
                w = max(minW, min(maxW, proposedW))
                h = w / ratio
                if h > maxH {
                    h = maxH
                    w = h * ratio
                }
            } else {
                h = max(minH, min(maxH, proposedH))
                w = h * ratio
                if w > maxW {
                    w = maxW
                    h = w / ratio
                }
            }
            if w < minW {
                w = min(minW, maxW)
                h = w / ratio
            }
            if h < minH {
                h = min(minH, maxH)
                w = h * ratio
            }
            return CGSize(width: w, height: h)
        }

        switch handle {
        case .topLeft:
            let anchorX = startPx.maxX
            let anchorY = startPx.maxY
            let preferW = abs(dx) >= abs(dy) * ratio
            let sz = fitSize(
                proposedW: startPx.width - dx,
                proposedH: startPx.height - dy,
                maxW: anchorX,
                maxH: anchorY,
                preferWidth: preferW
            )
            return CGRect(x: anchorX - sz.width, y: anchorY - sz.height, width: sz.width, height: sz.height)

        case .topRight:
            let anchorX = startPx.minX
            let anchorY = startPx.maxY
            let preferW = abs(dx) >= abs(dy) * ratio
            let sz = fitSize(
                proposedW: startPx.width + dx,
                proposedH: startPx.height - dy,
                maxW: W - anchorX,
                maxH: anchorY,
                preferWidth: preferW
            )
            return CGRect(x: anchorX, y: anchorY - sz.height, width: sz.width, height: sz.height)

        case .bottomLeft:
            let anchorX = startPx.maxX
            let anchorY = startPx.minY
            let preferW = abs(dx) >= abs(dy) * ratio
            let sz = fitSize(
                proposedW: startPx.width - dx,
                proposedH: startPx.height + dy,
                maxW: anchorX,
                maxH: H - anchorY,
                preferWidth: preferW
            )
            return CGRect(x: anchorX - sz.width, y: anchorY, width: sz.width, height: sz.height)

        case .bottomRight:
            let anchorX = startPx.minX
            let anchorY = startPx.minY
            let preferW = abs(dx) >= abs(dy) * ratio
            let sz = fitSize(
                proposedW: startPx.width + dx,
                proposedH: startPx.height + dy,
                maxW: W - anchorX,
                maxH: H - anchorY,
                preferWidth: preferW
            )
            return CGRect(x: anchorX, y: anchorY, width: sz.width, height: sz.height)

        case .left:
            let anchorX = startPx.maxX
            let sz = fitSize(proposedW: startPx.width - dx, proposedH: 0, maxW: anchorX, maxH: H, preferWidth: true)
            let y = max(0, min(H - sz.height, startPx.midY - sz.height / 2.0))
            return CGRect(x: anchorX - sz.width, y: y, width: sz.width, height: sz.height)

        case .right:
            let anchorX = startPx.minX
            let sz = fitSize(proposedW: startPx.width + dx, proposedH: 0, maxW: W - anchorX, maxH: H, preferWidth: true)
            let y = max(0, min(H - sz.height, startPx.midY - sz.height / 2.0))
            return CGRect(x: anchorX, y: y, width: sz.width, height: sz.height)

        case .top:
            let anchorY = startPx.maxY
            let sz = fitSize(proposedW: 0, proposedH: startPx.height - dy, maxW: W, maxH: anchorY, preferWidth: false)
            let x = max(0, min(W - sz.width, startPx.midX - sz.width / 2.0))
            return CGRect(x: x, y: anchorY - sz.height, width: sz.width, height: sz.height)

        case .bottom:
            let anchorY = startPx.minY
            let sz = fitSize(proposedW: 0, proposedH: startPx.height + dy, maxW: W, maxH: H - anchorY, preferWidth: false)
            let x = max(0, min(W - sz.width, startPx.midX - sz.width / 2.0))
            return CGRect(x: x, y: anchorY, width: sz.width, height: sz.height)
        }
    }
}

private struct DimmedMaskShape: Shape {
    let cutout: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(cutout)
        return path
    }
}

private struct RuleOfThirdsGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 10, rect.height > 10 else { return path }

        let x1 = rect.minX + rect.width / 3.0
        let x2 = rect.minX + (rect.width * 2.0) / 3.0
        let y1 = rect.minY + rect.height / 3.0
        let y2 = rect.minY + (rect.height * 2.0) / 3.0

        path.move(to: CGPoint(x: x1, y: rect.minY))
        path.addLine(to: CGPoint(x: x1, y: rect.maxY))
        path.move(to: CGPoint(x: x2, y: rect.minY))
        path.addLine(to: CGPoint(x: x2, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX, y: y1))
        path.addLine(to: CGPoint(x: rect.maxX, y: y1))
        path.move(to: CGPoint(x: rect.minX, y: y2))
        path.addLine(to: CGPoint(x: rect.maxX, y: y2))

        return path
    }
}
