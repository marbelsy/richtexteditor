import Vue from "nativescript-vue";
import Home from "./components/Home.vue";

import { RichEditor } from "./plugins";
Vue.registerElement("RichTextEditor", () => RichEditor);

import { BasicRichEditor } from './nativePlugins/BasicRichEditor/BasicRichEditor'
Vue.registerElement('BasicRichEditor', () => BasicRichEditor)

new Vue({
  render: (h) => h("frame", [h(Home)]),
}).$start();
