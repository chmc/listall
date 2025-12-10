#!/usr/bin/env bash
set -uo pipefail

# Metadata Validation Script for ListAll
# This script checks that all required files exist and meet character limits
# Note: We don't use 'set -e' because we need to continue checking all files
# even when some checks fail, to collect all errors and warnings.

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ListAll - App Store Metadata Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Function to check file exists
check_file() {
    local file=$1
    local required=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} Found: $file"
        return 0
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}✗${NC} Missing (REQUIRED): $file"
            ((ERRORS++))
        else
            echo -e "${YELLOW}⚠${NC} Missing (optional): $file"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Function to check character count
check_char_limit() {
    local file=$1
    local limit=$2
    local name=$3
    
    if [ -f "$file" ]; then
        local count=$(wc -c < "$file" | tr -d ' ')
        if [ "$count" -le "$limit" ]; then
            echo -e "${GREEN}✓${NC} $name: $count/$limit characters"
        else
            echo -e "${RED}✗${NC} $name: $count/$limit characters (EXCEEDS LIMIT)"
            ((ERRORS++))
        fi
    fi
}

# Function to check URL accessibility
check_url() {
    local file=$1
    local name=$2

    if [ -f "$file" ]; then
        local url=$(cat "$file" | tr -d '\n' | tr -d ' ')
        echo -n "  Checking $name: $url ... "

        # Simple URL format check
        if [[ $url =~ ^https?:// ]]; then
            echo -e "${GREEN}✓${NC} Valid format"
        else
            echo -e "${RED}✗${NC} Invalid URL format"
            ((ERRORS++))
        fi
    fi
}

# Function to check JSON syntax
check_json_syntax() {
    local file=$1
    local name=$2

    if [ -f "$file" ]; then
        if python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $name: Valid JSON syntax"
        else
            echo -e "${RED}✗${NC} $name: Invalid JSON syntax"
            ((ERRORS++))
        fi
    fi
}

echo "═══════════════════════════════════════════════════════"
echo "  CHECKING REQUIRED FILES"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check core metadata files
check_file "metadata/app_info.txt" "required"
check_file "metadata/app_privacy_questionnaire.txt" "required"
check_file "metadata/SUBMISSION_GUIDE.md" "optional"
check_file "metadata/README.md" "optional"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING en-US LOCALIZATION FILES"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check en-US files
check_file "metadata/en-US/description.txt" "required"
check_file "metadata/en-US/keywords.txt" "required"
check_file "metadata/en-US/support_url.txt" "required"
check_file "metadata/en-US/privacy_policy_url.txt" "required"
check_file "metadata/en-US/release_notes.txt" "required"
check_file "metadata/en-US/promotional_text.txt" "optional"
check_file "metadata/en-US/marketing_url.txt" "optional"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING macOS METADATA"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check macOS app_info.txt (categories and age rating documentation)
check_file "metadata/macos/app_info.txt" "required"

# Check macOS age rating configuration (required by Fastlane deliver)
check_file "metadata/macos/rating_config.json" "required"

# Check macOS en-US files
check_file "metadata/macos/en-US/description.txt" "required"
check_file "metadata/macos/en-US/keywords.txt" "required"
check_file "metadata/macos/en-US/support_url.txt" "required"
check_file "metadata/macos/en-US/privacy_policy_url.txt" "required"
check_file "metadata/macos/en-US/release_notes.txt" "required"
check_file "metadata/macos/en-US/promotional_text.txt" "optional"
check_file "metadata/macos/en-US/marketing_url.txt" "optional"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING CHARACTER LIMITS (iOS)"
echo "═══════════════════════════════════════════════════════"
echo ""

check_char_limit "metadata/en-US/description.txt" 4000 "Description"
check_char_limit "metadata/en-US/keywords.txt" 100 "Keywords"
check_char_limit "metadata/en-US/release_notes.txt" 4000 "Release Notes"
check_char_limit "metadata/en-US/promotional_text.txt" 170 "Promotional Text"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING CHARACTER LIMITS (macOS)"
echo "═══════════════════════════════════════════════════════"
echo ""

check_char_limit "metadata/macos/en-US/description.txt" 4000 "macOS Description"
check_char_limit "metadata/macos/en-US/keywords.txt" 100 "macOS Keywords"
check_char_limit "metadata/macos/en-US/release_notes.txt" 4000 "macOS Release Notes"
check_char_limit "metadata/macos/en-US/promotional_text.txt" 170 "macOS Promotional Text"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING URLS (iOS)"
echo "═══════════════════════════════════════════════════════"
echo ""

check_url "metadata/en-US/support_url.txt" "Support URL"
check_url "metadata/en-US/privacy_policy_url.txt" "Privacy Policy URL"
check_url "metadata/en-US/marketing_url.txt" "Marketing URL"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING URLS (macOS)"
echo "═══════════════════════════════════════════════════════"
echo ""

check_url "metadata/macos/en-US/support_url.txt" "macOS Support URL"
check_url "metadata/macos/en-US/privacy_policy_url.txt" "macOS Privacy Policy URL"
check_url "metadata/macos/en-US/marketing_url.txt" "macOS Marketing URL"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING JSON CONFIGURATION FILES"
echo "═══════════════════════════════════════════════════════"
echo ""

check_json_syntax "metadata/macos/rating_config.json" "macOS Age Rating Config"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING APP STORE CATEGORIES & AGE RATING"
echo "═══════════════════════════════════════════════════════"
echo ""

# Function to check category/age rating in app_info.txt
check_app_info_section() {
    local file=$1
    local section=$2
    local platform=$3

    if [ -f "$file" ]; then
        if grep -q "^${section}$" "$file"; then
            echo -e "${GREEN}✓${NC} ${platform}: ${section} section found"
        else
            echo -e "${RED}✗${NC} ${platform}: ${section} section MISSING"
            ((ERRORS++))
        fi
    fi
}

# Valid App Store categories for reference
# Full list: https://docs.fastlane.tools/actions/deliver/#available-categories
VALID_CATEGORIES="Books|Business|Developer Tools|Education|Entertainment|Finance|Food & Drink|Games|Graphics & Design|Health & Fitness|Kids|Lifestyle|Magazines & Newspapers|Medical|Music|Navigation|News|Photo & Video|Productivity|Reference|Shopping|Social Networking|Sports|Travel|Utilities|Weather"

# Check iOS app_info.txt categories
echo -e "${BLUE}iOS Categories:${NC}"
check_app_info_section "metadata/app_info.txt" "PRIMARY CATEGORY" "iOS"
check_app_info_section "metadata/app_info.txt" "SECONDARY CATEGORY (Optional)" "iOS"
check_app_info_section "metadata/app_info.txt" "AGE RATING" "iOS"

# Check macOS app_info.txt categories
echo ""
echo -e "${BLUE}macOS Categories:${NC}"
check_app_info_section "metadata/macos/app_info.txt" "PRIMARY CATEGORY" "macOS"
check_app_info_section "metadata/macos/app_info.txt" "SECONDARY CATEGORY (Optional)" "macOS"
check_app_info_section "metadata/macos/app_info.txt" "AGE RATING" "macOS"

# Validate category values match between iOS and macOS
echo ""
echo -e "${BLUE}Category Consistency:${NC}"
if [ -f "metadata/app_info.txt" ] && [ -f "metadata/macos/app_info.txt" ]; then
    IOS_PRIMARY=$(grep -A 2 "^PRIMARY CATEGORY$" metadata/app_info.txt | tail -n 1 | tr -d '[:space:]')
    MACOS_PRIMARY=$(grep -A 2 "^PRIMARY CATEGORY$" metadata/macos/app_info.txt | tail -n 1 | tr -d '[:space:]')

    if [ "$IOS_PRIMARY" = "$MACOS_PRIMARY" ]; then
        echo -e "${GREEN}✓${NC} Primary category matches: $IOS_PRIMARY"
    else
        echo -e "${YELLOW}⚠${NC} Primary category differs: iOS=$IOS_PRIMARY, macOS=$MACOS_PRIMARY"
        ((WARNINGS++))
    fi

    IOS_SECONDARY=$(grep -A 2 "^SECONDARY CATEGORY (Optional)" metadata/app_info.txt | tail -n 1 | tr -d '[:space:]')
    MACOS_SECONDARY=$(grep -A 2 "^SECONDARY CATEGORY (Optional)" metadata/macos/app_info.txt | tail -n 1 | tr -d '[:space:]')

    if [ "$IOS_SECONDARY" = "$MACOS_SECONDARY" ]; then
        echo -e "${GREEN}✓${NC} Secondary category matches: $IOS_SECONDARY"
    else
        echo -e "${YELLOW}⚠${NC} Secondary category differs: iOS=$IOS_SECONDARY, macOS=$MACOS_SECONDARY"
        ((WARNINGS++))
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING SCREENSHOTS (iOS & watchOS)"
echo "═══════════════════════════════════════════════════════"
echo ""

SCREENSHOT_DIR="metadata/en-US/screenshots"
if [ -d "$SCREENSHOT_DIR" ]; then
    echo -e "${GREEN}✓${NC} Screenshots directory exists"
    
    # Count screenshots
    IPHONE_69=$(ls "$SCREENSHOT_DIR"/iPhone_6.9_*.png 2>/dev/null | wc -l | tr -d ' ')
    IPHONE_67=$(ls "$SCREENSHOT_DIR"/iPhone_6.7_*.png 2>/dev/null | wc -l | tr -d ' ')
    IPHONE_65=$(ls "$SCREENSHOT_DIR"/iPhone_6.5_*.png 2>/dev/null | wc -l | tr -d ' ')
    IPHONE_55=$(ls "$SCREENSHOT_DIR"/iPhone_5.5_*.png 2>/dev/null | wc -l | tr -d ' ')
    WATCH=$(ls "$SCREENSHOT_DIR"/Watch_*.png 2>/dev/null | wc -l | tr -d ' ')
    
    echo ""
    echo "Screenshot counts:"
    
    if [ "$IPHONE_69" -ge 3 ]; then
        echo -e "  ${GREEN}✓${NC} iPhone 6.9\": $IPHONE_69 screenshots (3-10 required)"
    else
        echo -e "  ${RED}✗${NC} iPhone 6.9\": $IPHONE_69 screenshots (3-10 required)"
        ((WARNINGS++))
    fi
    
    if [ "$IPHONE_67" -ge 3 ]; then
        echo -e "  ${GREEN}✓${NC} iPhone 6.7\": $IPHONE_67 screenshots (3-10 required)"
    else
        echo -e "  ${RED}✗${NC} iPhone 6.7\": $IPHONE_67 screenshots (3-10 required)"
        ((WARNINGS++))
    fi
    
    if [ "$IPHONE_65" -ge 3 ]; then
        echo -e "  ${GREEN}✓${NC} iPhone 6.5\": $IPHONE_65 screenshots (3-10 required)"
    else
        echo -e "  ${YELLOW}⚠${NC} iPhone 6.5\": $IPHONE_65 screenshots (3-10 required)"
        ((WARNINGS++))
    fi
    
    if [ "$IPHONE_55" -ge 3 ]; then
        echo -e "  ${GREEN}✓${NC} iPhone 5.5\": $IPHONE_55 screenshots (3-10 required)"
    else
        echo -e "  ${YELLOW}⚠${NC} iPhone 5.5\": $IPHONE_55 screenshots (3-10 required)"
        ((WARNINGS++))
    fi
    
    if [ "$WATCH" -ge 3 ]; then
        echo -e "  ${GREEN}✓${NC} Apple Watch: $WATCH screenshots (3-5 required)"
    else
        echo -e "  ${YELLOW}⚠${NC} Apple Watch: $WATCH screenshots (3-5 required)"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} Screenshots directory not found"
    ((ERRORS++))
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING SCREENSHOTS (macOS)"
echo "═══════════════════════════════════════════════════════"
echo ""

MACOS_SCREENSHOT_DIR="metadata/macos/en-US/screenshots"
if [[ -d "${MACOS_SCREENSHOT_DIR}" ]]; then
    echo -e "${GREEN}✓${NC} macOS screenshots directory exists"

    # Count macOS screenshots by size
    # macOS supports: 1280x800, 1440x900, 2560x1600, 2880x1800
    MACOS_1280=$(ls "${MACOS_SCREENSHOT_DIR}"/1280x800_*.png 2>/dev/null | wc -l | tr -d ' ')
    MACOS_1440=$(ls "${MACOS_SCREENSHOT_DIR}"/1440x900_*.png 2>/dev/null | wc -l | tr -d ' ')
    MACOS_2560=$(ls "${MACOS_SCREENSHOT_DIR}"/2560x1600_*.png 2>/dev/null | wc -l | tr -d ' ')
    MACOS_2880=$(ls "${MACOS_SCREENSHOT_DIR}"/2880x1800_*.png 2>/dev/null | wc -l | tr -d ' ')

    echo ""
    echo "macOS screenshot counts:"

    if [[ "${MACOS_1280}" -ge 3 ]]; then
        echo -e "  ${GREEN}✓${NC} 1280x800: ${MACOS_1280} screenshots (3-10 required)"
    else
        echo -e "  ${YELLOW}⚠${NC} 1280x800: ${MACOS_1280} screenshots (3-10 required)"
        ((WARNINGS++))
    fi

    if [[ "${MACOS_1440}" -ge 3 ]]; then
        echo -e "  ${GREEN}✓${NC} 1440x900: ${MACOS_1440} screenshots (3-10 required)"
    else
        echo -e "  ${YELLOW}⚠${NC} 1440x900: ${MACOS_1440} screenshots (3-10 required)"
        ((WARNINGS++))
    fi

    if [[ "${MACOS_2560}" -ge 3 ]]; then
        echo -e "  ${GREEN}✓${NC} 2560x1600: ${MACOS_2560} screenshots (3-10 required)"
    else
        echo -e "  ${YELLOW}⚠${NC} 2560x1600: ${MACOS_2560} screenshots (3-10 required)"
        ((WARNINGS++))
    fi

    if [[ "${MACOS_2880}" -ge 3 ]]; then
        echo -e "  ${GREEN}✓${NC} 2880x1800: ${MACOS_2880} screenshots (3-10 required)"
    else
        echo -e "  ${YELLOW}⚠${NC} 2880x1800: ${MACOS_2880} screenshots (3-10 required)"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠${NC} macOS screenshots directory not found"
    ((WARNINGS++))
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING PRIVACY POLICY"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ -f "PRIVACY.md" ]; then
    echo -e "${GREEN}✓${NC} PRIVACY.md exists in root directory"
    
    # Check if it's reasonably sized
    SIZE=$(wc -c < "PRIVACY.md" | tr -d ' ')
    if [ "$SIZE" -gt 1000 ]; then
        echo -e "${GREEN}✓${NC} Privacy policy has substantial content ($SIZE bytes)"
    else
        echo -e "${YELLOW}⚠${NC} Privacy policy seems short ($SIZE bytes)"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} PRIVACY.md not found in root directory"
    ((ERRORS++))
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  METADATA CONTENT PREVIEW"
echo "═══════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}App Name (from app_info.txt):${NC}"
if [ -f "metadata/app_info.txt" ]; then
    grep -A 1 "^APP NAME$" metadata/app_info.txt | tail -n 1
