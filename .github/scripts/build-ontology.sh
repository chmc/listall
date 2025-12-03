#!/bin/bash
# build-ontology.sh - Generates code_ontology.jsonl from Swift source files
# Usage: .github/scripts/build-ontology.sh [output_file]
#
# Scans the codebase and creates a JSONL ontology file with:
# - Classes, structs, enums, protocols
# - Key methods and properties
# - File locations and relationships

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_FILE="${1:-$REPO_ROOT/code_ontology.jsonl}"
TEMP_FILE=$(mktemp)

# Source directories to scan
SOURCE_DIRS=(
    "ListAll/ListAll/Models"
    "ListAll/ListAll/Services"
    "ListAll/ListAll/ViewModels"
    "ListAll/ListAll/Views"
    "ListAllWatch Watch App"
)

# Clean output file
> "$OUTPUT_FILE"

echo "Building code ontology..."
echo "Output: $OUTPUT_FILE"

# Function to escape JSON strings
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/}"
    str="${str//$'\t'/\\t}"
    printf '%s' "$str"
}

# Function to extract namespace from file path
get_namespace() {
    local file="$1"
    if [[ "$file" == *"/Models/CoreData/"* ]]; then
        echo "CoreData"
    elif [[ "$file" == *"/Models/"* ]]; then
        echo "Models"
    elif [[ "$file" == *"/Services/"* ]]; then
        echo "Services"
    elif [[ "$file" == *"/ViewModels/"* ]]; then
        echo "ViewModels"
    elif [[ "$file" == *"/Views/"* ]]; then
        if [[ "$file" == *"Watch App"* ]]; then
            echo "Views.watchOS"
        else
            echo "Views.iOS"
        fi
    else
        echo "App"
    fi
}

# Function to determine kind from declaration
get_kind() {
    local decl="$1"
    if [[ "$decl" =~ ^class ]]; then
        echo "class"
    elif [[ "$decl" =~ ^struct ]]; then
        echo "struct"
    elif [[ "$decl" =~ ^enum ]]; then
        echo "enum"
    elif [[ "$decl" =~ ^protocol ]]; then
        echo "protocol"
    elif [[ "$decl" =~ ^extension ]]; then
        echo "extension"
    elif [[ "$decl" =~ ^func ]]; then
        echo "method"
    elif [[ "$decl" =~ ^(var|let).*: ]]; then
        echo "property"
    else
        echo "unknown"
    fi
}

# Function to extract type name from declaration
get_type_name() {
    local decl="$1"
    # Extract class/struct/enum/protocol name
    if [[ "$decl" =~ ^(class|struct|enum|protocol|extension)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*) ]]; then
        echo "${BASH_REMATCH[2]}"
    else
        echo ""
    fi
}

# Function to generate summary from declaration and context
generate_summary() {
    local kind="$1"
    local name="$2"
    local decl="$3"
    local file="$4"

    case "$kind" in
        "class")
            if [[ "$decl" =~ ObservableObject ]]; then
                echo "Observable $name class for SwiftUI state management"
            elif [[ "$name" == *"Service"* ]]; then
                echo "Service class providing ${name/Service/} functionality"
            elif [[ "$name" == *"Manager"* ]]; then
                echo "Manager class for ${name/Manager/} operations"
            elif [[ "$name" == *"ViewModel"* ]]; then
                echo "View model for ${name/ViewModel/} UI state"
            else
                echo "$name class"
            fi
            ;;
        "struct")
            if [[ "$decl" =~ Codable ]]; then
                echo "Codable $name model"
            elif [[ "$decl" =~ Identifiable ]]; then
                echo "Identifiable $name model"
            else
                echo "$name struct"
            fi
            ;;
        "enum")
            if [[ "$decl" =~ Error ]]; then
                echo "$name error cases"
            else
                echo "$name enumeration"
            fi
            ;;
        "protocol")
            echo "$name protocol definition"
            ;;
        "extension")
            echo "Extension for $name"
            ;;
        *)
            echo "$name"
            ;;
    esac
}

