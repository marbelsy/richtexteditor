<template>
  <Page>
    <ActionBar>
      <Label text="Home" />
    </ActionBar>

    <RichTextEditorSample/>
    <GridLayout columns="*, *" rows="50, *" backgroundColor="red" v-if="false">
      <!--
      <Button text="Get text" @tap="getTextVal" col="0" row="0"/>
      <Button text="replaceSelectedTextWithLink" @tap="replaceSelectedTextWithLink" col="1" row="0"/>
      <TextView ref="textView" row="1" col="0" colSpan="2" @textChange="textChangeTV" @loaded="tvLoaded"/>
      --->
      <!--
      <Button text="getHtml" col="0" row="0" @tap="getHTMLFromBRE"/>
      <BasicRichEditor ref="bre" row="1" col="0" colSpan="2" :html="text"/>
      --->
    </GridLayout>
  </Page>
</template>

<script lang="ts">
import type { RichEditor, RichEditorData } from "../plugins";
import RichTextEditorSample from "~/components/RichTextEditorSample.vue";
let editor: RichEditor;
let data: RichEditorData = {
  // text: "<div><ol><li>Test</li><li>Test 2</li></ol></div>",
  text: "<span style=\"font-family: Helvetica-Bold; font-size: 12px;text-align: left;font-weight: bold;\">Test</span>",
  isInspectorPresented: true,
  insetWidth: 65,
  insetHeight: 20,
  showToolbar: false,
};
export default {
  components: {RichTextEditorSample},
  data() {
    return {
      value: '<p>AsdaDD asd asd</p><p>Asdf asdf asdf</p><p></p><p>Asdf asdfasdf</p>',
      editor: null,
      lloremIpsumTest: 'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.'
    };
  },
  computed: {
    textValue: {
      get: function() {
        console.warn(this.parseValueToTVUsage(this.value))
        return this.parseValueToTVUsage(this.value)
      },
      set: function(value) {
        this.value = this.parseValueFromTVUsage(value)
      }
    }
  },
  methods: {
    parseValueToTVUsage(value) {
      if(!value) {
        return ''
      }
      value = value.replaceAll('<p>', '').replaceAll('</p>', '\n\n').replaceAll('<br>', '\n')
      return value
    },
    parseValueFromTVUsage(value) {
      if(!value || !value.length) {
        return ''
      }
      value = value.replaceAll('\n\n', '</p><p>').replaceAll('\n', '<br>')
      value = `<p>${value}</p>`
      return value
    },
    replaceSelectedTextWithLink() {
      const textView = this.$refs.textView;
      const nativeTextView = textView.nativeView.nativeTextViewProtected;
      const selectedText = this.getSelectedText(nativeTextView)

      if(global.isAndroid) {
        let text = nativeTextView.getText().toString()
        // text.splice(selectedText.end, selectedText.start-selectedText.end, `<a href="www.google.de">${selectedText.textValue}</a>`)
        text = text.slice(0, selectedText.start) + `<a href="www.google.de">${selectedText.textValue}</a>` + text.slice(selectedText.end)
        nativeTextView.setText(text)
      } else if(global.isIOS) {
        let text = nativeTextView.text
        text = text.slice(0, selectedText.start) + `<a href="www.google.de">${selectedText.textValue}</a>` + text.slice(selectedText.end)
        nativeTextView.text = text
      }


    },
    getSelectedText(nativeTextView) {
      if (global.isAndroid) {
        const start = nativeTextView.getSelectionStart();
        const end = nativeTextView.getSelectionEnd();
        console.warn(`${start} to ${end} with ${nativeTextView.getText().toString().substring(start, end)}`)
        return {
          start: start,
          end: end,
          textValue: nativeTextView.getText().toString().substring(start, end)
        }
      } else if (global.isIOS) {
        const range = nativeTextView.selectedRange;
        const start = range.location;
        const end = start + range.length;
        return {
          start: start,
          end: end,
          textValue: nativeTextView.text.substring(start, end)
        }
      }
      return null
    },
    tvLoaded(args) {
      args.object.text = this.textValue
    },
    textChangeTV(args) {
      this.textValue = args.value
    },
    getTextVal() {
      console.warn(this.value)
    },
    getHTMLFromBRE() {
      console.warn(this.$refs.bre.nativeView.getHtml())
    }
  },
};
</script>

<style scoped lang="scss">
@import "@nativescript/theme/scss/variables/blue";

// Custom styles
.fas {
  @include colorize($color: accent);
}

.info {
  font-size: 20;
  horizontal-align: center;
  vertical-align: center;
}
</style>
