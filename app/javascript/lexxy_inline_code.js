import { Extension, Lexical } from "lexxy"

// Lexxy's toolbar dispatches whatever a button's data-command names, but its own command
// set has no inline code — the format exists (backticks make it, the arrow keys step out
// of it), there is just no verb to toggle it from a button or a hotkey. Register the
// one that's missing, under the same string contract the rest of the toolbar speaks.
export default class InlineCode extends Extension {
  get lexicalExtension() {
    return this.defineExtension({
      name: "chronicles/inline-code",
      register: (editor) => editor.registerCommand("inlineCode", () => {
        editor.dispatchCommand(Lexical.FORMAT_TEXT_COMMAND, "code")
        return true
      }, Lexical.COMMAND_PRIORITY_LOW)
    })
  }
}