# Function to extract protocols/inheritance
get_relations() {
    local decl="$1"
    local relations=""

    # Extract protocols after colon
    if [[ "$decl" =~ :[[:space:]]*([^{]+) ]]; then
        local inherited="${BASH_REMATCH[1]}"
        # Split by comma and create relations
        IFS=',' read -ra PROTOCOLS <<< "$inherited"
        for proto in "${PROTOCOLS[@]}"; do
            proto=$(echo "$proto" | xargs) # trim whitespace
            if [[ -n "$proto" && "$proto" != "{"* ]]; then
                if [[ -n "$relations" ]]; then
                    relations="$relations, "
                fi
                relations="${relations}\"IMPLEMENTS:$proto\""
            fi
        done
    fi

    echo "$relations"
}

# Count for progress
total_entities=0

# Process each source directory
for dir in "${SOURCE_DIRS[@]}"; do
    full_dir="$REPO_ROOT/$dir"
    if [[ ! -d "$full_dir" ]]; then
        continue
    fi

    # Find all Swift files
    while IFS= read -r -d '' file; do
        relative_path="${file#$REPO_ROOT/}"
        namespace=$(get_namespace "$relative_path")

        # Extract type declarations (class, struct, enum, protocol)
        while IFS= read -r line; do
            # Skip empty lines
            [[ -z "$line" ]] && continue

            # Clean the line
            decl=$(echo "$line" | sed 's/^[[:space:]]*//' | tr -d '\r')

            # Skip comments and imports
            [[ "$decl" =~ ^// ]] && continue
            [[ "$decl" =~ ^import ]] && continue
            [[ "$decl" =~ ^@ ]] && continue

            kind=$(get_kind "$decl")
            [[ "$kind" == "unknown" ]] && continue

            type_name=$(get_type_name "$decl")
            [[ -z "$type_name" ]] && continue

            # Generate ID
            entity_id="$namespace.$type_name"

            # Get signature (first line of declaration)
            signature=$(echo "$decl" | head -1 | sed 's/{[[:space:]]*$//' | xargs)

            # Generate summary
            summary=$(generate_summary "$kind" "$type_name" "$decl" "$relative_path")

            # Get relations
            relations=$(get_relations "$decl")

            # Escape for JSON
            signature_escaped=$(json_escape "$signature")
            summary_escaped=$(json_escape "$summary")

            # Build relations array
            if [[ -n "$relations" ]]; then
                relations_json="[$relations]"
            else
                relations_json="[]"
            fi

            # Write JSONL entry
            echo "{\"id\": \"$entity_id\", \"kind\": \"$kind\", \"file\": \"$relative_path\", \"signature\": \"$signature_escaped\", \"summary\": \"$summary_escaped\", \"relations\": $relations_json}" >> "$TEMP_FILE"

            ((total_entities++))

        done < <(grep -E "^[[:space:]]*(public[[:space:]]+|private[[:space:]]+|internal[[:space:]]+|open[[:space:]]+|fileprivate[[:space:]]+)?(final[[:space:]]+)?(class|struct|enum|protocol|extension)[[:space:]]+" "$file" 2>/dev/null || true)

    done < <(find "$full_dir" -name "*.swift" -type f -print0 2>/dev/null)
done

# Sort and deduplicate entries, then write to output
sort -u "$TEMP_FILE" > "$OUTPUT_FILE"
rm -f "$TEMP_FILE"

# Count final entries
final_count=$(wc -l < "$OUTPUT_FILE" | xargs)

echo ""
echo "Ontology built successfully!"
echo "  Total entities: $final_count"
echo "  Output file: $OUTPUT_FILE"
echo ""
echo "Categories indexed:"
grep -o '"kind": "[^"]*"' "$OUTPUT_FILE" | sort | uniq -c | sort -rn | while read count kind; do
    kind_name=$(echo "$kind" | sed 's/"kind": "//;s/"//')
    printf "  %-12s %s\n" "$kind_name:" "$count"
done
