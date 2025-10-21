import { RichEditorCommon } from './common';

export class RichEditor extends RichEditorCommon {
  editor: jp.wasabeef.richeditor.RichEditor;
  createNativeView() {
    this.editor = new jp.wasabeef.richeditor.RichEditor(this._context);
    return this.editor;
  }

  initNativeView() {
    this.editor.setOnTextChangeListener(new jp.wasabeef.richeditor.RichEditor.OnTextChangeListener({
      onTextChange: (text) => {
        this.notify({
          eventName: 'textChange',
          data: text,
        });
      },
    }))
    this.editor.setOnDecorationChangeListener(new jp.wasabeef.richeditor.RichEditor.OnDecorationStateListener({
      onStateChangeListener: (test, decorations) => {
        console.info(test)
        console.warn(decorations)
      }
    }))
  }

  insertVideoSample() {
    this.editor.insertVideo("https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_10MB.mp4", 360);
  }

  insertLinkSample() {
    this.editor.insertLink("https://nativescript.org", "NativeScript");
  }

  setUnorderedList() {
    this.editor.setBullets()
  }

  setOrderedList() {
    this.editor.setNumbers()
  }

  setBold() {
    this.editor.setBold()
  }
}
