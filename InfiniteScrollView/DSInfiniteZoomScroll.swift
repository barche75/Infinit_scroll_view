//
//  DSZoomScroll.swift
//

import SwiftUI

public struct DSInfiniteZoomScroll<Model: Hashable, Content: View>: View {

    private struct ElementWrapper<T: Hashable>: Hashable {
        let position: Int
        var element: T
    }

    private var cellSize = CGSize(width: 380, height: 380)

    private let spacing = -8.0

    private let triggerWidth = 300.0

    // time to reset scrolls while next alignment
    @State private var timeToReset = false
    // how much times first element did disappear for screen
    @State private var firstElementDisappearCount = 0
    // first element
    @State private var firstElement: ElementWrapper<Model>?
    // element in center
    @State private var centeredElement: ElementWrapper<Model>?
    // element in center when slow sroll
    @State private var slowCenteredElement: ElementWrapper<Model>?
    // ScrollView position and size
    @State private var scrollRect: CGRect = .zero
    // Array of elements
    @State private var elementsToShow: [ElementWrapper<Model>] = []
    // How much time cell stays close to screen's center (it's not time but just counter)
    @State private var inCenterTimeCount = 0.0
    // biggest card in current moment (maybe can be replaced with centeredelement...)
    @State private var biggestCard: ElementWrapper<Model>?
    // this element used to reset scroll's position
    @State private var resetItem: ElementWrapper<Model>?
    // scrolls toggle
    @State private var scrollAppearance = true
    // for Navigation view (not used in this example)
    @State private var isFirstAppearance = true
    // Use animation or not
    @State var isAnimationNeeded = false
    // Allow user's interaction
    @State var allowUserInteraction = true

    // ScreenTouchObserver - helper to track user's interaction with screen
    // Not implemented in this example
    // I use it to handle long gestures, when user holds finger on screen and move it

    @Binding private var items: [Model]

    private var content: (_ item: Model) -> Content

    public init(
        items: Binding<[Model]>,
        content: @escaping (_ item: Model) -> Content
    ) {
        self._items = items
        self.content = content
    }

