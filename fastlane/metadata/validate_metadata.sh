#!/bin/bash

# Metadata Validation Script for ListAll
# This script checks that all required files exist and meet character limits

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
echo "  CHECKING CHARACTER LIMITS"
echo "═══════════════════════════════════════════════════════"
echo ""

check_char_limit "metadata/en-US/description.txt" 4000 "Description"
check_char_limit "metadata/en-US/keywords.txt" 100 "Keywords"
check_char_limit "metadata/en-US/release_notes.txt" 4000 "Release Notes"
check_char_limit "metadata/en-US/promotional_text.txt" 170 "Promotional Text"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING URLS"
echo "═══════════════════════════════════════════════════════"
echo ""

check_url "metadata/en-US/support_url.txt" "Support URL"
check_url "metadata/en-US/privacy_policy_url.txt" "Privacy Policy URL"
check_url "metadata/en-US/marketing_url.txt" "Marketing URL"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CHECKING SCREENSHOTS"
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

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED!${NC}"
    echo ""
    echo "Your metadata is ready for App Store submission."
    echo "Next steps:"
    echo "  1. Take screenshots (see metadata/en-US/screenshots/README.md)"
    echo "  2. Follow SUBMISSION_GUIDE.md"
    echo "  3. Upload to App Store Connect"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ VALIDATION COMPLETED WITH WARNINGS${NC}"
    echo ""
    echo "Warnings: $WARNINGS"
    echo ""
    echo "You can proceed, but address warnings for better results."
    echo "Most warnings are about missing screenshots."
    exit 0
else
    echo -e "${RED}✗ VALIDATION FAILED${NC}"
    echo ""
    echo "Errors: $ERRORS"
    echo "Warnings: $WARNINGS"
    echo ""
    echo "Fix the errors above before submitting to App Store."
    exit 1
fi

