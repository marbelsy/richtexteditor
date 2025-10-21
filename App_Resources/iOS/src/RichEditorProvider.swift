//
//  DemoEditorScreen.swift
//

import RichTextKit
import SwiftUI
import UIKit

// MARK: - SwiftUI Editor

struct RichEditor: View {
    @ObservedObject var data: RichEditorData

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            RichTextFormat.Toolbar(context: data.context)
            #endif

            RichTextEditor(
                text: Binding(
                    get: { data.nonOptionalText },
                    set: { newValue in
                        data.text = newValue
                        data.onEvent?(["textChange": newValue])
                    }
                ),
                context: data.context
            ) { nativeView in
                nativeView.textContentInset = CGSize(width: data.insetWidth, height: data.insetHeight)
                #if os(iOS)
                if let tv = nativeView as? UITextView {
                    data.textView = tv
                    // Install proxy + brief guard (RichTextKit 1.2 may re-assign the delegate)
                    DispatchQueue.main.async {
                        installDelegateProxyIfNeeded(data: data, textView: tv)
                        startDelegateGuard(for: data, textView: tv, durationFrames: 30) // ~0.5s @60fps
                    }
                }
                #endif
            }

            #if os(iOS)
            if data.showToolbar {
                RichTextKeyboardToolbar(
                    context: data.context,
                    leadingButtons: { $0 },
                    trailingButtons: { $0 },
                    formatSheet: { $0 }
                )
            }
            #endif
        }
        .inspector(isPresented: $data.isInspectorPresented) {
            RichTextFormat.Sidebar(context: data.context)
                #if os(macOS)
                .inspectorColumnWidth(min: 200, ideal: 200, max: 315)
                #endif
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $data.isInspectorPresented) {
                    Image.richTextFormatBrush
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .frame(minWidth: 500)
        .focusedValue(\.richTextContext, data.context)
        .toolbarRole(.automatic)
        .richTextFormatSheetConfig(.init(colorPickers: [.foreground, .background]))
        .richTextFormatSidebarConfig(.init(colorPickers: [.foreground, .background], fontPicker: isMac))
        .richTextFormatToolbarConfig(.init(colorPickers: []))
    }

    private var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}

// MARK: - View Model

class RichEditorData: NSObject, ObservableObject {
    @Published var text: NSAttributedString?
    @Published var isInspectorPresented = false
    @Published var insetWidth: CGFloat = 60
    @Published var insetHeight: CGFloat = 30
    @Published var showToolbar: Bool = false

    /// RichTextKit context (used by the editor UI)
    let context = RichTextContext()

    /// Underlying native text view (iOS)
    weak var textView: UITextView?

    /// Strong ref to the delegate proxy so it doesn't deallocate
    var delegateProxy: TextViewDelegateProxy?

    /// Short-lived guard that re-asserts the proxy if RichTextKit replaces it
    var delegateGuardLink: CADisplayLink?

    var nonOptionalText: NSAttributedString {
        text ?? NSAttributedString(string: "")
    }

    @Published var modifiers = NSArray()
    var onEvent: ((NSDictionary) -> Void)?
}

// MARK: - UITextViewDelegate proxy
//  - continues/ends lists on Enter (existing behavior)
//  - protects list markers (unordered/ordered) from direct deletion
//  - if backspace at marker boundary -> delete whole line & move caret to prev line end

class TextViewDelegateProxy: NSObject, UITextViewDelegate {
    weak var primary: UITextViewDelegate?
    weak var handler: RichEditorData?

    init(primary: UITextViewDelegate?, handler: RichEditorData) {
        self.primary = primary
        self.handler = handler
    }
    
