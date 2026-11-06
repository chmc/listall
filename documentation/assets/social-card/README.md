# Social card images

`social-card.html` is the source for the link preview images on listall.app:

| Output | Size | Used by |
|---|---|---|
| `docs/assets/og-image.png` | 1200×630 | `og:image` (Slack, iMessage, Facebook, LinkedIn) |
| `docs/assets/twitter-image.png` | 1200×675 | `twitter:image` |

The card uses `docs/assets/appicon.png` and the committed App Store screenshot
`fastlane/screenshots_compat/en-US/iPhone 17 Pro Max-03_GroceryItems.png`. Re-render
after either changes. Rendering uses the system WebKit, so it needs no browser install:

```bash
D=documentation/assets/social-card
swift $D/render.swift $D/social-card.html "$PWD" 1200 630 docs/assets/og-image.png
swift $D/render.swift $D/social-card.html "$PWD" 1200 675 docs/assets/twitter-image.png
magick docs/assets/og-image.png -strip -define png:compression-level=9 docs/assets/og-image.png
magick docs/assets/twitter-image.png -strip -define png:compression-level=9 docs/assets/twitter-image.png
```

Run from the repository root. The screenshot crop in the `.shot` CSS assumes the
device frame position of the 1290×2796 App Store screenshot.
