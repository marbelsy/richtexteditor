import { View } from "@nativescript/core";

export * from "./common";

export declare class RichEditor extends View {
  data: RichEditorData;
  /** Android only */
  insertVideoSample(): void;
  /** Android only */
  insertLinkSample(): void;
}