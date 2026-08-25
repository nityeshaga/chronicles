import { Extension, Lexical } from "lexxy"

const { $getSelection, $isRangeSelection, $getNodeByKey } = Lexical

// A post has one h1, its title; the body's headings are h2–h4, and the toolbar offers
// exactly those. Markdown doesn't know that: `# ` is Lexical's built-in shortcut for h1,
// and a body h1 reaches the public page as a second <h1>. The shortcut list isn't
// configurable, so this watches for an h1 under the caret — a heading the writer just
// made — and sets it down to h2. A heading the caret isn't in is left alone: an imported
// post's h1s are a fact of the import, not something opening it quietly rewrites.
export default class BodyHeadings extends Extension {
  get lexicalExtension() {
    return this.defineExtension({
      name: "chronicles/body-headings",
      register: editor => editor.registerUpdateListener(({ editorState, dirtyElements }) => {
        if (dirtyElements.size === 0) return

        const key = editorState.read(() => {
          const selection = $getSelection()
          if (!$isRangeSelection(selection)) return null

          const block = selection.anchor.getNode().getTopLevelElement()
          return block?.getType() === "heading" && block.getTag() === "h1" ? block.getKey() : null
        })

        if (key) editor.update(() => $getNodeByKey(key)?.setTag("h2"), { tag: "history-merge" })
      })
    })
  }
}
