<template>
  <Page>
    <ActionBar>
      <Label text="Home" />
    </ActionBar>

    <GridLayout columns="*, *" rows="50, *" backgroundColor="red">
      <Button text="Video" col="0" row="0" @tap="insertVideo" />
      <Button text="Link" col="1" row="0" @tap="insertLinkSample" />
      <RichTextEditor row="1" col="0" colSpan="2" @loaded="editorLoaded"
                      @textChange="textChange" @contextChange="contextChange"/>
    </GridLayout>
  </Page>
</template>

<script lang="ts">
import type { RichEditor, RichEditorData } from "../plugins";
let editor: RichEditor;
let data: RichEditorData = {
  text: "",
  isInspectorPresented: true,
  insetWidth: 65,
  insetHeight: 20,
  showToolbar: true,
};
export default {
  data() {
    return {
      editor: null,
      lloremIpsumTest: 'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.'
    };
  },
  methods: {
    contextChange(value) {
      console.info(value.data);
    },
    textChange(value) {
      console.warn(value.data);
    },
    editorLoaded(args) {
      console.warn(args.object.getActualSize())
      args.object.backgroundColor = 'white'
      editor = args.object;
      editor.data = data
    },
    insertVideo() {
      if (__APPLE__) {
        data = {
          ...data,
          showToolbar: !data.showToolbar,
        };
        editor.data = data;
      } else {
        editor.insertVideoSample();
      }
    },
    insertLinkSample() {
      if (__APPLE__) {
        data = {
          ...data,
          isInspectorPresented: !data.isInspectorPresented,
        };
        editor.data = data;
      } else {
        editor.insertLinkSample();
      }
    },
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
