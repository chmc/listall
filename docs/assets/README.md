# Assets Guide for ListAll Website

This directory contains visual assets for the ListAll website at https://listall.app/

## Required Assets

### 1. App Icon (`app-icon.png`)
- **Size**: 1024x1024 pixels
- **Format**: PNG with transparency
- **Purpose**: Display on website, favicon generation
- **Source**: Use the same icon from `ListAll/Assets.xcassets/AppIcon.appiconset/`
- **How to export**: 
  1. Open Xcode project
  2. Navigate to Assets.xcassets
  3. Right-click AppIcon → Show in Finder
  4. Export 1024x1024 version
  5. Copy to `docs/assets/app-icon.png`

### 2. Screenshots (`screenshots/*.png`)
- **Recommended**: 5-8 screenshots
- **Size**: iPhone 14 Pro (1290x2796) or actual device screenshots
- **Format**: PNG
- **Purpose**: Display in screenshots section of website
- **Suggested screenshots**:
  1. `01-lists-view.png` - Main lists screen
  2. `02-items-view.png` - Items within a list
  3. `03-item-detail.png` - Item details with photo
  4. `04-smart-suggestions.png` - Suggestions in action
  5. `05-watch-app.png` - Apple Watch interface
  6. `06-settings.png` - Settings screen (optional)

**How to capture**:
```bash
# Run app in simulator
# Press Cmd+S to save screenshot
# Or use: xcrun simctl io booted screenshot screenshot.png
```

### 3. Open Graph Image (`og-image.png`)
- **Size**: 1200x630 pixels
- **Format**: PNG or JPG
- **Purpose**: Social media sharing preview (Facebook, LinkedIn, etc.)
- **Content**: 
  - App icon
  - App name "ListAll"
  - Tagline "Smart Lists with Sync"
  - Key feature highlights
  - Clean, branded design
- **Tools**: Figma, Canva, Photoshop, or Sketch

### 4. Twitter Card Image (`twitter-image.png`)
- **Size**: 1200x675 pixels
- **Format**: PNG or JPG
- **Purpose**: Twitter sharing preview
- **Content**: Similar to OG image but optimized for Twitter's aspect ratio

## Optional Assets

### Favicon (`favicon.ico`)
- **Size**: 32x32, 16x16 (multi-size .ico file)
- **Purpose**: Browser tab icon
- **Generate from**: app-icon.png
- **Tools**: https://favicon.io/ or https://realfavicongenerator.net/

### Apple Touch Icon (`apple-touch-icon.png`)
- **Size**: 180x180 pixels
- **Format**: PNG
- **Purpose**: iOS home screen bookmark icon
- **Source**: Resized version of app-icon.png

## Quick Asset Generation Workflow

### Step 1: Export App Icon from Xcode
```bash
# Navigate to your project
cd /Users/aleksi/source/ListAllApp/ListAll

# Find the 1024x1024 app icon in Assets
# Copy to docs/assets/
cp "ListAll/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" \
   ../docs/assets/app-icon.png
```

### Step 2: Capture Screenshots
```bash
# Launch iOS Simulator with your app
# Take screenshots using Cmd+S
# Screenshots saved to Desktop by default
# Move to docs/assets/screenshots/
mv ~/Desktop/Simulator*.png docs/assets/screenshots/
# Rename files appropriately
```

### Step 3: Create Social Media Images

**Using Figma** (Recommended):
1. Create new design: 1200x630
2. Add app icon (centered or left-aligned)
3. Add text: "ListAll - Smart Lists with Sync"
4. Add 3-4 key features with icons
5. Use app's color scheme (#007AFF)
6. Export as PNG
7. Save as `og-image.png`
8. Create 1200x675 version for Twitter

**Using Canva** (Easy):
1. Go to canva.com
2. Search for "Facebook Post" template (1200x630)
3. Design with app branding
4. Download as PNG
5. Repeat for Twitter (1200x675)

### Step 4: Generate Favicon
1. Go to https://favicon.io/favicon-converter/
2. Upload `app-icon.png`
3. Download generated favicon package
4. Copy `favicon.ico` to `docs/assets/`

## Asset Optimization

Before uploading, optimize images for web:

```bash
# Install ImageMagick (if not already installed)
brew install imagemagick

# Optimize PNG files
mogrify -strip -interlace Plane -quality 85 docs/assets/*.png

# Optimize screenshots
mogrify -strip -interlace Plane -quality 85 \
        -resize 50% docs/assets/screenshots/*.png

# Convert large PNGs to JPG if needed
convert docs/assets/og-image.png -quality 85 docs/assets/og-image.jpg
```

## Integration with Website

Once assets are added, update `index.html`:

```html
<!-- Add favicon -->
<link rel="icon" type="image/x-icon" href="assets/favicon.ico">
<link rel="apple-touch-icon" href="assets/apple-touch-icon.png">

<!-- Update OG and Twitter images -->
<meta property="og:image" content="https://listall.app/assets/og-image.png">
<meta name="twitter:image" content="https://listall.app/assets/twitter-image.png">

<!-- Add screenshots to screenshots section -->
<div class="screenshot">
    <img src="assets/screenshots/01-lists-view.png" alt="ListAll main screen">
</div>
```

## Current Status

- [ ] App icon (app-icon.png)
- [ ] Screenshots (5-8 images)
- [ ] Open Graph image (og-image.png)
- [ ] Twitter Card image (twitter-image.png)
- [ ] Favicon (favicon.ico)
- [ ] Apple Touch Icon (apple-touch-icon.png)

## File Size Guidelines

- **App Icon**: < 500 KB
- **Screenshots**: < 300 KB each
- **OG Image**: < 500 KB
- **Twitter Image**: < 500 KB
- **Favicon**: < 50 KB

## Asset Checklist

Before going live, ensure:
- [ ] All images are optimized for web
- [ ] File names use lowercase and hyphens
- [ ] No spaces in file names
- [ ] Images have appropriate alt text in HTML
- [ ] OG/Twitter images display correctly when testing with debuggers:
  - Facebook Debugger: https://developers.facebook.com/tools/debug/
  - Twitter Card Validator: https://cards-dev.twitter.com/validator
- [ ] Favicon displays correctly in all browsers
- [ ] Screenshots showcase key features clearly
- [ ] All images use consistent branding (colors, style)

## License

All assets should be created specifically for the ListAll project and are covered under the GPL-3.0-or-later license.

---

**Note**: High-quality assets significantly improve the website's professional appearance and social media presence. Take time to create polished, branded images.
