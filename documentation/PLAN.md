# Plan: Fix gradient canvas gravity leak in framing_helper.rb

## Status: Completed

## Root cause

ImageMagick `-gravity` is sticky state. `+repage` does NOT reset it — it only resets virtual canvas offset. The `-gravity center` used for cropping the square gradient to target dimensions leaked into all subsequent `-geometry +X+Y -composite` operations, shifting content relative to canvas center instead of top-left.

## Fix applied

**File: `fastlane/lib/framing_helper.rb`**, `gradient_canvas_args` method

Added `"+gravity"` (ImageMagick-idiomatic reset using plus prefix) as the last element after `+repage` to explicitly reset gravity after the crop.

## Secondary cleanup

Removed vestigial `gravity: 'center'` from `DEFAULT_OPTIONS` — it was never read anywhere and created confusion.