else
    echo "  (file not found)"
fi

echo ""
echo -e "${BLUE}Keywords:${NC}"
if [ -f "metadata/en-US/keywords.txt" ]; then
    cat metadata/en-US/keywords.txt
else
    echo "  (file not found)"
fi

echo ""
echo -e "${BLUE}Description (first 200 chars):${NC}"
if [ -f "metadata/en-US/description.txt" ]; then
    head -c 200 metadata/en-US/description.txt
    echo "..."
else
    echo "  (file not found)"
fi

echo ""
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  VALIDATION SUMMARY"
echo "═══════════════════════════════════════════════════════"
echo ""

if [[ ${ERRORS} -eq 0 ]] && [[ ${WARNINGS} -eq 0 ]]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED!${NC}"
    echo ""
    echo "Your metadata is ready for App Store submission."
    echo "Next steps:"
    echo "  1. Take screenshots for iOS/watchOS (see metadata/en-US/screenshots/README.md)"
    echo "  2. Take screenshots for macOS (sizes: 1280x800, 1440x900, 2560x1600, 2880x1800)"
    echo "  3. Follow SUBMISSION_GUIDE.md"
    echo "  4. Upload to App Store Connect"
    exit 0
elif [[ ${ERRORS} -eq 0 ]]; then
    echo -e "${YELLOW}⚠ VALIDATION COMPLETED WITH WARNINGS${NC}"
    echo ""
    echo "Warnings: ${WARNINGS}"
    echo ""
    echo "You can proceed, but address warnings for better results."
    echo "Most warnings are about missing screenshots."
    echo ""
    echo "Platform-specific notes:"
    echo "  - iOS: Requires screenshots for 6.9\", 6.7\" (minimum)"
    echo "  - watchOS: Requires Apple Watch screenshots"
    echo "  - macOS: Requires screenshots at 1280x800, 1440x900, 2560x1600, or 2880x1800"
    exit 0
else
    echo -e "${RED}✗ VALIDATION FAILED${NC}"
    echo ""
    echo "Errors: ${ERRORS}"
    echo "Warnings: ${WARNINGS}"
    echo ""
    echo "Fix the errors above before submitting to App Store."
    exit 1
fi

