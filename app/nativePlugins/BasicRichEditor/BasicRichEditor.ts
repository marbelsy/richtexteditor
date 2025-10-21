// components/BasicRichEditor.ts
import { ContentView, isIOS, isAndroid } from '@nativescript/core'

export class BasicRichEditor extends ContentView {
  private _nativeView: any
  private _html = ''
  private _iosDelegate: any
  private _androidWatcher: android.text.TextWatcher | null = null

  createNativeView() {
    if (isIOS) {
      const tv = UITextView.new()
      tv.editable = true
      tv.scrollEnabled = true
      tv.font = UIFont.systemFontOfSize(16)

      const self = this
      const Delegate = (NSObject as any).extend(
        {
          // Intercept Enter to support bullets and cap consecutive Enters at 2
          textViewShouldChangeTextInRangeReplacementText: (
            textView: UITextView,
            range: NSRange,
            replacementText: string
          ) => {
            if (replacementText !== '\n') return true

            const text = textView.text || ''
            const caret = range.location

            // ----- Bullet handling -----
            const lineStart = self.iosLineStart(text, caret)
            const currentLine = text.substring(lineStart, caret)
            const onBullet = /^\s*•\s/.test(currentLine)
            const onlyBullet = /^\s*•\s*$/.test(currentLine)

            if (onBullet) {
              if (onlyBullet) {
                // Exit list: replace current bullet line with a single newline
                const newText =
                  text.substring(0, lineStart) + '\n' + text.substring(caret)
                textView.text = newText
                const pos = lineStart + 1
                textView.selectedRange = { location: pos, length: 0 } as any
                return false
              } else {
                // New bullet line
                const insert = '\n• '
                const newText =
                  text.substring(0, caret) + insert + text.substring(caret)
                textView.text = newText
                const pos = caret + insert.length
                textView.selectedRange = { location: pos, length: 0 } as any
                return false
              }
            }

            // ----- Normal text handling -----
            // Allow first Enter to insert ONE '\n' (return true).
            // If there are already 2 consecutive newlines before caret, block (cap at 2).
            if (caret > 1 && text.charAt(caret - 1) === '\n' && text.charAt(caret - 2) === '\n') {
              return false // already \n\n; ignore more
            }
            // Otherwise, let iOS insert a single '\n'. A second Enter will make it '\n\n'.
            return true
          },
        },
        { name: 'BasicRichEditorDelegate', protocols: [UITextViewDelegate] }
      )

      this._iosDelegate = new Delegate()
      ;(tv as any).delegate = this._iosDelegate
      this._nativeView = tv
    } else if (isAndroid) {
      const et = new android.widget.EditText(this._context)
      et.setTextSize(16)
      et.setPadding(0, 0, 0, 0)
      et.setInputType(
        android.text.InputType.TYPE_CLASS_TEXT |
        android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE |
        android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
      )

      const self = this
      let inWatch = false

      this._androidWatcher = new (android.text.TextWatcher as any)({
        beforeTextChanged() {},
        onTextChanged() {},
        afterTextChanged(s: android.text.Editable) {
          if (inWatch) return
          const pos = et.getSelectionStart()
          const end = et.getSelectionEnd()
          if (pos !== end) return // only caret insertions
          if (pos <= 0) return
          if (s.charAt(pos - 1) !== '\n') return

          inWatch = true
          try {
            const text = s.toString()

            // Cap consecutive Enters to at most 2: if we already have \n\n before caret, remove the new one
            if (pos - 2 >= 0 && text.charAt(pos - 2) === '\n') {
              if (pos - 3 >= 0 && text.charAt(pos - 3) === '\n') {
                // already at least \n\n before; delete the just-inserted '\n'
                s.delete(pos - 1, pos)
                et.setSelection(pos - 1)
                return
              }
              // We had exactly one '\n' before; keep this new '\n' → now it's '\n\n'
              // do nothing special
            }

            // ----- Bullet logic -----
            const lineStart = self.androidLineStart(text, pos - 1)
            const currentLine = text.substring(lineStart, pos - 1) // exclude just-inserted \n

            const onBullet = /^\s*•\s/.test(currentLine)
            const onlyBullet = /^\s*•\s*$/.test(currentLine)

            if (onBullet) {
              if (onlyBullet) {
                // Exit list: remove the inserted '\n', delete bullet content, leave a single newline
                s.delete(pos - 1, pos) // remove '\n'
                s.replace(lineStart, lineStart + currentLine.length, '')
                s.insert(lineStart, '\n')
                et.setSelection(lineStart + 1)
              } else {
                // New bullet line
                s.replace(pos - 1, pos, '\n• ')
                et.setSelection(pos + 2) // net +3 then caret shift -1 => +2
              }
            } else {
              // Normal text: leave '\n' as-is (first Enter produces one newline).
              // Second consecutive Enter naturally makes it '\n\n' (we allow that).
              // Nothing else to do.
            }
          } finally {
            inWatch = false
          }
        },
      })

      et.addTextChangedListener(this._androidWatcher)
      this._nativeView = et
    }

    return this._nativeView
  }

