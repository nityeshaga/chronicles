import { configure } from "lexxy"
import EmbedFrames from "lexxy_embed_frames"
import CodeBlocks from "lexxy_code_blocks"

// Lexxy's configure replaces the extensions list rather than adding to it, so the list is
// written once, here. Lexxy defers defining its elements until the current call stack
// drains, so configuring right after the writing entry imports it lands in time.
configure({ global: { extensions: [ EmbedFrames, CodeBlocks ] } })
