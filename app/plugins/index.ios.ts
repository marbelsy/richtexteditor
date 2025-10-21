import { Utils } from "@nativescript/core";
import { registerSwiftUI, SwiftUI, UIDataDriver } from "@nativescript/swift-ui";
import { RichEditorType } from "./common";

export class RichEditor extends SwiftUI implements RichEditorType {
  provider: RichEditorProvider;

  constructor() {
    super();
    // make each usage unique so could use many throughout app is desired
    const swiftId = `richEditor-${crypto.randomUUID()}`;
    if (Utils.SDK_VERSION >= 17) {
      registerSwiftUI(swiftId, (view) => {
        this.provider = RichEditorProvider.alloc().init();
        return new UIDataDriver(this.provider as any, view);
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

  setOrderedList() {
    console.warn('setOrderedList')
    this.updateData({ setList: "numbered", enable: true });
  }

  setUnorderedList() {
    this.updateData({ setList: "bullet", enable: true });
  }
}

function attributedStringToHTML(attr: NSAttributedString): string {
  // First pass: inline tags for bold and links, preserve newlines
  let htmlParts: string[] = [];

  attr.enumerateAttributesInRangeOptionsUsingBlock(
    { location: 0, length: attr.length },
    NSAttributedStringEnumerationOptions.LongestEffectiveRangeNotRequired,
    (attributes, range, stop) => {
      let text = attr.string.substring(range.location, range.location + range.length);

      // Escape HTML special chars, keep newlines for later list handling
      text = text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");

      // Detect link
      const link = attributes.objectForKey(NSLinkAttributeName) as NSURL | string;

      // Detect bold
      let isBold = false;
      const font = attributes.objectForKey(NSFontAttributeName) as UIFont;
      if (font) {
        const traits = font.fontDescriptor.symbolicTraits;
        // Bitwise check for bold
        // @ts-ignore
        if (traits & UIFontDescriptorSymbolicTraits.TraitBold) {
          isBold = true;
        }
      }

      // Compose wrappers (nest link outside, bold inside for valid HTML)
      if (link) {
        const href = typeof link === "string" ? link : (link as NSURL).absoluteString;
        text = `<a href="${href}">${text}</a>`;
      }
      if (isBold) {
        text = `<strong>${text}</strong>`; // can also use <b> ?
      }

      htmlParts.push(text);
    }
  );

  const inlineHTML = htmlParts.join("");

  // Second pass: convert lines with list markers into <ul>/<ol>
  return normalizeLists(inlineHTML);
}

function normalizeLists(inlineHTML: string): string {
  // Split on newlines preserved from the attributed string
  const lines = inlineHTML.split(/\n/);

  const ulMarker = /^\s*(?:[•\-\*])\s+(.*)$/;      // bullets: •, -, *
  const olMarker = /^\s*(\d+)[.)]\s+(.*)$/;        // numbers: "1. " or "1) "

  let out: string[] = [];
  let currentList: { type: "ul" | "ol"; items: string[] } | null = null;

  const flushList = () => {
    if (!currentList) return;
    const tag = currentList.type;
    out.push(`<${tag}>`);
    for (const it of currentList.items) out.push(`<li>${it}</li>`);
    out.push(`</${tag}>`);
    currentList = null;
  };

  for (const rawLine of lines) {
    const line = rawLine.trimEnd(); // keep leading spaces for markers detection above

    let m = line.match(ulMarker);
    if (m) {
      const item = m[1];
      if (!currentList || currentList.type !== "ul") {
        flushList();
        currentList = { type: "ul", items: [] };
      }
      currentList.items.push(item);
      continue;
    }

    m = line.match(olMarker);
    if (m) {
      const item = m[2];
      if (!currentList || currentList.type !== "ol") {
        flushList();
        currentList = { type: "ol", items: [] };
      }
      currentList.items.push(item);
      continue;
    }

    // Plain line
    flushList();
    if (line.length > 0) {
      out.push(line + "<br>");
    } else {
      // paragraph break
      out.push("<br>");
    }
  }

  flushList();

  // Tidy trailing <br>
  return out.join("\n").replace(/(<br>\s*)+$/,"");
}

function addTextDecoration(current: string, value: string) {
  if (!current) {
    current = "text-decoration:";
  }
  current += " " + value;
  return current;
}