    private func lineIsEmptyAfterMarker(textView: UITextView,
                                        info: (line: NSRange, markerStart: Int, markerEnd: Int,
                                               previousLine: (line: NSRange, contentsEnd: Int)?)) -> Bool {
        let ns = (textView.text ?? "") as NSString
        let lineStr = ns.substring(with: info.line) as NSString

        let afterMarkerOffset = info.markerEnd - info.line.location
        if afterMarkerOffset >= lineStr.length { return true }

        let afterMarker = lineStr.substring(from: afterMarkerOffset)
        return afterMarker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func textView(_ textView: UITextView,
                  shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {

        // --- Special handling: backspace cases ---
        if text.isEmpty && range.length == 1 {

            // Use the caret position (after deletion): caretLoc = range.location + range.length
            let caretLoc = range.location + range.length

            if let info = markerInfoAt(textView: textView, caretLocation: caretLoc) {

                // Case A: caret was right AFTER the marker (markerEnd) → first backspace behavior (you already had this)
                if caretLoc == info.markerEnd {
                    if lineIsEmptyAfterMarker(textView: textView, info: info) {
                        textView.textStorage.beginEditing()
                        textView.textStorage.replaceCharacters(
                            in: NSRange(location: info.markerStart, length: info.markerEnd - info.markerStart),
                            with: ""
                        )
                        textView.textStorage.endEditing()
                        // Move to true start so NEXT backspace merges lines
                        textView.selectedRange = NSRange(location: info.line.location, length: 0)
                        return false
                    }
                    // Block deleting into the marker when there is content after it
                    return false
                }

                // Case B: caret was right AT the marker start → second backspace
                // Instead of deleting the char BEFORE the marker, remove the marker itself
                if caretLoc == info.markerStart && lineIsEmptyAfterMarker(textView: textView, info: info) {
                    textView.textStorage.beginEditing()
                    textView.textStorage.replaceCharacters(
                        in: NSRange(location: info.markerStart, length: info.markerEnd - info.markerStart),
                        with: ""
                    )
                    textView.textStorage.endEditing()
                    // Move to true start; a subsequent backspace will merge with previous line
                    textView.selectedRange = NSRange(location: info.line.location, length: 0)
                    return false
                }
            }
        }
        // --- end backspace handling ---

        // Prevent edits that start inside the list marker itself (keep marker uneditable)
        if let info = markerInfoAt(textView: textView, caretLocation: range.location) {
            let startsInsideMarker = range.location < info.markerEnd && range.location >= info.markerStart
            if startsInsideMarker { return false }
        }

        // Enter handling for lists (unchanged)
        if handleEnterForLists(textView, range: range, text: text) == false {
            return false
        }

        if let result = primary?.textView?(textView, shouldChangeTextIn: range, replacementText: text) {
            return result
        }
        return true
    }


    func textViewDidChangeSelection(_ textView: UITextView) {
        if let info = markerInfoAt(textView: textView, caretLocation: textView.selectedRange.location) {
            var sel = textView.selectedRange
            // Allow caret to sit exactly at markerStart so the user can backspace the char BEFORE the bullet.
            if sel.length == 0, sel.location < info.markerStart {
                sel.location = info.markerStart
                textView.selectedRange = sel
            }
        }
        (primary as? UITextViewDelegate)?.textViewDidChangeSelection?(textView)
    }

    // Forward all other delegate callbacks to RichTextKit's original delegate.
    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return (primary as AnyObject?)?.responds?(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        primary
    }

    // MARK: Enter handling (unchanged behavior, just attribute-safe insert)
    private func handleEnterForLists(_ textView: UITextView, range: NSRange, text: String) -> Bool? {
        guard text == "\n" else { return nil }

        let ns = (textView.text ?? "") as NSString
        let line = currentLineRange(in: ns, around: range.location)
        let lineStr = ns.substring(with: line)

        // Determine indentation
        let leadingWSCount = lineStr.prefix { $0 == " " || $0 == "\t" }.count
        let afterWS = String(lineStr.dropFirst(leadingWSCount))

        // Patterns
        let isUnordered = afterWS.hasPrefix("• ") || afterWS.hasPrefix("- ") || afterWS.hasPrefix("* ")
        let orderedMatch = orderedHeadMatch(afterWS) // returns (num, headLength)
        let isOrdered = orderedMatch != nil

        // Not a list line → let default behavior happen
        if !isUnordered && !isOrdered { return nil }

        // Text after the marker on the current line
        let afterMarker = {
            if isUnordered { return String(afterWS.dropFirst(2)) } // drop "• "
            let headLen = orderedMatch!.headLength
            return String(afterWS.dropFirst(headLen))              // drop "N. "
        }()

        // If empty after the marker AND caret is at end → EXIT list (double Enter)
        let caretAtLineEnd = range.location >= line.location + line.length
        if afterMarker.trimmingCharacters(in: .whitespaces).isEmpty && caretAtLineEnd {
            let markerLoc = line.location + leadingWSCount
            let markerLen = isUnordered ? 2 : orderedMatch!.headLength
            textView.textStorage.beginEditing()
            textView.textStorage.replaceCharacters(in: NSRange(location: markerLoc, length: markerLen), with: "")
            textView.textStorage.endEditing()
            return nil // allow normal newline insertion
        }

        // CONTINUE list on next line (preserve attributes at insertion point)
        let indent = String(repeating: " ", count: leadingWSCount)
        let insertString: String = {
            if isUnordered { return "\n\(indent)• " }
            let nextNum = orderedMatch!.number + 1
            return "\n\(indent)\(nextNum). "
        }()

        let attrs = attributesAt(textView: textView, index: range.location)
        let insert = NSAttributedString(string: insertString, attributes: attrs)

        textView.textStorage.beginEditing()
        textView.textStorage.replaceCharacters(in: range, with: insert)
        textView.textStorage.endEditing()
        textView.selectedRange = NSRange(location: range.location + insert.length, length: 0)
        return false // handled here
    }

    // MARK: Utilities for line ranges & markers

    private func currentLineRange(in text: NSString, around location: Int) -> NSRange {
        var start = 0, end = 0, contentsEnd = 0
        let loc = max(0, min(location, text.length))
        text.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: loc, length: 0))
        return NSRange(location: start, length: end - start)
    }

