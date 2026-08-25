import { Extension } from "lexxy"

// Two things Lexical's code block gets wrong for a writer, fixed where the block is made.
//
// The default language. A block typed as ``` arrives with no language, and the
// highlighter's own transform then stamps JavaScript on it — the tokenizer's default,
// which Lexxy 0.9.31 copies at registration and exposes nowhere (the toolbar button
// already asks for "plain"; the fence shortcut is the path that doesn't). Transforms run
// in registration order and the highlighter's are registered first, so ours go at the
// front of the list rather than the back: by the time the highlighter looks, the block
// already says plain text. Three lists, because the highlighter reaches the block from
// its text children too — a leaf's transform runs before its parent's, and the fence
// shortcut's first leaf is what used to stamp the language.
//
// The language hint. Lexical reads a pasted block's language from data-language alone.
// A markdown fence (Lexxy renders ```ruby to <pre><code class="language-ruby">), Ghost's
// importer (the same shape) and Trix (<pre language="ruby">) all spell it differently, and
// every one of them landed as JavaScript. Conversion matchers all run before one is
// chosen, so a matcher that copies the hint onto data-language and claims nothing lets
// Lexical's own converter find it. It goes straight into the editor's conversion cache,
// the way Lexxy's own highlight-preserving pre converter does, because an extension's
// html.import is merged by tag — declaring pre there would displace Lexxy's Trix converter,
// and the next extension to declare pre would displace ours, neither with an error.
const LANGUAGE_CLASS = /^language-(.+)$/

export default class CodeBlocks extends Extension {
  get lexicalExtension() {
    return this.defineExtension({
      name: "chronicles/code-blocks",
      register(editor) {
        const conversions = editor._htmlConversions.get("pre")
        conversions.push(rememberLanguageHint)
        const forget = defaultToPlainText(editor)
        return () => { conversions.splice(conversions.indexOf(rememberLanguageHint), 1); forget() }
      }
    })
  }
}

function rememberLanguageHint(pre) {
  if (!pre.hasAttribute("data-language")) {
    const hint = pre.getAttribute("language") || languageClass(pre) || languageClass(pre.querySelector("code"))
    pre.setAttribute("data-language", hint || "plain")
  }
  return null
}

function languageClass(element) {
  if (!element) return null
  for (const name of element.classList) {
    const match = name.match(LANGUAGE_CLASS)
    if (match) return match[1]
  }
  return null
}

function defaultToPlainText(editor) {
  const CodeNode = editor._nodes.get("code").klass
  const plainText = (node) => {
    const block = node instanceof CodeNode ? node : node.getParent()
    if (block instanceof CodeNode && block.getLanguage() === undefined) block.setLanguage("plain")
  }

  // Lexxy replaces the code node with a subclass of its own, and Lexical registers a
  // transform on the replacement too, so both lists are covered.
  const registrations = [ "code", "text", "code-highlight" ].flatMap(type => {
    const registration = editor._nodes.get(type)
    return registration.replaceWithKlass ? [ registration, editor._nodes.get(registration.replaceWithKlass.getType()) ] : [ registration ]
  })
  registrations.forEach(registration => { registration.transforms = new Set([ plainText, ...registration.transforms ]) })
  return () => registrations.forEach(registration => registration.transforms.delete(plainText))
}
