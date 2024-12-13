#!/bin/bash

# Colors for terminal output
RED='\033[0;31m'
NC='\033[0m'    # No Color
GREEN='\033[0;32m'
YELLOW='\033[1;33m'

# Default configuration
DEFAULT_PATTERN=".*"
DEFAULT_OUTPUT="output.md"
DEFAULT_EXCLUDE_DIRS="node_modules|\.git|\.idea|\.vscode|dist|build|coverage"
DEFAULT_MAX_FILE_SIZE=1048576  # 1MB in bytes

# Function to print usage instructions
print_usage() {
    echo "Usage: $0 [options] [pattern]"
    echo "Options:"
    echo "  -d, --dir <directory>     Directory to search (default: current directory)"
    echo "  -o, --output <file>       Output file (default: documentation.md)"
    echo "  -e, --exclude <pattern>   Exclude pattern (default: node_modules|.git|...)"
    echo "  -m, --max-size <bytes>    Maximum file size to process (default: 1MB)"
    echo "  -h, --help               Show this help message"
}

# Function to format file size
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB")
    local unit=0
    
    # Use awk for floating point comparison
    while (( $(echo "$size > 1024" | bc -l) )) && ((unit < 3)); do
        size=$(echo "scale=2; $size/1024" | bc)
        ((unit++))
    done
    
    echo "$size ${units[$unit]}"
}

# Function to get number of lines in a file
count_lines() {
    wc -l < "$1" | tr -d ' '
}

# Function to check if tree command exists
check_tree_command() {
    if ! command -v tree &> /dev/null; then
        echo -e "${YELLOW}Warning: 'tree' command not found. Installing...${NC}"
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux (Debian/Ubuntu based)
            sudo apt-get update && sudo apt-get install -y tree
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            brew install tree
        else
            echo -e "${RED}Error: Please install 'tree' command manually${NC}"
            exit 1
        fi
    fi
}

# Function to generate tree structure
generate_tree() {
    local dir=$1
    local exclude_pattern=$2
    
    # Check if tree command is available
    check_tree_command
    
    # Convert exclude pattern to tree-compatible format
    # Convert | separated patterns to multiple -I patterns
    local tree_exclude=""
    if [ -n "$exclude_pattern" ]; then
        # Split the pattern by | and create -I patterns
        IFS='|' read -ra PATTERNS <<< "$exclude_pattern"
        for pattern in "${PATTERNS[@]}"; do
            tree_exclude="$tree_exclude -I '$pattern'"
        done
    fi
    
    # Generate tree with specific options
    # -a: All files
    # -I: Exclude pattern
    # --noreport: No report at the end
    # --charset utf-8: Use UTF-8 characters
    # --dirsfirst: Show directories first
    eval "tree -a $tree_exclude --noreport --charset utf-8 --dirsfirst '$dir'"
}


# Function to process a single file
process_file() {
    local file=$1
    local size
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    local lines
    lines=$(count_lines "$file")
    local extension="${file##*.}"
    
    echo -e "\n## File: ${file##*/}"
    echo "- Path: \`$file\`"
    echo "- Size: $(format_size $size)"
    echo "- Extension: .$extension"
    echo "- Lines of code: $lines"
    echo "- Content:"
    echo
    echo "\`\`\`${extension}"
    # Add line numbers to content
    nl -ba "$file" | sed 's/^\s*\([0-9]\+\)\s\+/\1 | /'
    echo "\`\`\`"
    echo
    echo "---------------------------------------------------------------------------"
}

# Main script
main() {
    local pattern="$DEFAULT_PATTERN"
    local output="$DEFAULT_OUTPUT"
    local directory="."
    local exclude="$DEFAULT_EXCLUDE_DIRS"
    local max_size="$DEFAULT_MAX_FILE_SIZE"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dir)
                directory="$2"
                shift 2
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            -e|--exclude)
                exclude="$2"
                shift 2
                ;;
            -m|--max-size)
                max_size="$2"
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                pattern="$1"
                shift
                ;;
        esac
    done
    
    # Check if directory exists
    if [ ! -d "$directory" ]; then
        echo -e "${RED}Error: Directory '$directory' does not exist${NC}"
        exit 1
    fi
    
    # Create documentation header
    {
        echo "# Code Documentation"
        echo "Generated on: $(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")"
        
        # Get total number of files
        local total_files
        total_files=$(find "$directory" -type f -regex "$pattern" ! -regex ".*\($exclude\).*" | wc -l)
        echo "Total files: $total_files"
        
        echo -e "\n## Project Structure\n"
        echo "\`\`\`"
        generate_tree "$directory" "" "$exclude"
        echo "\`\`\`"
        
        # Process each file
        while IFS= read -r -d '' file; do
            local file_size
            file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            if [ "$file_size" -gt "$max_size" ]; then
                echo -e "${YELLOW}Skipping large file: $file${NC}" >&2
                continue
            fi
            process_file "$file"
        done < <(find "$directory" -type f -regex "$pattern" ! -regex ".*\($exclude\).*" -print0)
        
    } > "$output"
    
    echo -e "${GREEN}Documentation generated successfully at: $output${NC}"
}

# Execute main function with all arguments
main "$@"