    private func previousLineRange(in text: NSString, before location: Int) -> (line: NSRange, contentsEnd: Int)? {
        let curr = currentLineRange(in: text, around: location)
        guard curr.location > 0 else { return nil }
        var start = 0, end = 0, contentsEnd = 0
        text.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: max(0, curr.location - 1), length: 0))
        let line = NSRange(location: start, length: end - start)
        return (line, contentsEnd)
    }

    /// Detects ordered marker like "12. " or "12) " at the start of the string.
    /// Returns (number, headLength) where headLength is the length of "12. ".
    private func orderedHeadMatch(_ s: String) -> (number: Int, headLength: Int)? {
        let ns = s as NSString
        let rx = try! NSRegularExpression(pattern: #"^(\d+)([.)])\s"#)
        guard let m = rx.firstMatch(in: s, options: [], range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        let numStr = ns.substring(with: m.range(at: 1))
        let headLen = m.range.location == NSNotFound ? 0 : m.range.length
        return (Int(numStr) ?? 0, headLen)
    }

    /// Info about the list marker (if any) at the caret line.
    private func markerInfoAt(textView: UITextView, caretLocation: Int)
        -> (line: NSRange, markerStart: Int, markerEnd: Int, previousLine: (line: NSRange, contentsEnd: Int)?)? {

        let ns = (textView.text ?? "") as NSString
        let line = currentLineRange(in: ns, around: caretLocation)
        let lineStr = ns.substring(with: line)

        // indentation
        let leadingWSCount = lineStr.prefix { $0 == " " || $0 == "\t" }.count
        let afterWS = String(lineStr.dropFirst(leadingWSCount))
        let markerStart = line.location + leadingWSCount

        // unordered
        if afterWS.hasPrefix("• ") || afterWS.hasPrefix("- ") || afterWS.hasPrefix("* ") {
            let markerEnd = markerStart + 2
            return (line, markerStart, markerEnd, previousLineRange(in: ns, before: line.location))
        }
        // ordered
        if let m = orderedHeadMatch(afterWS) {
            let markerEnd = markerStart + m.headLength
            return (line, markerStart, markerEnd, previousLineRange(in: ns, before: line.location))
        }
        return nil
    }

    /// Delete the current line entirely and move caret to end of previous line.
    private func deleteLineAndJumpUp(_ textView: UITextView, currentLine: NSRange,
                                     previousLineInfo: (line: NSRange, contentsEnd: Int)?) {
        let ns = (textView.text ?? "") as NSString
        let hasPrev = previousLineInfo != nil
        textView.textStorage.beginEditing()

        if hasPrev {
            // Remove from the previous line's end to the end of the current line,
            // effectively deleting the newline + the whole current line.
            let prevEnd = previousLineInfo!.contentsEnd
            let deleteRange = NSRange(location: prevEnd, length: (currentLine.location + currentLine.length) - prevEnd)
            textView.textStorage.replaceCharacters(in: deleteRange, with: "")
            textView.textStorage.endEditing()
            textView.selectedRange = NSRange(location: prevEnd, length: 0)
        } else {
            // No previous line: clear current line content
            textView.textStorage.replaceCharacters(in: currentLine, with: "")
            textView.textStorage.endEditing()
            textView.selectedRange = NSRange(location: 0, length: 0)
        }
    }
}

// MARK: - Provider (bridged to NativeScript)

@available(iOS 17.0, *)
@objc
open class RichEditorProvider: UIViewController, SwiftUIProvider {
    private var props = RichEditorData()
    private var swiftUI: RichEditor?

    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    required public init() { super.init(nibName: nil, bundle: nil) }

    public override func viewDidLoad() {
        super.viewDidLoad()
        props.onEvent = { [weak self] data in self?.onEvent?(data) }
    }

    // MARK: SwiftUIProvider

    func updateData(data: NSDictionary) {
        let enumerator = data.keyEnumerator()
        while let k = enumerator.nextObject() {
            let key = k as! String
            let v = data.object(forKey: key)
            guard let value = v else { continue }

            switch key {
            case "text":
                if let s = value as? String {
                    props.text = NSAttributedString(string: s, attributes: [:])
                }
            case "isInspectorPresented":
                if let b = value as? Bool { props.isInspectorPresented = b }
            case "insetWidth":
                if let w = value as? CGFloat { props.insetWidth = w }
            case "insetHeight":
                if let h = value as? CGFloat { props.insetHeight = h }
            case "showToolbar":
                if let b = value as? Bool { props.showToolbar = b }
            default:
                break
            }
        }

        if swiftUI == nil {
            swiftUI = RichEditor(data: props)
            setupSwiftUIView(content: swiftUI)
        } else {
            swiftUI?.data = props
        }

        // Ensure the proxy is installed (and guarded briefly)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let tv = self.props.textView else { return }
            installDelegateProxyIfNeeded(data: self.props, textView: tv)
            startDelegateGuard(for: self.props, textView: tv, durationFrames: 30)
        }
    }

    /// Send data to NativeScript
    var onEvent: ((NSDictionary) -> ())?

    // MARK: Programmatic formatting API (v1.2-safe)

    /// Toggle **bold** on current selection; caret-only updates typing attributes.
    @objc public func toggleBold() {
        DispatchQueue.main.async { [weak self] in
            guard let tv = self?.props.textView else { return }
            let sel = tv.selectedRange

            if sel.length == 0 {
                let current = (tv.typingAttributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
                let desc = current.fontDescriptor
                let isBold = desc.symbolicTraits.contains(.traitBold)
                let newTraits: UIFontDescriptor.SymbolicTraits = isBold
                    ? desc.symbolicTraits.subtracting(.traitBold)
                    : desc.symbolicTraits.union(.traitBold)
                let newDesc = desc.withSymbolicTraits(newTraits) ?? desc
                let newFont = UIFont(descriptor: newDesc, size: current.pointSize)
                var attrs = tv.typingAttributes
                attrs[.font] = newFont
                tv.typingAttributes = attrs
                return
            }

            tv.textStorage.beginEditing()
            tv.textStorage.enumerateAttribute(.font, in: sel, options: []) { value, range, _ in
                let base = (value as? UIFont) ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
                let desc = base.fontDescriptor
                let isBold = desc.symbolicTraits.contains(.traitBold)
                let newTraits: UIFontDescriptor.SymbolicTraits = isBold
                    ? desc.symbolicTraits.subtracting(.traitBold)
                    : desc.symbolicTraits.union(.traitBold)
                let newDesc = desc.withSymbolicTraits(newTraits) ?? desc
                let newFont = UIFont(descriptor: newDesc, size: base.pointSize)
                tv.textStorage.addAttribute(.font, value: newFont, range: range)
            }
            tv.textStorage.endEditing()
        }
    }

    /// Toggle unordered list (•) for selected lines. Removes ordered markers first if present.
    @objc public func toggleUnorderedList() {
        DispatchQueue.main.async { [weak self] in
            guard let tv = self?.props.textView else { return }
            self?.toggleBulletList(in: tv)
        }
    }

    /// Toggle ordered list (1.) for selected lines. Removes unordered markers first if present.
    @objc public func toggleOrderedList() {
        DispatchQueue.main.async { [weak self] in
            guard let tv = self?.props.textView else { return }
            self?.toggleNumberedList(in: tv)
        }
    }

    /// Apply a link to the current selection (or set typing attributes if caret-only).
    @objc public func setLink(_ urlString: String) {
        DispatchQueue.main.async { [weak self] in
            guard let tv = self?.props.textView, let url = URL(string: urlString) else { return }
            let range = tv.selectedRange
            if range.length == 0 {
                var attrs = tv.typingAttributes
                attrs[.link] = url
                tv.typingAttributes = attrs
            } else {
                tv.textStorage.beginEditing()
                tv.textStorage.addAttribute(.link, value: url, range: range)
                tv.textStorage.endEditing()
            }
        }
    }

    /// Remove link attribute from the current selection (or typing attributes if caret-only).
    @objc public func removeLink() {
        DispatchQueue.main.async { [weak self] in
            guard let tv = self?.props.textView else { return }
            let range = tv.selectedRange
            if range.length == 0 {
                var attrs = tv.typingAttributes
                attrs.removeValue(forKey: .link)
                tv.typingAttributes = attrs
            } else {
                tv.textStorage.beginEditing()
                tv.textStorage.removeAttribute(.link, range: range)
                tv.textStorage.endEditing()
            }
        }
    }
}

// MARK: - List toggles (index-safe, preserves attributes, cleans old markers)

@available(iOS 17.0, *)
extension RichEditorProvider {

    private func lineRanges(in text: NSString, covering selection: NSRange) -> [NSRange] {
        var ranges: [NSRange] = []
        var start = 0, end = 0, contentsEnd = 0
        let full = NSRange(location: 0, length: text.length)
        let sel = NSIntersectionRange(selection, full)

        var idx = 0
        while idx < text.length {
            text.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: idx, length: 0))
            let lineRange = NSRange(location: start, length: end - start)
            if NSIntersectionRange(lineRange, sel).length > 0 {
                ranges.append(lineRange)
            }
            idx = end
        }
        if ranges.isEmpty, text.length > 0 {
            text.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: max(0, min(sel.location, text.length - 1)), length: 0))
            ranges.append(NSRange(location: start, length: end - start))
        }
        return ranges
    }

    /// Helper: attributes at index (falls back to typingAttributes if needed)
    private func attributesAt(textView: UITextView, index: Int) -> [NSAttributedString.Key: Any] {
        let safeIndex = max(0, min(index, textView.textStorage.length > 0 ? textView.textStorage.length - 1 : 0))
        if textView.textStorage.length > 0 {
            return textView.textStorage.attributes(at: safeIndex, effectiveRange: nil)
        } else {
            return textView.typingAttributes
        }
    }

    /// Toggle unordered list (•) per line, bottom-to-top; preserves font/attrs.
    fileprivate func toggleBulletList(in textView: UITextView) {
        guard let _ = textView.text else { return }
        let lines = lineRanges(in: (textView.text! as NSString), covering: textView.selectedRange)

        let unorderedRx = try! NSRegularExpression(pattern: #"^(\s*)([•\-\*])\s+"#) // group 1 = indent
        let orderedRx   = try! NSRegularExpression(pattern: #"^(\s*)\d+[.)]\s+"#)

        // Evaluate "all bulleted" once from current text
        let allBulleted = lines.allSatisfy { r in
            let s = (textView.text as NSString?)?.substring(with: r) ?? ""
            return unorderedRx.firstMatch(in: s, options: [], range: NSRange(location: 0, length: (s as NSString).length)) != nil
        }

        textView.textStorage.beginEditing(); defer { textView.textStorage.endEditing() }

        for r in lines.reversed() {
            let current = (textView.text ?? "") as NSString
            let line = current.substring(with: r) as NSString

            // Current indentation
            let wsMatch = try! NSRegularExpression(pattern: #"^(\s*)"#)
                .firstMatch(in: line as String, options: [], range: NSRange(location: 0, length: line.length))
            let indentLen = wsMatch?.range(at: 1).length ?? 0
            let startLoc = r.location + indentLen

            if allBulleted {
                // Remove unordered marker if present
                if let m = unorderedRx.firstMatch(in: line as String, options: [], range: NSRange(location: 0, length: line.length)) {
                    let removeStart = r.location + m.range(at: 1).length
                    let removeLen = m.range(at: 0).length - m.range(at: 1).length
                    textView.textStorage.replaceCharacters(in: NSRange(location: removeStart, length: removeLen), with: "")
                }
            } else {
                // Strip ordered marker if present on this line
                if let m = orderedRx.firstMatch(in: line as String, options: [], range: NSRange(location: 0, length: line.length)) {
                    let removeStart = r.location + m.range(at: 1).length
                    let removeLen = m.range(at: 0).length - m.range(at: 1).length
                    textView.textStorage.replaceCharacters(in: NSRange(location: removeStart, length: removeLen), with: "")
                }
                // Insert bullet at current start (after indentation), preserving attributes
                let attrs = attributesAt(textView: textView, index: startLoc)
                let bullet = NSAttributedString(string: "• ", attributes: attrs)
                textView.textStorage.replaceCharacters(in: NSRange(location: startLoc, length: 0), with: bullet)
            }
        }
    }

    /// Toggle ordered list (1.) per line with safe indices; cleans existing bullets first; preserves attrs.
    fileprivate func toggleNumberedList(in textView: UITextView) {
        guard let _ = textView.text else { return }
        var lines = lineRanges(in: (textView.text! as NSString), covering: textView.selectedRange)

        let unorderedRx = try! NSRegularExpression(pattern: #"^(\s*)([•\-\*])\s+"#)
        let orderedRx   = try! NSRegularExpression(pattern: #"^(\s*)\d+[.)]\s+"#)

        // Determine once if all are already ordered
        let allNumbered = lines.allSatisfy { r in
            let s = (textView.text as NSString?)?.substring(with: r) ?? ""
            return orderedRx.firstMatch(in: s, options: [], range: NSRange(location: 0, length: (s as NSString).length)) != nil
        }

        textView.textStorage.beginEditing(); defer { textView.textStorage.endEditing() }

        if allNumbered {
            // Remove ordered markers bottom→top
            for r in lines.reversed() {
                let current = (textView.text ?? "") as NSString
                let line = current.substring(with: r) as NSString
                if let m = orderedRx.firstMatch(in: line as String, options: [], range: NSRange(location: 0, length: line.length)) {
                    let removeStart = r.location + m.range(at: 1).length
                    let removeLen = m.range(at: 0).length - m.range(at: 1).length
                    textView.textStorage.replaceCharacters(in: NSRange(location: removeStart, length: removeLen), with: "")
                }
            }
            return
        }

        // Assign numbers top→bottom now…
        let numbers: [String] = (0..<lines.count).map { "\($0 + 1). " }

        // …but apply edits bottom→top; on each line, recompute indentation then insert the preassigned number.
        for (idx, r) in lines.enumerated().reversed() {
            let current = (textView.text ?? "") as NSString
            let line = current.substring(with: r) as NSString

            // Remove unordered if present
            if let m = unorderedRx.firstMatch(in: line as String, options: [], range: NSRange(location: 0, length: line.length)) {
                let removeStart = r.location + m.range(at: 1).length
                let removeLen = m.range(at: 0).length - m.range(at: 1).length
                textView.textStorage.replaceCharacters(in: NSRange(location: removeStart, length: removeLen), with: "")
            }

            // Recompute indentation after possible removal
            let updated = (textView.text ?? "") as NSString
            let updatedLine = updated.substring(with: r) as NSString
            let wsMatch = try! NSRegularExpression(pattern: #"^(\s*)"#)
                .firstMatch(in: updatedLine as String, options: [], range: NSRange(location: 0, length: updatedLine.length))
            let indentLen = wsMatch?.range(at: 1).length ?? 0
            let startLoc = r.location + indentLen

            let attrs = attributesAt(textView: textView, index: startLoc)
            let num = NSAttributedString(string: numbers[idx], attributes: attrs)
            textView.textStorage.replaceCharacters(in: NSRange(location: startLoc, length: 0), with: num)
        }
    }
}

// MARK: - Shared helpers (single definitions)

fileprivate func attributesAt(textView: UITextView, index: Int) -> [NSAttributedString.Key: Any] {
    let storage = textView.textStorage
    let length = storage.length

    if length == 0 {
        return textView.typingAttributes
    }

    // If inserting at the very end, prefer current typingAttributes (keeps font/size consistent)
    if index >= length {
        return textView.typingAttributes.isEmpty
            ? storage.attributes(at: length - 1, effectiveRange: nil)
            : textView.typingAttributes
    }

    let clamped = max(0, min(index, length - 1))
    return storage.attributes(at: clamped, effectiveRange: nil)
}

private func installDelegateProxyIfNeeded(data: RichEditorData, textView: UITextView) {
    if let existing = data.delegateProxy, textView.delegate === existing { return }
    let primary = textView.delegate
    let proxy = TextViewDelegateProxy(primary: primary, handler: data)
    data.delegateProxy = proxy
    textView.delegate = proxy
}

private func startDelegateGuard(for data: RichEditorData, textView: UITextView, durationFrames: Int) {
    data.delegateGuardLink?.invalidate()
    var framesLeft = durationFrames
    let link = CADisplayLink(target: BlockTarget { [weak data, weak textView] in
        guard let data = data, let tv = textView else { return }
        if tv.delegate !== data.delegateProxy {
            installDelegateProxyIfNeeded(data: data, textView: tv)
        }
        framesLeft -= 1
        if framesLeft <= 0 {
            data.delegateGuardLink?.invalidate()
            data.delegateGuardLink = nil
        }
    }, selector: #selector(BlockTarget.invoke))
    link.add(to: .main, forMode: .common)
    data.delegateGuardLink = link
}

private class BlockTarget: NSObject {
    let block: () -> Void
    init(_ block: @escaping () -> Void) { self.block = block }
    @objc func invoke() { block() }
}
