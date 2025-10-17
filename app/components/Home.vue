<template>
    <Page>
        <ActionBar>
            <Label text="Home"/>
        </ActionBar>

      <GridLayout columns="*, *" rows="50, *" backgroundColor="red">
        <Button text="Video" col="0" row="0" @tap="insertVideo"/>
        <Button text="Link" col="1" row="0" @tap="insertLinkSample"/>
        <RichTextEditor row="1" col="0" colSpan="2" @loaded="editorLoaded"/>
      </GridLayout>
    </Page>
</template>

<script>
  export default {
    data() {
      return {
        editor: null
      }
    },
    methods: {
      editorLoaded(args) {
        this.editor = args.object
      },
      insertVideo() {
        this.editor.insertVideoSample()
      },
      insertLinkSample() {
        this.editor.insertLinkSample()
      }
    }
  };
</script>

<style scoped lang="scss">
    @import '@nativescript/theme/scss/variables/blue';

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
