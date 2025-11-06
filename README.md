[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](./LICENSE)
[![CI](https://github.com/chmc/listall/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/chmc/listall/actions/workflows/ci.yml)

TB

## Development Setup

### Local Testing with Fastlane

To test Fastlane lanes locally (beta uploads, App Store Connect authentication, etc.), you'll need App Store Connect API credentials.

1. **Create your local environment file:**
   ```bash
   cp .env.template .env
   ```

2. **Fill in your App Store Connect API key details** in `.env`:
   - Get your API key from [App Store Connect](https://appstoreconnect.apple.com) > Users and Access > Integrations > Keys > App Store Connect API > Team Keys
   - Required role: `App Manager`
   - Generate base64 encoding: `base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'`

3. **Install dependencies and test:**
   ```bash
   bundle install
   bundle exec fastlane asc_dry_run  # Verify App Store Connect auth
   ```

**Note:** Fastlane automatically loads `.env` files from your project root. The `.env` file is gitignored and will never be committed. Only `.env.template` is tracked in the repository.

### Available Fastlane Lanes

- `bundle exec fastlane test` — Run tests (mirrors CI)
- `bundle exec fastlane test_scan` — Run tests via Fastlane Scan
- `bundle exec fastlane asc_dry_run` — Verify App Store Connect authentication
- `bundle exec fastlane beta` — Build and upload to TestFlight (requires ASC API key)
- `bundle exec fastlane release` — Deliver metadata to App Store (requires ASC API key)

## License
ListAll is licensed under the GNU General Public License v3.0 or later (GPL-3.0-or-later).  
See [LICENSE](./LICENSE) for the full text and [COPYRIGHT](./COPYRIGHT) for ownership details.
