# RSpec Test Suite for Screenshot Framing

This directory contains comprehensive RSpec tests for the custom screenshot framing solution, following Test-Driven Development (TDD) methodology.

## Structure

```
spec/
├── spec_helper.rb                    # RSpec configuration and setup
├── device_frame_registry_spec.rb     # Tests for device detection and metadata
├── framing_helper_spec.rb            # Tests for screenshot framing operations
├── support/
│   └── fixture_generator.rb          # Helper methods for creating test fixtures
├── fixtures/
│   ├── screenshots_normalized/       # Test screenshots (generated)
│   │   ├── en-US/
│   │   └── fi/
│   └── device_frames/               # Test device frames (generated)
│       ├── iphone/
│       ├── ipad/
│       └── watch/
└── README.md                         # This file
```

## Requirements

- **Ruby 3.2+**: Already installed with Fastlane
- **RSpec 3.x**: Install with `bundle install` or `gem install rspec`
- **ImageMagick 7.x**: Required for image operations (`brew install imagemagick`)

Verify requirements:
```bash
ruby --version          # Should be 3.2+
bundle exec rspec --version  # Should be 3.x
magick --version        # Should be ImageMagick 7.x
```

## Running Tests

### Run All Tests
```bash
cd fastlane
bundle exec rspec spec/ --format documentation
```

### Run Specific Test File
```bash
# Device registry tests
bundle exec rspec spec/device_frame_registry_spec.rb

# Framing helper tests
bundle exec rspec spec/framing_helper_spec.rb
```

### Run Specific Test
```bash
# By line number
bundle exec rspec spec/framing_helper_spec.rb:42

# By description pattern
bundle exec rspec spec/ -e "frames all screenshots"
```

### Run with Different Output Formats
```bash
# Progress dots (default)
bundle exec rspec spec/

# Documentation format (detailed)
bundle exec rspec spec/ --format documentation

# JSON format (for CI)
bundle exec rspec spec/ --format json --out test_results.json
```

### Run Only Tests That Aren't Skipped
```bash
# Most tests are currently skipped (TDD Red phase - implementation pending)
bundle exec rspec spec/ --tag ~requires_implementation
```

## TDD Workflow

This test suite follows the **Red-Green-Refactor** cycle:

### Phase 1: RED (Current Phase) ✅
Tests are written but **all tests are skipped** with:
```ruby
skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"
```

This is intentional! The tests define the expected behavior before implementation.

### Phase 2: GREEN (Next Phase)
1. Remove `skip` from one test
2. Run the test - it should **FAIL** (RED)
3. Implement minimal code to make it **PASS** (GREEN)
4. Repeat for next test

### Phase 3: REFACTOR
Once tests pass, improve the code:
- Extract duplicated logic
- Add documentation
- Optimize performance
- Keep tests green

## Test Coverage

### DeviceFrameRegistry Tests (43 tests)
- ✅ Device detection from filenames (iPhone, iPad, Watch)
- ✅ Metadata loading and parsing
- ✅ Error handling for missing frames
- ✅ Edge cases (special characters, case sensitivity)
- ✅ Available frames listing

### FramingHelper Tests (38 tests)
- ✅ Single screenshot framing
- ✅ Batch processing multiple screenshots
- ✅ Multi-locale support
- ✅ Background color customization
- ✅ Dimension validation
- ✅ Error handling and resilience
- ✅ Skip existing files option
- ✅ Output directory creation

**Total: 81 comprehensive tests**

## Test Fixtures

Fixtures are automatically generated when tests run:

### Screenshots
- Created with ImageMagick (`magick -size WxH xc:#COLOR output.png`)
- Exact dimensions matching App Store requirements
- Different colors to distinguish test cases

### Device Frames
- Simulated bezels with transparent centers
- Correct dimensions for each device type
- Metadata JSON files with screen area coordinates

### Manual Fixture Creation
If you need to manually create fixtures:

