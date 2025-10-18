<template>
  <Page>
    <ActionBar>
      <Label text="Home" />
    </ActionBar>

    <GridLayout columns="*, *" rows="50, *" backgroundColor="red">
      <Button text="Video" col="0" row="0" @tap="insertVideo" />
      <Button text="Link" col="1" row="0" @tap="insertLinkSample" />
      <RichTextEditor row="1" col="0" colSpan="2" @loaded="editorLoaded" />
    </GridLayout>
  </Page>
</template>

<script lang="ts">
import type { RichEditor, RichEditorData } from "../plugins";
let editor: RichEditor;
let data: RichEditorData = {
  text: "",
  isInspectorPresented: false,
  insetWidth: 65,
  insetHeight: 20,
  showToolbar: false,
};
export default {
  data() {
    return {
      editor: null,
    };
  },
  methods: {
    editorLoaded(args) {
      editor = args.object;
    },
    insertVideo() {
      if (__APPLE__) {
        data = {
          ...data,
          showToolbar: !data.showToolbar,
        };
        editor.data = data;
      } else {
        this.editor.insertVideoSample();
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
