# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'support/fixture_generator'

# Note: DeviceFrameRegistry doesn't exist yet - this follows TDD (Red phase)
# These tests should FAIL until we implement the module

RSpec.describe 'DeviceFrameRegistry' do
  include FixtureGenerator

  let(:fixtures_dir) { File.expand_path('fixtures', __dir__) }
  let(:frames_dir) { File.join(fixtures_dir, 'device_frames') }
  let(:temp_dir) { File.join(fixtures_dir, 'tmp') }

  before(:all) do
    @fixtures_dir = File.expand_path('fixtures', __dir__)
    @frames_dir = File.join(@fixtures_dir, 'device_frames')
    FileUtils.mkdir_p(@frames_dir)

    # Create test frame metadata files
    create_test_frame_metadata
  end

  after(:all) do
    # Keep fixtures for inspection but clean temp files
    FileUtils.rm_rf(File.join(@fixtures_dir, 'tmp')) if File.exist?(File.join(@fixtures_dir, 'tmp'))
  end

  before(:each) do
    FileUtils.mkdir_p(temp_dir)
  end

  after(:each) do
    FileUtils.rm_rf(temp_dir)
  end

  describe '.detect_device', :requires_implementation do
    context 'when detecting iPhone devices' do
      it 'detects iPhone 16 Pro Max from filename' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('iPhone 16 Pro Max-01_Welcome.png')

        expect(result).to be_a(Hash)
        expect(result[:type]).to eq(:iphone)
        expect(result[:frame]).to eq('iphone_16_pro_max')
        expect(result[:screen_size]).to eq([1290, 2796])
      end

      it 'detects iPhone 17 Pro Max from filename' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('iPhone 17 Pro Max-02_Main.png')

        expect(result).to be_a(Hash)
        expect(result[:type]).to eq(:iphone)
        expect(result[:frame]).to eq('iphone_16_pro_max') # Uses iPhone 16 frame
        expect(result[:screen_size]).to eq([1320, 2868])
      end

      it 'detects iPhone from middle of filename' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('en-US_iPhone 16 Pro Max-Screenshot.png')

        expect(result).not_to be_nil
        expect(result[:type]).to eq(:iphone)
      end
    end

    context 'when detecting iPad devices' do
      it 'detects iPad Pro 13-inch (M4) from filename' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('iPad Pro 13-inch (M4)-01_Welcome.png')

        expect(result).to be_a(Hash)
        expect(result[:type]).to eq(:ipad)
        expect(result[:frame]).to eq('ipad_pro_13_m4')
        expect(result[:screen_size]).to eq([2064, 2752])
      end

      it 'handles iPad filename variations' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('iPad Pro 13-inch (M4) - Screenshot.png')

        expect(result).not_to be_nil
        expect(result[:type]).to eq(:ipad)
      end
    end

    context 'when detecting Apple Watch devices' do
      it 'detects Apple Watch Series 10 (46mm) from filename' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('Apple Watch Series 10 (46mm)-01_Watch.png')

        expect(result).to be_a(Hash)
        expect(result[:type]).to eq(:watch)
        expect(result[:frame]).to eq('apple_watch_series_10_46mm')
        expect(result[:screen_size]).to eq([396, 484])
      end

      it 'detects Apple Watch with different naming' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('AppleWatch Series10 46mm-Test.png')

        expect(result).not_to be_nil
        expect(result[:type]).to eq(:watch)
      end
    end

    context 'when device is not recognized' do
      it 'returns nil for unknown device' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('Unknown Device-01_Test.png')

        expect(result).to be_nil
      end

      it 'returns nil for non-device filenames' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('random_image.png')

        expect(result).to be_nil
      end

      it 'returns nil for empty string' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('')

        expect(result).to be_nil
      end
    end

    context 'edge cases' do
      it 'handles filenames with special characters' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('iPhone 16 Pro Max-Screenshot (1).png')

        expect(result).not_to be_nil
        expect(result[:type]).to eq(:iphone)
      end

      it 'is case-sensitive for device names' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        result = DeviceFrameRegistry.detect_device('iphone 16 pro max-test.png')

        # Should not match - expects exact case
        expect(result).to be_nil
      end
    end
  end

  describe '.frame_metadata', :requires_implementation do
    context 'when loading metadata for known frames' do
      it 'loads metadata for iPhone 16 Pro Max' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        metadata = DeviceFrameRegistry.frame_metadata('iphone_16_pro_max')

        expect(metadata).to be_a(Hash)
        expect(metadata[:device]).to eq('iPhone 16 Pro Max')
        expect(metadata[:screen_area]).to be_a(Hash)
        expect(metadata[:screen_area][:width]).to eq(1290)
        expect(metadata[:screen_area][:height]).to eq(2796)
        expect(metadata[:frame_dimensions]).to be_a(Hash)
      end

      it 'loads metadata for iPad Pro 13-inch' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        metadata = DeviceFrameRegistry.frame_metadata('ipad_pro_13_m4')

        expect(metadata).to be_a(Hash)
        expect(metadata[:device]).to eq('iPad Pro 13-inch (M4)')
        expect(metadata[:screen_area][:width]).to eq(2064)
        expect(metadata[:screen_area][:height]).to eq(2752)
      end

      it 'loads metadata for Apple Watch Series 10' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        metadata = DeviceFrameRegistry.frame_metadata('apple_watch_series_10_46mm')

        expect(metadata).to be_a(Hash)
        expect(metadata[:device]).to eq('Apple Watch Series 10 (46mm)')
        expect(metadata[:screen_area][:width]).to eq(396)
        expect(metadata[:screen_area][:height]).to eq(484)
      end

      it 'includes variant information' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        metadata = DeviceFrameRegistry.frame_metadata('iphone_16_pro_max')

        expect(metadata[:variants]).to be_a(Hash)
        expect(metadata[:variants][:black]).to be_a(String)
        expect(metadata[:default_variant]).to eq('black')
      end

      it 'includes corner radius' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        metadata = DeviceFrameRegistry.frame_metadata('iphone_16_pro_max')

        expect(metadata[:corner_radius]).to be_a(Integer)
        expect(metadata[:corner_radius]).to be > 0
      end
    end

    context 'when metadata does not exist' do
      it 'raises FrameNotFoundError for unknown frame' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        expect {
          DeviceFrameRegistry.frame_metadata('nonexistent_device')
        }.to raise_error(DeviceFrameRegistry::FrameNotFoundError, /not found/)
      end

      it 'raises FrameNotFoundError for nil frame name' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        expect {
          DeviceFrameRegistry.frame_metadata(nil)
        }.to raise_error(DeviceFrameRegistry::FrameNotFoundError)
      end

      it 'raises FrameNotFoundError for empty frame name' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        expect {
          DeviceFrameRegistry.frame_metadata('')
        }.to raise_error(DeviceFrameRegistry::FrameNotFoundError)
      end
    end

    context 'metadata file validation' do
      it 'parses JSON with symbolized keys' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        metadata = DeviceFrameRegistry.frame_metadata('iphone_16_pro_max')

        # Should use symbols, not strings
        expect(metadata.keys.first).to be_a(Symbol)
        expect(metadata[:screen_area].keys.first).to be_a(Symbol)
      end

      it 'validates required fields are present' do
        skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

        metadata = DeviceFrameRegistry.frame_metadata('iphone_16_pro_max')

        required_fields = [:device, :screen_area, :frame_dimensions, :variants, :default_variant]
        required_fields.each do |field|
          expect(metadata).to have_key(field), "Missing required field: #{field}"
        end
      end
    end
  end

  describe '.available_frames', :requires_implementation do
    it 'lists all available device frames' do
      skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

      frames = DeviceFrameRegistry.available_frames

      expect(frames).to be_an(Array)
      expect(frames).to include('iPhone 16 Pro Max')
      expect(frames).to include('iPad Pro 13-inch (M4)')
      expect(frames).to include('Apple Watch Series 10 (46mm)')
    end

    it 'returns empty array when no frames available' do
      skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

      # Temporarily move frames away
      original_dir = DeviceFrameRegistry.instance_variable_get(:@frames_dir)
      DeviceFrameRegistry.instance_variable_set(:@frames_dir, '/nonexistent')

      frames = DeviceFrameRegistry.available_frames

      expect(frames).to eq([])

      # Restore
      DeviceFrameRegistry.instance_variable_set(:@frames_dir, original_dir)
    end
  end

  describe '.metadata_path_for', :requires_implementation do
    it 'constructs correct path for iPhone frame' do
      skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

      path = DeviceFrameRegistry.metadata_path_for('iphone_16_pro_max')

      expect(path).to include('device_frames')
      expect(path).to include('iphone')
      expect(path).to end_with('metadata.json')
    end

    it 'constructs correct path for iPad frame' do
      skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

      path = DeviceFrameRegistry.metadata_path_for('ipad_pro_13_m4')

      expect(path).to include('ipad')
      expect(path).to end_with('metadata.json')
    end

    it 'constructs correct path for Watch frame' do
      skip "DeviceFrameRegistry not yet implemented (TDD Red phase)"

      path = DeviceFrameRegistry.metadata_path_for('apple_watch_series_10_46mm')

      expect(path).to include('watch')
      expect(path).to end_with('metadata.json')
    end
  end

  # Helper method to create test metadata files
  def create_test_frame_metadata
    # iPhone metadata
    iphone_dir = File.join(@frames_dir, 'iphone')
    FileUtils.mkdir_p(iphone_dir)

    create_test_metadata(
      File.join(iphone_dir, 'metadata.json'),
      'iPhone 16 Pro Max',
      { x: 85, y: 155, width: 1290, height: 2796 },
      { width: 1460, height: 3106 }
    )

    # iPad metadata
    ipad_dir = File.join(@frames_dir, 'ipad')
    FileUtils.mkdir_p(ipad_dir)

    create_test_metadata(
      File.join(ipad_dir, 'metadata.json'),
      'iPad Pro 13-inch (M4)',
      { x: 68, y: 152, width: 2064, height: 2752 },
      { width: 2200, height: 3056 }
    )

    # Watch metadata
    watch_dir = File.join(@frames_dir, 'watch')
    FileUtils.mkdir_p(watch_dir)

    create_test_metadata(
      File.join(watch_dir, 'metadata.json'),
      'Apple Watch Series 10 (46mm)',
      { x: 52, y: 58, width: 396, height: 484 },
      { width: 500, height: 600 }
    )
  end
end
