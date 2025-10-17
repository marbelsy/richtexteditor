import { Utils } from "@nativescript/core";
import { registerSwiftUI, SwiftUI, UIDataDriver } from "@nativescript/swift-ui";
import { RichEditorData, RichEditorType } from "./common";

export class RichEditor extends SwiftUI implements RichEditorType {
  provider: RichEditorProvider;
  data: RichEditorData;

  constructor() {
    super();
    // make each usage unique so could use many throughout app is desired
    const swiftId = `richEditor-${crypto.randomUUID()}`;
    if (Utils.SDK_VERSION >= 17) {
      registerSwiftUI(swiftId, (view) => {
        this.provider = RichEditorProvider.alloc().init();
        console.warn(this.provider);
        console.warn(new UIDataDriver(this.provider, view))
        return new UIDataDriver(this.provider, view);
      });
    }
    this.swiftId = swiftId;
  }

  initNativeView() {
    super.initNativeView();
    // @ts-ignore
    this.provider.onEvent = (data) => {
      const textChange = data.objectForKey("textChange");
      const contextChange = data.objectForKey("contextChange");
      if (textChange) {
        // Note: you could format the NSAttributedString anyway you want
        // This just shows a start to converting to HTML string if desired
        const htmlString = attributedStringToHTML(textChange);
        this.notify({
          eventName: "textChange",
          data: htmlString,
        });
      }
      if (contextChange) {
        // console.log("contextChange:", contextChange);
        this.notify({
          eventName: "contextChange",
          data: contextChange,
        });
      }
    };
  }
}

function attributedStringToHTML(attributedString: NSAttributedString): string {
  let htmlString = "";

  attributedString.enumerateAttributesInRangeOptionsUsingBlock(
    { location: 0, length: attributedString.length },
    NSAttributedStringEnumerationOptions.LongestEffectiveRangeNotRequired,
    (attributes, range, stop) => {
      const substring = attributedString.string.substring(
        range.location,
        range.location + range.length
      );
      let span = `<span `;

      let style = `style="`;

      // Check for font
      const font = attributes.objectForKey(NSFontAttributeName);
      if (font) {
        const fontName = font.fontName;
        const fontSize = font.pointSize;
        style += `font-family: ${fontName}; font-size: ${fontSize}px;`;
      }

      // Check for text color
      const color = attributes.objectForKey(NSForegroundColorAttributeName);
      const paragraphStyle: NSParagraphStyle = attributes.objectForKey(
        NSParagraphStyleAttributeName
      );
      if (paragraphStyle) {
        switch (paragraphStyle.alignment) {
          case NSTextAlignment.Center:
            style += `text-align: center;`;
            break;
          case NSTextAlignment.Right:
            style += `text-align: right;`;
            break;
          case NSTextAlignment.Justified:
            style += `text-align: justify; text-justify: inter-word;`;
            break;
          default:
            style += `text-align: left;`;
            break;
        }
      }

      // Add other attributes (e.g., bold, italic)
      const traits = font.fontDescriptor.symbolicTraits;
      if (traits & UIFontDescriptorSymbolicTraits.TraitBold) {
        style += `font-weight: bold;`;
      }
      if (traits & UIFontDescriptorSymbolicTraits.TraitItalic) {
        style += `font-style: italic;`;
      }
      let textDecoration: string;
      const underline = attributes.objectForKey(NSUnderlineStyleAttributeName);
      if (underline) {
        textDecoration = addTextDecoration(textDecoration, "underline");
      }
      const strikethrough = attributes.objectForKey(
        NSStrikethroughStyleAttributeName
      );
      if (strikethrough) {
        textDecoration = addTextDecoration(textDecoration, "line-through");
      }
      if (textDecoration) {
        style += textDecoration + ";";
      }
      span += `${style}"`;

      // Close the span tag and add the text
      span += `>${substring}</span>`;
      htmlString += span;
    }
  );

  return htmlString;
}

function addTextDecoration(current: string, value: string) {
  if (!current) {
    current = "text-decoration:";
  }
  current += " " + value;
  return current;
}
