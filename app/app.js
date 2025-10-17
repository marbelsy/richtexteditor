import Vue from 'nativescript-vue'

import Home from './components/Home'

import {RichEditor} from "~/plugins";
Vue.registerElement('RichTextEditor', () => RichEditor)

new Vue({
  render: (h) => h('frame', [h(Home)]),
}).$start()
