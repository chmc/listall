# ListAll GitHub Pages Website

This directory contains the GitHub Pages website for ListAll at https://listall.app/

## Files

- **index.html** - Main landing page with features, screenshots, and download links
- **privacy.html** - Complete privacy policy
- **support.html** - Help center with FAQs and contact information

## Deployment to GitHub Pages

### 1. Enable GitHub Pages

1. Go to your repository settings: https://github.com/chmc/listall/settings
2. Navigate to "Pages" in the left sidebar
3. Under "Source", select:
   - **Source**: Deploy from a branch
   - **Branch**: `main`
   - **Folder**: `/pages`
4. Click "Save"

### 2. Configure Custom Domain (Optional)

To use the custom domain `listall.app`:

1. In your domain registrar (e.g., Namecheap, GoDaddy), add DNS records:
   ```
   Type: A
   Host: @
   Value: 185.199.108.153
   
   Type: A
   Host: @
   Value: 185.199.109.153
   
   Type: A
   Host: @
   Value: 185.199.110.153
   
   Type: A
   Host: @
   Value: 185.199.111.153
   
   Type: CNAME
   Host: www
   Value: chmc.github.io
   ```

2. In GitHub Pages settings, add your custom domain: `listall.app`

3. Enable "Enforce HTTPS" (recommended)

4. Wait for DNS propagation (can take up to 24 hours)

### 3. Verify Deployment

After enabling GitHub Pages, your site will be available at:
- Default: https://chmc.github.io/listall/
- Custom domain (if configured): https://listall.app/

## Local Development

To preview the website locally:

```bash
# Option 1: Using Python's built-in HTTP server
cd pages
python3 -m http.server 8000
# Open http://localhost:8000 in your browser

# Option 2: Using Node.js http-server
npm install -g http-server
cd pages
http-server
# Open http://localhost:8080 in your browser
```

## Updating Content

### To update the main page:
Edit `index.html` and commit changes to the `main` branch.

### To update privacy policy:
Edit `privacy.html` and commit changes.

### To update support/FAQ:
Edit `support.html` and commit changes.

Changes will be automatically deployed to GitHub Pages within a few minutes.

## SEO Optimization

The website includes:
- ✅ Semantic HTML5 structure
- ✅ Meta descriptions and keywords
- ✅ Open Graph tags for social sharing
- ✅ Twitter Card metadata
- ✅ Mobile-responsive design
- ✅ Fast loading times (no external dependencies)

## Assets Needed

To complete the website, add these assets:

1. **App Icon** - Place at `assets/app-icon.png` (1024x1024)
2. **Screenshots** - Place in `assets/screenshots/` directory
3. **OG Image** - Social sharing preview at `assets/og-image.png` (1200x630)
4. **Twitter Image** - Twitter card preview at `assets/twitter-image.png` (1200x675)

## Browser Support

The website supports:
- Safari (iOS and macOS)
- Chrome
- Firefox
- Edge
- Mobile browsers (iOS Safari, Chrome Mobile)

## Performance

The website is optimized for:
- Fast loading (no external CSS/JS frameworks)
- Mobile-first responsive design
- Accessibility (semantic HTML, ARIA labels)
- SEO (proper meta tags, structured data)

## Maintenance

Regular updates needed:
- [ ] Update screenshots when UI changes
- [ ] Update privacy policy when features change
- [ ] Add new FAQs based on user feedback
- [ ] Update App Store links when published
- [ ] Keep feature descriptions current

## License

The website content is part of the ListAll project and is licensed under GPL-3.0-or-later.

---

**Note**: Replace placeholder App Store links with actual links once the app is published.