```ruby
require_relative 'spec/support/fixture_generator'
include FixtureGenerator

# Create a test screenshot
create_test_screenshot('path/to/output.png', 1290, 2796, '#FFFFFF')

# Create a test frame
create_test_frame('path/to/frame.png', 1460, 3106,
  { x: 85, y: 155, width: 1290, height: 2796 })

# Create metadata
create_test_metadata('path/to/metadata.json',
  'iPhone 16 Pro Max',
  { x: 85, y: 155, width: 1290, height: 2796 },
  { width: 1460, height: 3106 })
```

## CI Integration

### GitHub Actions
Add to `.github/workflows/screenshots.yml`:

```yaml
test-framing:
  name: Test Screenshot Framing
  runs-on: macos-14
  steps:
    - uses: actions/checkout@v4

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.2'
        bundler-cache: true

    - name: Install ImageMagick
      run: brew install imagemagick

    - name: Run RSpec tests
      run: |
        cd fastlane
        bundle exec rspec spec/ --format documentation --format json --out test_results.json

    - name: Upload test results
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: test-results
        path: fastlane/test_results.json
```

### Fastlane Lane
Run tests via Fastlane:

```ruby
desc "Run framing tests"
lane :test_framing do
  sh("cd #{__dir__} && bundle exec rspec spec/ --format documentation")
end
```

Then run:
```bash
bundle exec fastlane test_framing
```

## Debugging Tests

### View Detailed Failures
```bash
bundle exec rspec spec/ --format documentation --fail-fast
```

### Check Test Fixtures
```bash
# List generated fixtures
ls -lR fastlane/spec/fixtures/

# Check image dimensions
identify fastlane/spec/fixtures/screenshots_normalized/en-US/*.png

# Verify PNG integrity
identify -regard-warnings fastlane/spec/fixtures/device_frames/*/*.png
```

### Test Individual Operations
```ruby
# In IRB or test file
require_relative 'spec/support/fixture_generator'
include FixtureGenerator

# Test screenshot creation
create_test_screenshot('/tmp/test.png', 1290, 2796, '#FF0000')
system("open /tmp/test.png")  # View on macOS

# Check dimensions
dims = get_image_dimensions('/tmp/test.png')
puts "Dimensions: #{dims[:width]}x#{dims[:height]}"

# Check pixel color
color = get_pixel_color('/tmp/test.png', 0, 0)
puts "Corner color: #{color}"
```

## Performance

Test suite performance benchmarks:

| Test Group | Tests | Time (est.) |
|-----------|-------|-------------|
| DeviceFrameRegistry | 43 | ~0.5s |
| FramingHelper (unit) | 25 | ~2.0s |
| FramingHelper (integration) | 13 | ~5.0s |
| **Total** | **81** | **~7.5s** |

*Actual time depends on ImageMagick performance and system resources*

## Troubleshooting

### ImageMagick Not Found
```bash
# Install ImageMagick
brew install imagemagick

# Verify installation
which magick
magick --version
```

### Tests Are All Skipped
This is expected during TDD Red phase! Tests are intentionally skipped until implementation begins.

To see all tests:
```bash
bundle exec rspec spec/ --format documentation --dry-run
```

### Bundle Install Issues
```bash
# Install bundler if needed
gem install bundler

# Install dependencies
cd fastlane
bundle install

# Update RSpec
bundle update rspec
```

### Fixture Generation Fails
Check ImageMagick is working:
```bash
# Simple test
magick -size 100x100 xc:#FF0000 /tmp/test.png
open /tmp/test.png  # Should show red square

# Check for errors
magick -size 100x100 xc:#FF0000 /tmp/test.png 2>&1
```

## Next Steps

1. **Remove skip from first test** in `device_frame_registry_spec.rb`
2. **Run test** - it should FAIL (red)
3. **Implement DeviceFrameRegistry** to make test pass (green)
4. **Refactor** and move to next test
5. **Repeat** until all tests pass

## Contributing

When adding new tests:

1. Follow AAA pattern (Arrange-Act-Assert)
2. Use descriptive test names: `test_<what>_<scenario>_<expected>`
3. Make each test independent (no shared state)
4. Use `skip` for tests requiring unimplemented features
5. Tag tests with `:requires_imagemagick` if they need ImageMagick
6. Add test fixtures to `fixtures/` directory
7. Update this README with new test coverage

## License

Tests are part of the ListAll project.
