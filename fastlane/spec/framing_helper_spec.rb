# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'support/fixture_generator'

# Note: FramingHelper doesn't exist yet - this follows TDD (Red phase)
# These tests should FAIL until we implement the module

RSpec.describe 'FramingHelper' do
  include FixtureGenerator

  let(:fixtures_dir) { File.expand_path('fixtures', __dir__) }
  let(:screenshots_dir) { File.join(fixtures_dir, 'screenshots_normalized') }
  let(:frames_dir) { File.join(fixtures_dir, 'device_frames') }
  let(:temp_dir) { File.join(fixtures_dir, 'tmp') }
  let(:output_dir) { File.join(temp_dir, 'framed') }

  before(:all) do
    @fixtures_dir = File.expand_path('fixtures', __dir__)
    @screenshots_dir = File.join(@fixtures_dir, 'screenshots_normalized')
    @frames_dir = File.join(@fixtures_dir, 'device_frames')

    # Create directory structure
    FileUtils.mkdir_p(@screenshots_dir)
    FileUtils.mkdir_p(@frames_dir)

    # Create test frame assets (these persist across all tests)
    create_test_frames
  end

  before(:each) do
    FileUtils.mkdir_p(temp_dir)
    FileUtils.mkdir_p(output_dir)

    # Create fresh test screenshots for each test
    create_test_screenshots
  end

  after(:each) do
    FileUtils.rm_rf(temp_dir)
  end

  after(:all) do
    # Clean up screenshots but keep frames
    FileUtils.rm_rf(@screenshots_dir) if File.exist?(@screenshots_dir)
  end

  describe '.frame_screenshot', :requires_implementation, :requires_imagemagick do
    let(:screenshot_path) { File.join(screenshots_dir, 'en-US', 'iPhone 16 Pro Max-01_Welcome.png') }
    let(:output_path) { File.join(output_dir, 'output_framed.png') }
    let(:device_spec) do
      {
        type: :iphone,
        frame: 'iphone_16_pro_max',
        screen_size: [1290, 2796]
      }
    end

    context 'basic framing operation' do
      it 'creates framed output file' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        expect(File.exist?(output_path)).to be false

        FramingHelper.frame_screenshot(screenshot_path, output_path, device_spec)

        expect(File.exist?(output_path)).to be true
        expect(valid_png?(output_path)).to be true
      end

      it 'framed image is larger than input screenshot' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        FramingHelper.frame_screenshot(screenshot_path, output_path, device_spec)

        input_dims = get_image_dimensions(screenshot_path)
        output_dims = get_image_dimensions(output_path)

        expect(output_dims[:width]).to be > input_dims[:width], "Output width should be larger"
        expect(output_dims[:height]).to be > input_dims[:height], "Output height should be larger"
      end

      it 'creates output directory if it does not exist' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        nested_output = File.join(temp_dir, 'nested', 'deep', 'output.png')
        expect(File.directory?(File.dirname(nested_output))).to be false

        FramingHelper.frame_screenshot(screenshot_path, nested_output, device_spec)

        expect(File.exist?(nested_output)).to be true
      end

      it 'overwrites existing output file' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        # Create existing file
        File.write(output_path, 'old content')
        old_size = File.size(output_path)

        FramingHelper.frame_screenshot(screenshot_path, output_path, device_spec)

        new_size = File.size(output_path)
        expect(new_size).to be > old_size
        expect(valid_png?(output_path)).to be true
      end
    end

    context 'background color options' do
      it 'applies default background color' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        FramingHelper.frame_screenshot(screenshot_path, output_path, device_spec)

        # Check corner pixel for background color
        corner_color = get_pixel_color(output_path, 0, 0)
        expect(corner_color).not_to be_nil
      end

      it 'applies custom background color' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        FramingHelper.frame_screenshot(
          screenshot_path,
          output_path,
          device_spec,
          background: '#FF0000'
        )

        corner_color = get_pixel_color(output_path, 0, 0)
        expect(corner_color).to match(/red|#FF0000/i)
      end

      it 'supports hex color codes' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        FramingHelper.frame_screenshot(
          screenshot_path,
          output_path,
          device_spec,
          background: '#0E1117'
        )

        expect(File.exist?(output_path)).to be true
      end
    end

    context 'error handling' do
      it 'raises ScreenshotNotFoundError for missing screenshot' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        nonexistent = File.join(screenshots_dir, 'nonexistent.png')

        expect {
          FramingHelper.frame_screenshot(nonexistent, output_path, device_spec)
        }.to raise_error(FramingHelper::ScreenshotNotFoundError, /not found/)
      end

      it 'raises DimensionMismatchError for wrong screenshot size' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        wrong_size_path = File.join(screenshots_dir, 'wrong_size.png')
        create_test_screenshot(wrong_size_path, 800, 600, '#FFFFFF')

        expect {
          FramingHelper.frame_screenshot(wrong_size_path, output_path, device_spec)
        }.to raise_error(FramingHelper::DimensionMismatchError, /Expected 1290x2796/)
      end

      it 'raises FrameAssetMissingError when frame asset does not exist' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        bad_spec = device_spec.merge(frame: 'nonexistent_frame')

        expect {
          FramingHelper.frame_screenshot(screenshot_path, output_path, bad_spec)
        }.to raise_error(FramingHelper::FrameAssetMissingError, /Frame asset not found/)
      end

      it 'raises ImageMagickError if composite command fails' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        # Use invalid output path to force failure
        invalid_output = '/invalid/path/that/cannot/be/written/output.png'

        expect {
          FramingHelper.frame_screenshot(screenshot_path, invalid_output, device_spec)
        }.to raise_error(FramingHelper::ImageMagickError)
      end
    end

    context 'dimension validation' do
      it 'validates screenshot matches expected screen_size exactly' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        # Create screenshot with slightly wrong dimensions
        wrong_height = File.join(screenshots_dir, 'wrong_height.png')
        create_test_screenshot(wrong_height, 1290, 2800, '#FFFFFF') # Height off by 4px

        expect {
          FramingHelper.frame_screenshot(wrong_height, output_path, device_spec)
        }.to raise_error(FramingHelper::DimensionMismatchError, /got 1290x2800/)
      end

      it 'accepts screenshot with exact dimensions' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        # screenshot_path is already correct size
        expect {
          FramingHelper.frame_screenshot(screenshot_path, output_path, device_spec)
        }.not_to raise_error
      end
    end

    context 'different device types' do
      it 'frames iPad screenshots' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        ipad_screenshot = File.join(screenshots_dir, 'en-US', 'iPad Pro 13-inch (M4)-01_Welcome.png')
        ipad_output = File.join(output_dir, 'ipad_framed.png')
        ipad_spec = {
          type: :ipad,
          frame: 'ipad_pro_13_m4',
          screen_size: [2064, 2752]
        }

        FramingHelper.frame_screenshot(ipad_screenshot, ipad_output, ipad_spec)

        expect(File.exist?(ipad_output)).to be true
        output_dims = get_image_dimensions(ipad_output)
        expect(output_dims[:width]).to be > 2064
      end

      it 'frames Apple Watch screenshots' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        watch_screenshot = File.join(screenshots_dir, 'en-US', 'Apple Watch Series 10 (46mm)-01_Watch.png')
        watch_output = File.join(output_dir, 'watch_framed.png')
        watch_spec = {
          type: :watch,
          frame: 'apple_watch_series_7plus_45mm',
          screen_size: [396, 484]
        }

        FramingHelper.frame_screenshot(watch_screenshot, watch_output, watch_spec)

        expect(File.exist?(watch_output)).to be true
        output_dims = get_image_dimensions(watch_output)
        expect(output_dims[:width]).to be > 396
      end
    end
  end

  describe '.frame_all_screenshots', :requires_implementation, :requires_imagemagick do
    let(:input_dir) { File.join(screenshots_dir, 'en-US') }

    context 'batch processing' do
      it 'frames all screenshots in directory' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        results = FramingHelper.frame_all_screenshots(input_dir, output_dir)

        expect(results[:processed]).to eq(3) # iPhone + iPad + Watch
        expect(results[:errors]).to be_empty
        expect(Dir.glob(File.join(output_dir, '*_framed.png')).count).to eq(3)
      end

      it 'returns correct result structure' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        results = FramingHelper.frame_all_screenshots(input_dir, output_dir)

        expect(results).to have_key(:processed)
        expect(results).to have_key(:skipped)
        expect(results).to have_key(:errors)
        expect(results[:processed]).to be_a(Integer)
        expect(results[:skipped]).to be_a(Integer)
        expect(results[:errors]).to be_an(Array)
      end

      it 'appends _framed suffix to output filenames' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        FramingHelper.frame_all_screenshots(input_dir, output_dir)

        output_files = Dir.glob(File.join(output_dir, '*.png')).map { |f| File.basename(f) }
        expect(output_files).to all(match(/_framed\.png$/))
      end

      it 'preserves original filename structure' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        FramingHelper.frame_all_screenshots(input_dir, output_dir)

        expect(File.exist?(File.join(output_dir, 'iPhone 16 Pro Max-01_Welcome_framed.png'))).to be true
        expect(File.exist?(File.join(output_dir, 'iPad Pro 13-inch (M4)-01_Welcome_framed.png'))).to be true
      end
    end

    context 'skip existing option' do
      it 'skips already framed screenshots when option enabled' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        # First pass
        results1 = FramingHelper.frame_all_screenshots(input_dir, output_dir)
        expect(results1[:processed]).to eq(3)

        first_file = Dir.glob(File.join(output_dir, '*.png')).first
        first_mtime = File.mtime(first_file)

        # Wait to ensure mtime would change
        sleep(0.1)

        # Second pass with skip_existing
        results2 = FramingHelper.frame_all_screenshots(input_dir, output_dir, skip_existing: true)

        expect(results2[:skipped]).to eq(3)
        expect(results2[:processed]).to eq(0)

        # Verify file wasn't modified
        second_mtime = File.mtime(first_file)
        expect(first_mtime).to eq(second_mtime)
      end

      it 're-processes screenshots when option disabled' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        # First pass
        FramingHelper.frame_all_screenshots(input_dir, output_dir)
        first_file = Dir.glob(File.join(output_dir, '*.png')).first
        first_mtime = File.mtime(first_file)

        sleep(0.1)

        # Second pass without skip_existing
        results = FramingHelper.frame_all_screenshots(input_dir, output_dir, skip_existing: false)

        expect(results[:processed]).to eq(3)
        expect(results[:skipped]).to eq(0)

        # Verify file was modified
        second_mtime = File.mtime(first_file)
        expect(second_mtime).to be > first_mtime
      end
    end

    context 'error handling and resilience' do
      it 'handles errors gracefully and continues processing' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        # Add a corrupted file
        corrupted_path = File.join(input_dir, 'iPhone 16 Pro Max-corrupted.png')
        create_corrupted_file(corrupted_path, 'not a png')

        results = FramingHelper.frame_all_screenshots(input_dir, output_dir)

        # Should process valid files and record error for corrupted one
        expect(results[:processed]).to be >= 2
        expect(results[:errors].count).to be >= 1
        expect(results[:errors].first).to have_key(:file)
        expect(results[:errors].first).to have_key(:error)
      end

      it 'skips files that cannot be detected' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        # Add a file that won't match device detection
        unknown_file = File.join(input_dir, 'Unknown Device-test.png')
        create_test_screenshot(unknown_file, 1290, 2796, '#FFFFFF')

        results = FramingHelper.frame_all_screenshots(input_dir, output_dir)

        # Should skip unknown device file
        expect(results[:processed]).to eq(3) # Only known devices
      end

      it 'skips files already containing _framed in name' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        # Add a file that looks already framed
        already_framed = File.join(input_dir, 'iPhone 16 Pro Max-01_Welcome_framed.png')
        create_test_screenshot(already_framed, 1290, 2796, '#FFFFFF')

        results = FramingHelper.frame_all_screenshots(input_dir, output_dir)

        # Should not process files with _framed in name
        output_files = Dir.glob(File.join(output_dir, '*.png'))
        expect(output_files).not_to include(match(/_framed_framed\.png$/))
      end

      it 'provides detailed error messages' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        corrupted_path = File.join(input_dir, 'iPhone 16 Pro Max-bad.png')
        create_corrupted_file(corrupted_path)

        results = FramingHelper.frame_all_screenshots(input_dir, output_dir)

        expect(results[:errors]).not_to be_empty
        error = results[:errors].first
        expect(error[:file]).to include('iPhone 16 Pro Max-bad.png')
        expect(error[:error]).to be_a(String)
        expect(error[:error].length).to be > 10 # Non-empty error message
      end
    end

    context 'empty directory handling' do
      it 'handles empty directory gracefully' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        empty_dir = File.join(screenshots_dir, 'empty')
        FileUtils.mkdir_p(empty_dir)

        results = FramingHelper.frame_all_screenshots(empty_dir, output_dir)

        expect(results[:processed]).to eq(0)
        expect(results[:errors]).to be_empty
      end

      it 'handles non-existent input directory' do
        skip "FramingHelper not yet implemented (TDD Red phase)"

        nonexistent = File.join(screenshots_dir, 'nonexistent')

        expect {
          FramingHelper.frame_all_screenshots(nonexistent, output_dir)
        }.not_to raise_error # Should handle gracefully
      end
    end
  end

  describe '.frame_all_locales', :requires_implementation, :requires_imagemagick do
    let(:input_root) { screenshots_dir }

    before(:each) do
      # Create fi locale with one screenshot
      fi_dir = File.join(screenshots_dir, 'fi')
      FileUtils.mkdir_p(fi_dir)
      create_test_screenshot(
        File.join(fi_dir, 'iPhone 16 Pro Max-01_Welcome.png'),
        1290, 2796, '#FFFFFF'
      )
    end

    it 'processes multiple locales' do
      skip "FramingHelper not yet implemented (TDD Red phase)"

      results = FramingHelper.frame_all_locales(
        input_root,
        File.join(temp_dir, 'framed'),
        locales: ['en-US', 'fi']
      )

      expect(results).to have_key('en-US')
      expect(results).to have_key('fi')
      expect(results['en-US'][:processed]).to be >= 1
      expect(results['fi'][:processed]).to be >= 1
    end

    it 'creates separate output directories for each locale' do
      skip "FramingHelper not yet implemented (TDD Red phase)"

      output_root = File.join(temp_dir, 'framed')

      FramingHelper.frame_all_locales(
        input_root,
        output_root,
        locales: ['en-US', 'fi']
      )

      expect(File.directory?(File.join(output_root, 'en-US'))).to be true
      expect(File.directory?(File.join(output_root, 'fi'))).to be true
    end

    it 'defaults to en-US and fi locales' do
      skip "FramingHelper not yet implemented (TDD Red phase)"

      results = FramingHelper.frame_all_locales(
        input_root,
        File.join(temp_dir, 'framed')
      )

      # Should process both default locales
      expect(results.keys).to include('en-US', 'fi')
    end

    it 'returns results keyed by locale' do
      skip "FramingHelper not yet implemented (TDD Red phase)"

      results = FramingHelper.frame_all_locales(
        input_root,
        File.join(temp_dir, 'framed'),
        locales: ['en-US']
      )

      expect(results['en-US']).to have_key(:processed)
      expect(results['en-US']).to have_key(:skipped)
      expect(results['en-US']).to have_key(:errors)
    end

    it 'handles missing locales gracefully' do
      skip "FramingHelper not yet implemented (TDD Red phase)"

      results = FramingHelper.frame_all_locales(
        input_root,
        File.join(temp_dir, 'framed'),
        locales: ['en-US', 'de-DE'] # de-DE doesn't exist
      )

      expect(results['en-US'][:processed]).to be > 0
      expect(results['de-DE'][:processed]).to eq(0)
    end
  end

  # Helper methods to create test fixtures
  def create_test_screenshots
    en_us_dir = File.join(screenshots_dir, 'en-US')
    FileUtils.mkdir_p(en_us_dir)

    # Create iPhone screenshot
    create_test_screenshot(
      File.join(en_us_dir, 'iPhone 16 Pro Max-01_Welcome.png'),
      1290, 2796, '#FFFFFF'
    )

    # Create iPad screenshot
    create_test_screenshot(
      File.join(en_us_dir, 'iPad Pro 13-inch (M4)-01_Welcome.png'),
      2064, 2752, '#F5F5F5'
    )

    # Create Watch screenshot (Series 10 captures normalized to Series 7+ dimensions for App Store)
    create_test_screenshot(
      File.join(en_us_dir, 'Apple Watch Series 10 (46mm)-01_Watch.png'),
      396, 484, '#EEEEEE'
    )
  end

  def create_test_frames
    # Create iPhone frame
    iphone_dir = File.join(@frames_dir, 'iphone')
    FileUtils.mkdir_p(iphone_dir)
    create_test_frame(
      File.join(iphone_dir, 'iphone_16_pro_max_black.png'),
      1460, 3106,
      { x: 85, y: 155, width: 1290, height: 2796 }
    )

    # Create iPad frame
    ipad_dir = File.join(@frames_dir, 'ipad')
    FileUtils.mkdir_p(ipad_dir)
    create_test_frame(
      File.join(ipad_dir, 'ipad_pro_13_m4_black.png'),
      2200, 3056,
      { x: 68, y: 152, width: 2064, height: 2752 }
    )

    # Create Watch frame (Series 7+ dimensions for App Store compatibility)
    watch_dir = File.join(@frames_dir, 'watch')
    FileUtils.mkdir_p(watch_dir)
    create_test_frame(
      File.join(watch_dir, 'apple_watch_series_7plus_45mm_black.png'),
      500, 596,
      { x: 52, y: 56, width: 396, height: 484 }
    )
  end
end