    public var body: some View {
        GeometryReader { scrollGeometry in
            let screenCenterX = scrollGeometry.frame(in: .global).midX
            let _ = setScroll(geometry: scrollGeometry.frame(in: .global))
            ZStack {
                // Foreground scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { reader in
                        LazyHStack(alignment: .center, spacing: spacing) {
                            ForEach($elementsToShow, id: \.self) { item in
                                GeometryReader { cardGeometry in
                                    let cardCenterX = cardGeometry.frame(in: .global).midX
                                    let cardOffset = abs(cardCenterX - screenCenterX)
                                    let scaleNumber = calculateScale(for: cardOffset)
                                    let _ = scrollAppearance
                                    ? ()
                                    : handleItemAlignment(for: cardOffset, and: item.wrappedValue)
                                    content(item.wrappedValue.element)
                                        .onDisappear {
                                            onDisappear(item.wrappedValue)
                                        }
                                        .scaleEffect(CGSize(width: scaleNumber, height: scaleNumber))
                                        .animation(.easeInOut(duration: 0.05), value: scaleNumber)
                                }
                                .frame(width: cellSize.width)
                            }
                        }
                        .onChange(of: centeredElement) { element in
                            guard let element, !scrollAppearance else { return }
                            resetItem = nil
                            withAnimation(.easeOut) {
                                reader.scrollTo(element, anchor: .center)
                            }
                            resetScroll(if: timeToReset, to: element)
                        }
                        .onChange(of: slowCenteredElement) { newSlowElement in
                            guard let newSlowElement, !scrollAppearance else { return }
                            withAnimation(.easeOut) {
                                reader.scrollTo(newSlowElement, anchor: .center)
                            }
                        }
                        .onChange(of: resetItem) { newItem in
                            if let newItem, scrollAppearance {
                                reader.scrollTo(newItem, anchor: .center)
                            }
                        }
                    }
                }
                .allowsHitTesting(allowUserInteraction)
                .opacity(scrollAppearance ? 0 : 1)

                // Front scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { reader in
                        LazyHStack(alignment: .center, spacing: spacing) {
                            ForEach($elementsToShow, id: \.self) { item in
                                GeometryReader { cardGeometry in
                                    let cardCenterX = cardGeometry.frame(in: .global).midX
                                    let cardOffset = abs(cardCenterX - screenCenterX)
                                    let scaleNumber = calculateScale(for: cardOffset)
                                    let _ = scrollAppearance
                                    ? handleItemAlignment(for: cardOffset, and: item.wrappedValue)
                                    : ()
                                    content(item.wrappedValue.element)
                                        .onDisappear {
                                            onDisappear(item.wrappedValue)
                                        }
                                        .scaleEffect(CGSize(width: scaleNumber, height: scaleNumber))
                                        .animation(.easeInOut(duration: 0.05), value: scaleNumber)
                                }
                                .frame(width: cellSize.width)
                            }
                        }
                        .onChange(of: centeredElement) { element in
                            guard  let element, scrollAppearance else { return }
                            resetItem = nil
                            if isAnimationNeeded {
                                withAnimation(.easeOut) {
                                    reader.scrollTo(element, anchor: .center)
                                }
                            } else {
                                reader.scrollTo(element, anchor: .center)
                                isAnimationNeeded = true
                            }
                            resetScroll(if: timeToReset, to: element)
                        }
                        .onChange(of: slowCenteredElement) { newSlowElement in
                            guard let newSlowElement, scrollAppearance else { return }
                            withAnimation(.easeOut) {
                                reader.scrollTo(newSlowElement, anchor: .center)
                            }
                        }
                        .onChange(of: resetItem) { newItem in
                            if let newItem, !scrollAppearance {
                                reader.scrollTo(newItem, anchor: .center)
                            }
                        }
                    }
                }
                .allowsHitTesting(allowUserInteraction)
                .opacity(scrollAppearance ? 1 : 0)
            }
            .onAppear {
                guard isFirstAppearance else { return }
                isFirstAppearance = false
                items.isEmpty ? () : convert(items)
            }
            .onChange(of: items) { newItems in
                newItems.isEmpty ? () : convert(items)
            }
        }
        .frame(height: cellSize.height)
    }

    private func handleItemAlignment(for offset: CGFloat, and item: ElementWrapper<Model>) {
        guard abs(offset) < 200 else { return }
        DispatchQueue.main.async {
            if biggestCard != item {
                biggestCard = item
                inCenterTimeCount = 0.0
                centeredElement = nil
            } else {
//                if ScreenTouchObserver.shared.touchDidEnded {
                inCenterTimeCount += 1
                if inCenterTimeCount > 10 {
                    centeredElement = item
                }
//                }
            }
        }

//        ScreenTouchObserver.shared.onChange = { state, velocity, count, touchPoint in
//            guard
//                scrollRect.hasPointInside(touchPoint, isPortrait: InterfaceUtils.isPortrait),
//                isVisible
//            else {
//                return
//            }
//            handleSlowScroll(state: state, velocity: velocity.x, count: count)
//        }
    }

    // this method handles long touch gestures (dot used in this example)
    private func handleSlowScroll(state: UIGestureRecognizer.State, velocity: Double, count: Int) {
        if state == .ended, count > 10 {
            let positionBig = biggestCard?.position ?? 0
            var position = 0

            if velocity == 0 {
                position = positionBig
            } else if velocity > 0 {
                position = positionBig - 1
            } else if velocity < 0 {
                position = positionBig + 1
            }

            let element = elementsToShow[safe: position]
            slowCenteredElement = element
        } else {
            slowCenteredElement = nil
        }
    }

    private func onDisappear(_ item: ElementWrapper<Model>) {
        guard let element = firstElement?.element, element == item.element else { return }
        self.centeredElement = nil
        self.firstElementDisappearCount += 1
        if self.firstElementDisappearCount > 5 {
            self.timeToReset = true
        }
    }

    private func resetScroll(if timeToReset: Bool, to item: ElementWrapper<Model>) {
        guard timeToReset else { return }
        self.allowUserInteraction = false
        self.timeToReset = false
        let filtered = elementsToShow.filter { $0.element == item.element }.map { $0.position }
        let filteredCount = filtered.count
        let midIndex = Int(filteredCount / 2) - 1
        let newIndex = filtered[safe: midIndex]
        firstElementDisappearCount = 0
        if let item = elementsToShow.first(where: { $0.position == newIndex }) {
            resetItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.allowUserInteraction = true
                self.scrollAppearance.toggle()
            }
        }
    }

    private func convert(_ original: [Model]) {
        let first = original.first
        var indexesOfFirstElement: [Int] = []
        var result: [ElementWrapper<Model>] = []
        var number = 0
        for _ in 0...15 {
            original.forEach { originalElement in
                let wrapped = ElementWrapper<Model>(position: number, element: originalElement)
                result.append(wrapped)
                if let first, first == originalElement {
                    indexesOfFirstElement.append(number)
                }
                number += 1
            }
        }

        let middleIndexPosition = Int(indexesOfFirstElement.count / 2)
        let middleIndex = indexesOfFirstElement[safe: middleIndexPosition] ?? 0
        let middleElement = result[safe: middleIndex]

        self.elementsToShow = result
        self.firstElement = middleElement
        self.centeredElement = middleElement
        self.biggestCard = middleElement
    }

    private func calculateScale(for offset: CGFloat) -> Double {
        // Минимальное значение, для scale карточки
        let cardMinimumScale = 0.8
        // Величина отступа центра карточки от центра экрана, на протяжении которой на карточку действует эффект зума
        let zoomTriggerValue = triggerWidth
        // если отступ вышел за границу действия области зума, то просто возвращаем значение для уменьшенной карточки
        guard abs(offset) <= zoomTriggerValue else { return cardMinimumScale }
        // Один процент от оригинального диапазона зумирования
        let originalRangeOnePercent = zoomTriggerValue / 100
        // На сколько сдвинута карточка в процентах от оригинального диапазона зумирования
        let originalOffsetInPercents = offset / originalRangeOnePercent

        // Теперь будем считать масштаб уменьшения карточки
        // чем больше originalOffsetInPercents тем меньше сама карточка и наоборот
        // 0 - 200 -> 1.0 - 0.9

        // Высчитываем абсолютную величину нового диапазона
        let scaledRange = 1 - cardMinimumScale
        // Считаем 1 процент от нового диапазона
        let scaledRangeOnePercent = scaledRange / 100
        // Считаем размер изменения нового диапазона в зависимости на сколько процентов прокручен оригинальный диапазон
        let scaledOffsetInPercent = scaledRangeOnePercent * originalOffsetInPercents
        // Тк при увеличении смещения размер уменьшается, то вычитаем из 1
        let result = 1 - scaledOffsetInPercent
        return result
    }

    private func setScroll(geometry: CGRect) {
        DispatchQueue.main.async {
            self.scrollRect = geometry
        }
    }
}
