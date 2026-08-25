import { Extension } from "lexxy"

// ⌘⌥2/3/4 for the body's headings, ⌘⌥0 back to paragraph — the chord Ghost and Notion
// both use, and the one thing the toolbar's `data-hotkey` can't carry: Lexxy matches
// hotkeys on `event.key`, and on a Mac keyboard Option+2 arrives as "™". `event.code` is
// the physical key and says Digit2 whatever Option did to the character, so the chords
// are matched on that instead. Ctrl stands in for Cmd, as everywhere else in the toolbar.
//
// `applyHeadingFormat` is Lexxy's own command for "make this heading that tag" — the same
// call its Large/Medium/Small presets resolve to, only named rather than counted. The tag
// has to be one the editor is configured for, so ⌘⌥1 does nothing: the body has no h1, on
// purpose, and configuring a different set of headings moves the keyboard with the menu.
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
    if (!event.altKey || event.shiftKey || !(event.metaKey || event.ctrlKey)) return
    // AltGr reports as Ctrl+Alt on a European layout, where these digits are characters
    // the writer means to type. A Mac's Option never carries Cmd with it, so the chord
    // this file exists for is not what's being turned away.
    if (event.getModifierState?.("AltGraph") && !event.metaKey) return

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
    return this.#headings.includes(tag) ? { command: "applyHeadingFormat", payload: tag } : null
  }

  get #headings() {
    return this.editorConfig.get("headings")
  }
}
