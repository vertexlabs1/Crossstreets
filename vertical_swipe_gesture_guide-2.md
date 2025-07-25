Vertical Swipe Gestures in iOS (Swift) – A Comprehensive Developer Guide

## Introduction

Vertical swipe gestures (swipe up to reveal a detail view, swipe down to dismiss) can enrich iPhone app UIs by providing intuitive, gesture-driven navigation. Implementing these gestures requires carefully handling touch events, animating views or transitions, and managing user experience details like haptics and accessibility. This guide covers two approaches – UIKit and SwiftUI – and explores techniques ranging from basic gesture recognizers to advanced interactive transitions. We’ll discuss how to recognize vertical swipes (using `UISwipeGestureRecognizer` and `UIPanGestureRecognizer` in UIKit, and `DragGesture` in SwiftUI), animate view transitions during swipes, use interactive modal transitions or custom presentation controllers, integrate haptic feedback, ensure accessibility (VoiceOver cues, Dynamic Type), and handle gesture conflicts (e.g. with scroll views). Code examples (in Swift) and best-practice architecture suggestions are provided throughout.

**Note:** Examples assume an iPhone-only context.

## UIKit Implementation

### Recognizing Vertical Swipes

**UISwipeGestureRecognizer:**

```swift
let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
swipeUp.direction = .up
view.addGestureRecognizer(swipeUp)
```

**UIPanGestureRecognizer:**

```swift
let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
view.addGestureRecognizer(pan)

@objc func handlePan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: view)
    switch gesture.state {
    case .changed:
        if translation.y > 0 {
            detailView.frame.origin.y = translation.y
        }
    case .ended:
        let velocity = gesture.velocity(in: view).y
        if translation.y > 200 || velocity > 1000 {
            dismissDetailViewAnimated()
        } else {
            UIView.animate(withDuration: 0.2) {
                self.detailView.frame.origin.y = 0
            }
        }
    default: break
    }
}
```

### Animating Transitions

```swift
UIView.animate(withDuration: 0.3) {
    detailView.frame.origin.y = 0 // to open
}

UIView.animate(withDuration: 0.3, animations: {
    detailView.frame.origin.y = self.view.bounds.height // to dismiss
}, completion: { _ in
    detailView.removeFromSuperview()
})
```

### Interactive View Controller Transitions

```swift
class Interactor: UIPercentDrivenInteractiveTransition {
    var hasStarted = false
    var shouldFinish = false
}

@IBAction func handleGesture(_ sender: UIPanGestureRecognizer) {
    let translation = sender.translation(in: view)
    let progress = max(0, min(translation.y / view.bounds.height, 1))
    switch sender.state {
    case .began:
        interactor.hasStarted = true
        dismiss(animated: true, completion: nil)
    case .changed:
        interactor.shouldFinish = progress > 0.3
        interactor.update(progress)
    case .ended:
        interactor.hasStarted = false
        interactor.shouldFinish ? interactor.finish() : interactor.cancel()
    case .cancelled:
        interactor.hasStarted = false
        interactor.cancel()
    default: break
    }
}
```

### Sheet-Style Modal Presentation (iOS 15+)

```swift
if let sheet = detailVC.sheetPresentationController {
    sheet.detents = [.medium(), .large()]
    sheet.prefersGrabberVisible = true
    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
}
```

### Haptic Feedback

```swift
let feedback = UIImpactFeedbackGenerator(style: .medium)
feedback.prepare()
feedback.impactOccurred()
```

### Gesture Conflict Handling

```swift
func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
    return scrollView.contentOffset.y <= 0
}
```

## SwiftUI Implementation

### Using DragGesture

```swift
struct DetailView: View {
    @Binding var show: Bool
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack {
            Text("Drag me down to dismiss").padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        withAnimation {
                            dragOffset = UIScreen.main.bounds.height
                            show = false
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } else {
                        withAnimation { dragOffset = 0 }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
        )
    }
}
```

### ViewModifier for Reuse

```swift
struct SwipeToDismiss: ViewModifier {
    @Binding var isPresented: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        if val.translation.height > 0 {
                            offset = val.translation.height
                        }
                    }
                    .onEnded { val in
                        if val.translation.height > 100 {
                            withAnimation {
                                offset = UIScreen.main.bounds.height
                                isPresented = false
                            }
                        } else {
                            withAnimation { offset = 0 }
                        }
                    }
            )
    }
}

extension View {
    func swipeToDismiss(isPresented: Binding<Bool>) -> some View {
        self.modifier(SwipeToDismiss(isPresented: isPresented))
    }
}
```

### Sheet Presentation with Detents

```swift
.sheet(isPresented: $showDetail) {
    DetailView()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
```

### Accessibility in SwiftUI

```swift
.accessibilityAddTraits(.isModal)
.accessibilityAction(named: Text("Dismiss")) {
    showDetail = false
}
```

## Best Practices

- Abstract logic into reusable modifiers or delegates.
- Use visual cues (e.g., grabber) for gestures.
- Avoid hardcoded values; base thresholds on screen size.
- Test on real devices (haptics, gesture fluidity).
- Ensure fallbacks for accessibility users.

## Summary

Vertical swipe gestures can enhance UX when implemented carefully. UIKit offers deep control with custom transitions, while SwiftUI simplifies gesture handling with declarative state. Use built-in APIs when possible (e.g., `UISheetPresentationController`), and add haptic feedback and accessibility to make gestures inclusive and intuitive.

---

**Recommended Apple Documentation:**

- [UISwipeGestureRecognizer](https://developer.apple.com/documentation/uikit/uiswipegesturerecognizer)
- [UIPanGestureRecognizer](https://developer.apple.com/documentation/uikit/uipangesturerecognizer)
- [UIViewControllerTransitioningDelegate](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioningdelegate)
- [UIImpactFeedbackGenerator](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator)
- [UISheetPresentationController](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller)
- [SwiftUI DragGesture](https://developer.apple.com/documentation/swiftui/draggesture)
- [SwiftUI Sheet Presentation](https://developer.apple.com/documentation/swiftui/view/sheet\(isPresented\:content:\))

