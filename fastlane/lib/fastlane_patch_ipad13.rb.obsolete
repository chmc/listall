# Monkey-patch Fastlane to support iPad Pro 13" (M4) screenshot dimensions
# This adds the 2064x2752 resolution that Apple requires for iPad 13" but Fastlane doesn't support yet
# See: https://github.com/fastlane/fastlane/issues/22030

require 'deliver/app_screenshot'
require 'spaceship/connect_api/models/app_screenshot_set'

module Deliver
  class AppScreenshot
    module ScreenSize
      # iPad Pro 13" (M4) - not yet in Fastlane 2.228.0
      IOS_IPAD_PRO_13 = "iOS-iPad-Pro-13" unless const_defined?(:IOS_IPAD_PRO_13)
    end

    class << self
      # Override devices to include iPad 13" resolution
      alias_method :original_devices_without_ipad13, :devices

      def devices
        result = original_devices_without_ipad13
        # Add iPad Pro 13" dimensions if not already present
        result[ScreenSize::IOS_IPAD_PRO_13] ||= [
          [2752, 2064],  # landscape
          [2064, 2752]   # portrait
        ]
        result
      end
    end

    # Override device_type to include iPad 13"
    alias_method :original_device_type_without_ipad13, :device_type

    def device_type
      if self.screen_size == ScreenSize::IOS_IPAD_PRO_13
        return Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPAD_PRO_3GEN_129
      end
      original_device_type_without_ipad13
    end

    # Override formatted_name to include iPad 13"
    alias_method :original_formatted_name_without_ipad13, :formatted_name

    def formatted_name
      if self.screen_size == ScreenSize::IOS_IPAD_PRO_13
        return "iPad Pro 13-inch (M4)"
      end
      original_formatted_name_without_ipad13
    end
  end
end

UI.message("✅ Fastlane patched: Added iPad Pro 13\" (2064x2752) support") if defined?(UI)
