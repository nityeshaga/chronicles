import { Extension } from "lexxy"

// ⌘⌥2/3/4 for the body's headings, ⌘⌥0 back to paragraph — the chord Ghost and Notion
// both use, and the one thing the toolbar's `data-hotkey` can't carry: Lexxy matches
// hotkeys on `event.key`, and on a Mac keyboard Option+2 arrives as "™". `event.code` is
// the physical key and says Digit2 whatever Option did to the character, so the chords
// are matched on that instead. Ctrl stands in for Cmd, as everywhere else in the toolbar.
//
// The tag comes from the editor's own heading config and the command is the one the
// heading dropdown's buttons dispatch, so configuring a different set of headings moves
// the keyboard with the menu. A digit with no configured heading (⌘⌥1 — the body has no
// h1, on purpose) does nothing.
const PRESET_COMMANDS = [ "setFormatHeadingLarge", "setFormatHeadingMedium", "setFormatHeadingSmall" ]

export default class HeadingHotkeys extends Extension {
  get lexicalExtension() {
    return this.defineExtension({
      name: "chronicles/heading-hotkeys",
      register: (editor) => {
        const handler = (event) => this.#handleHotkey(event, editor)

        return editor.registerRootListener((root, previousRoot) => {
          previousRoot?.removeEventListener("keydown", handler)
          root?.addEventListener("keydown", handler)
        })
      }
    })
  }

  #handleHotkey(event, editor) {
    if (!event.altKey || !(event.metaKey || event.ctrlKey)) return

    const dispatch = this.#dispatchFor(event.code)
    if (!dispatch) return

    event.preventDefault()
    // Lexxy's own matcher is listening one element up and would read this as a bare
    // digit; nothing above the editor has a claim on the chord either.
    event.stopPropagation()
    editor.dispatchCommand(dispatch.command, dispatch.payload)
  }

  #dispatchFor(code) {
    if (code === "Digit0") return { command: "setFormatParagraph" }

    const tag = code.replace(/^Digit/, "h")
    const index = this.#headings.indexOf(tag)
    if (index < 0) return null

    return { command: PRESET_COMMANDS[index] ?? "applyHeadingFormat", payload: tag }
  }

  get #headings() {
    return this.editorConfig.get("headings")
  }
}
