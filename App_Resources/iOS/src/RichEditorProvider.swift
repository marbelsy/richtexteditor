//
//  DemoEditorScreen.swift
//  Demo
//
//  Created by Daniel Saidi on 2024-03-04.
//  Simplified: 2025-10-20 – Bullet/Number list + auto-continue, double-Enter exit,
//              broken-prefix normalization, typing-attributes syncing, and empty-paragraph support
//

import SwiftUI
import RichTextKit
import UIKit

// MARK: - RichEditor

struct RichEditor: View {

    @ObservedObject var data: RichEditorData
    @StateObject var context = RichTextContext()


    var exposedContext: RichTextContext { context }

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            RichTextFormat.Toolbar(context: context)
            #endif

            #if os(iOS)
            if data.showToolbar {
                HStack(spacing: 16) {
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            #endif

            RichTextEditor(
                text: Binding(
                    get: { data.nonOptionalText },
                    set: { newValue in
                        data.text = newValue
                        data.onEvent?(["textChange": newValue])
                    }
                ),
                context: context
            ) { tv in

                // Capture the underlying UITextView so toggles & observers can use it
                data.textView = tv as? UITextView
                tv.textContentInset = CGSize(width: data.insetWidth, height: data.insetHeight)
            }

            #if os(iOS)
            if data.showToolbar {
                RichTextKeyboardToolbar(
                    context: context,
                    leadingButtons: { $0 },
                    trailingButtons: { $0 },
                    formatSheet: { $0 }
                )
            }
            #endif
        }
        .inspector(isPresented: $data.isInspectorPresented) {
            RichTextFormat.Sidebar(context: context)
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
        .focusedValue(\.richTextContext, context)
        .toolbarRole(.automatic)
        .richTextFormatSheetConfig(.init(colorPickers: colorPickers))
        .richTextFormatSidebarConfig(.init(colorPickers: colorPickers, fontPicker: isMac))
        .richTextFormatToolbarConfig(.init(colorPickers: []))
    }
}

// MARK: - Config helpers

private extension RichEditor {
    var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
    var colorPickers: [RichTextColor] { [.foreground, .background] }
}

// MARK: - Data Model

class RichEditorData: ObservableObject {
    @Published var text: NSAttributedString?
    @Published var isInspectorPresented = false
    @Published var insetWidth: CGFloat = 60
    @Published var insetHeight: CGFloat = 30
    @Published var showToolbar: Bool = false

    weak var textView: UITextView?

    var nonOptionalText: NSAttributedString { text ?? NSAttributedString(string: "") }

    @Published var modifiers = NSArray()
    var onEvent: ((NSDictionary) -> Void)?
}

// MARK: - SwiftUI Provider (NativeScript bridge)

@available(iOS 17.0, *)
@objc open class RichEditorProvider: UIViewController, SwiftUIProvider {

    private var props = RichEditorData()
    private var swiftUI: RichEditor?

    var context: RichTextContext? { swiftUI?.exposedContext }

    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    required public init() { super.init(nibName: nil, bundle: nil) }

    public override func viewDidLoad() {
        super.viewDidLoad()
        props.onEvent = { data in self.onEvent?(data) }
    }

    func updateData(data: NSDictionary) {
        let enumerator = data.keyEnumerator()
        while let k = enumerator.nextObject() {
            let key = k as! String
            let v = data.object(forKey: key)
            guard let v = v else { continue }

            switch key {
            case "text":
                props.text = NSAttributedString(string: v as! String, attributes: [:])
            case "isInspectorPresented":
                props.isInspectorPresented = v as! Bool
            case "insetWidth":
                props.insetWidth = v as! CGFloat
            case "insetHeight":
                props.insetHeight = v as! CGFloat
            case "showToolbar":
                props.showToolbar = v as! Bool
            default: break
            }
        }

        if self.swiftUI == nil {
            swiftUI = RichEditor(data: props)
            setupSwiftUIView(content: swiftUI)
        } else {
            self.swiftUI?.data = props
        }
    }

    var onEvent: ((NSDictionary) -> ())?

    // MARK: Text Formatting

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
