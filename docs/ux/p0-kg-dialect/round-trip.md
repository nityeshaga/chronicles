# Slice 0.3 receipts — kg-* round trip (dev DB, 25 Aug 2026)

Method (`tmp/rt/full.sh`, dev-browser on the real editor): curl the public page, open the post in the
editor, type one word in the first paragraph, wait for "Saved", curl again, compare marker counts and
block-level text. Then type a second word, save, and diff the stored body (`post.body.body.to_html`)
against the first save.

| post | iframe | gallery | embed | bookmark | figcaption | tweet | srcset | image-card | toggle | pre | public text delta (save 1) | stored body, save 1 → save 2 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 8 wth-does-a-neural-network-learn | 0→0 | 2→2 | 1→1 | 0→0 | 18→18 | 1→1 | 0→0 | 16→16 | 0→0 | 0→0 | +kgword1 (¹) | only kgword2 |
| 64 2024-recap-curated-connections | 1→1 | 2→2 | 1→1 | 1→1 | 8→8 | 0→0 | 18→18 | 13→13 | 0→0 | 0→0 | +kgword1 | only kgword2 |
| 61 beautiful-tools-…-moving-to-ghost | 0→0 | 3→3 | 0→0 | 0→0 | 4→4 | 0→0 | 10→10 | 3→3 | 2→2 | 0→0 | +kgword1 | only kgword2 |
| 15 whatsapp-chat-analyser (stand-in: the python post is not in this DB) | 1→1 | 0→0 | 9→9 | 0→0 | 1→1 | 8→8 | 0→0 | 7→7 | 0→0 | 2→2 | +kgword1 | kgword2 + two bare `<pre>` blocks lose a trailing `<br>` (²) |
| 23 equal-pay-for-equal-work (bare iframe HTML card, wide image card) | 1→1 | 0→0 | 9→9 | 0→0 | 0→0 | 9→9 | 0→0 | 1→1 | 0→0 | 0→0 | (¹) | only kgword2 |

¹ One block also loses the space before a `<br>` ("brain. <br>" → "brain.<br>") — Lexical trims a trailing
space before a line break; invisible when rendered, not a card. In post 23 the first paragraph holds an
opaque card, so the first typed word landed on the decorator and was not inserted; the second attempt typed
before it. ² Lexxy's code block trims a trailing empty line on its second pass; prose-level, not a card.

`<action-text-attachment>` goes 0 → N on the public page for every post: each card now renders inside
its attachment wrapper (inline element; the figure inside keeps the `.kg-card` rhythm).

New-post check (kg-dialect-new-post-check): one upload + caption, two uploads in a row, pasted YouTube URL →
public page has `kg-image-card` 1 (`kg-card-hascaption`, figcaption, srcset, no filename/size caption),
`kg-gallery-card` 1 with 2 `kg-gallery-image`, `kg-embed-card` 1 with 1 iframe, `attachment--` 0. Reload the
editor, type and delete a character, save → stored body byte-identical (2054 bytes).

Screenshots: `*-canvas-top.png`, `*-canvas-image-node.png` (caption textarea shows raw caption HTML — see
report), `*-canvas-opaque-card.png`, `*-public-top.png`, `*-public-card.png` for posts 8 and 64;
`new-post-canvas.png`, `new-post-public.png`. Images under /content/images/ 404 in dev (no volume), so
imported Ghost-hosted images paint blank in both canvas and public page here.