  disposeNativeView() {
    if (isAndroid && this._nativeView && this._androidWatcher) {
      this._nativeView.removeTextChangedListener(this._androidWatcher)
      this._androidWatcher = null
    }
    if (isIOS && this._nativeView) {
      ;(this._nativeView as UITextView).delegate = null
      this._iosDelegate = null
    }
    super.disposeNativeView()
  }

  // iOS: start index of current line
  private iosLineStart(text: string, caret: number) {
    let i = Math.max(0, caret - 1)
    while (i > 0 && text.charAt(i - 1) !== '\n') i--
    return i
  }

  // Android: start index of current line
  private androidLineStart(text: string, caretMinusOne: number) {
    let i = Math.max(0, caretMinusOne)
    while (i > 0 && text.charAt(i - 1) !== '\n') i--
    return i
  }

  /** Public html property */
  get html() {
    return this._html
  }
  set html(value: string) {
    this._html = value || ''
    this.updateFromHtml()
  }

  /** Import: simple HTML -> plain text + markers */
  private updateFromHtml() {
    const plain = (this._html || '')
      // paragraphs -> blank line separation is represented by '\n\n' in the model
      .replace(/<\/?p>/gi, '\n\n')
      // lists: keep simple bullets only
      .replace(/<ul>/gi, '')
      .replace(/<\/ul>/gi, '')
      .replace(/<ol>/gi, '')
      .replace(/<\/ol>/gi, '')
      .replace(/<li>/gi, '• ')
      .replace(/<\/li>/gi, '\n')
      // bold markers
      .replace(/<\s*(b|strong)\s*>/gi, '*')
      .replace(/<\s*\/\s*(b|strong)\s*>/gi, '*')
      // remove leftover tags
      .replace(/<\/?[^>]+>/g, '')
      // normalize: collapse 3+ newlines to 2
      .replace(/\n{3,}/g, '\n\n')

    if (isIOS) {
      ;(this._nativeView as UITextView).text = plain
    } else if (isAndroid) {
      this._nativeView.setText(plain)
      this._nativeView.setSelection(this._nativeView.getText().length())
    }
  }

  /** Export: plain text with markers -> HTML (<p>, <ul>/<li>, <strong>) */
  public getHtml(): string {
    let text = ''
    if (isIOS) text = (this._nativeView as UITextView).text || ''
    else if (isAndroid) text = this._nativeView.getText().toString()

    // normalize runs of 3+ to exactly 2
    text = text.replace(/\n{3,}/g, '\n\n')

    // split blocks by double newline (paragraph breaks)
    const rawBlocks = text.split(/\n{2}/)

    // collapse consecutive empties to a single empty paragraph
    const blocks: string[] = []
    for (const b of rawBlocks) {
      const trimmed = b.replace(/\s+$/g, '')
      if (trimmed.length === 0) {
        if (blocks.length === 0 || blocks[blocks.length - 1] !== '__EMPTY__') {
          blocks.push('__EMPTY__')
        }
      } else {
        blocks.push(trimmed)
      }
    }

    let html = ''
    for (const block of blocks) {
      if (block === '__EMPTY__') {
        html += '<p></p>'
        continue
      }

      const lines = block.split(/\n/)
      const allBullets = lines.every((l) => /^\s*•\s/.test(l) || l.trim() === '')

      if (allBullets) {
        html += '<ul>'
        for (const l of lines) {
          const item = l.replace(/^\s*•\s?/, '')
          if (item.trim().length) html += `<li>${escapeHtml(item)}</li>`
        }
        html += '</ul>'
      } else {
        // *bold* -> <strong>
        const withBold = block.replace(/\*(.*?)\*/g, '<strong>$1</strong>')
        html += `<p>${escapeHtmlExceptTags(withBold, ['strong'])}</p>`
      }
    }

    return html
  }
}

/** Escapes HTML entirely */
function escapeHtml(s: string) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
}

/** Escapes HTML but re-allows specific tags (here: <strong>) */
function escapeHtmlExceptTags(s: string, allowed: string[]) {
  let out = escapeHtml(s)
  for (const tag of allowed) {
    const open = new RegExp(`&lt;${tag}&gt;`, 'g')
    const close = new RegExp(`&lt;\\/${tag}&gt;`, 'g')
    out = out.replace(open, `<${tag}>`).replace(close, `</${tag}>`)
  }
  return out
}
