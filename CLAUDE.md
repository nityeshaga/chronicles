# Chronicles

## Pull requests

**PR descriptions read top-down.** When writing a PR description, start with what changes for the user in a sentence or two, then add detail step by step, ending with how it works and architecture. Use visuals like tables, ASCII diagrams or mermaid where they're easier to follow than prose. Keep it up to date with the final code, including what changed in later commits.

**Screenshots are the proof for UI work.** Any PR that makes a change a user can see or experience gets screenshots of all key changes posted as a PR comment, desktop and mobile, before and after. This helps in reviewing the experience.

A PR comment cannot show an image from your disk, and `gh` cannot upload attachments, so check the PNGs into the PR itself under `docs/screenshots/` (name them `YYYY-MM-DD-<page>-<viewport>.png`) and embed them by their GitHub URL pinned to the commit:

```markdown
![home, desktop](https://github.com/nityeshaga/chronicles/blob/<commit-sha>/docs/screenshots/2026-09-17-home-desktop.png?raw=true)
```

Use the `github.com/.../blob/...?raw=true` form, never `raw.githubusercontent.com`: the blob URL is served by github.com with the viewer's session, so it works whether the repo is public or private, while the raw host needs a token for a private repo and shows a broken image. Pin the SHA, not the branch, so the image still resolves after the branch is deleted.
