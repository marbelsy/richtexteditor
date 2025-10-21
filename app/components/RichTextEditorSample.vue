<template>
  <GridLayout columns="*, *" rows="auto, *" backgroundColor="red">

    <StackLayout>
      <Button text="UL" col="0" row="0" @tap="setUnorderedList" />
      <Button text="OL" col="0" row="0" @tap="setOrderedList" />
      <Button text="Link" col="1" row="0" @tap="insertLinkSample" />
      <Button text="Bold" col="1" row="0" @tap="setBold" />
    </StackLayout>

    <RichTextEditor row="1" col="0" colSpan="2" @loaded="editorLoaded"
                    @textChange="textChange" @contextChange="contextChange"/>
  </GridLayout>
</template>

<script>
let editor;
let data = {
  // text: "<div><ol><li>Test</li><li>Test 2</li></ol></div>",
  text: "",
  isInspectorPresented: true,
  insetWidth: 65,
  insetHeight: 20,
  showToolbar: false,
};

export default {
  name: "RichTextEditorSample",
  methods: {
    contextChange(value) {
      console.error(value.data);
    },
    textChange(value) {
      console.warn(value.data)
      console.info('----')
    },
    editorLoaded(args) {
      args.object.backgroundColor = 'white'
      editor = args.object;
      editor.data = data
    },
    setOrderedList() {
      if (__APPLE__) {
        editor.provider.toggleNumberedList();
        // editor.provider.toogleUList()
      } else {
        editor.setOrderedList();
      }
    },
    setUnorderedList() {
      if (__APPLE__) {
        editor.provider.toggleBulletedList();
        // editor.provider.toogleUList()
      } else {
        editor.setUnorderedList();
      }
    },
    insertLinkSample() {
      if (__APPLE__) {
        editor.provider.setLink("https://example.com");
      } else {
        editor.insertLinkSample();
      }
    },
    setBold() {
      if (__APPLE__) {
        editor.provider.toggleBold()
      } else {
        editor.setBold();
      }
    }
  }
}
</script>

<style scoped lang="scss">

</style>
