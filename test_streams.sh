#!/bin/bash

# Set PATH to include common locations
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS] [TEST_DURATION]"
    echo ""
    echo "Options:"
    echo "  -d, --default     Test default_stations.json"
    echo "  -c, --custom      Test custom_stations.json"
    echo "  -a, --all         Test both default and custom stations"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Arguments:"
    echo "  TEST_DURATION     Duration to test each station in seconds (default: 5)"
    echo ""
    echo "Examples:"
    echo "  $0 --default           # Test default stations with 5 second duration"
    echo "  $0 --custom 10         # Test custom stations with 10 second duration"
    echo "  $0 --all               # Test both default and custom stations"
    exit 0
}

# Parse arguments
STATION_FILE=""
TEST_BOTH=false
TEST_DURATION=5

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--default)
            STATION_FILE="default_stations.json"
            shift
            ;;
        -c|--custom)
            STATION_FILE="custom_stations.json"
            shift
            ;;
        -a|--all)
            TEST_BOTH=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        [0-9]*)
            TEST_DURATION=$1
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# If no option specified, show interactive menu
if [ -z "$STATION_FILE" ] && [ "$TEST_BOTH" = false ]; then
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Radio Stream Tester${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo "What would you like to test?"
    echo ""
    echo "  1) Default stations (default_stations.json)"
    echo "  2) Custom stations (custom_stations.json)"
    echo "  3) All stations (both files)"
    echo ""
    read -p "Enter your choice (1-3): " choice

    case $choice in
        1)
            STATION_FILE="default_stations.json"
            ;;
        2)
            STATION_FILE="custom_stations.json"
            ;;
        3)
            TEST_BOTH=true
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    echo ""
fi

# Check if mpv is installed
if ! command -v mpv &> /dev/null; then
    echo -e "${RED}Error: mpv is not installed${NC}"
    echo "Please install it with: brew install mpv"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo "Please install it with: brew install jq"
    exit 1
fi

# Function to test stations from a file
test_stations_file() {
    local file=$1
    local file_label=$2

    # Check if file exists
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: $file not found${NC}"
        return 1
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Testing $file_label${NC}"
    echo -e "${BLUE}Test duration: ${TEST_DURATION} seconds per station${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Arrays to track results
    declare -a working_stations
    declare -a failing_stations

    # Read JSON and test each station
    local station_count=0
    local working_count=0
    local failing_count=0

    while IFS= read -r line; do
        station_name=$(echo "$line" | cut -d: -f1)
        station_url=$(echo "$line" | cut -d: -f2-)

        ((station_count++))

        echo -e "${YELLOW}[$station_count] Testing: ${station_name}${NC}"
        echo -e "    URL: ${station_url}"

        # Test the stream with mpv in background
        mpv --no-video --really-quiet "${station_url}" &> /dev/null &
        mpv_pid=$!

        # Wait for TEST_DURATION seconds
        sleep ${TEST_DURATION}

        # Check if mpv is still running
        if kill -0 $mpv_pid 2>/dev/null; then
            # Process is still running, which means stream is working
            kill $mpv_pid 2>/dev/null
            wait $mpv_pid 2>/dev/null
            echo -e "    ${GREEN}✓ Working${NC}"
            working_stations+=("$station_name")
            ((working_count++))
        else
            # Process died, stream failed
            echo -e "    ${RED}✗ Failed${NC}"
            failing_stations+=("$station_name")
            ((failing_count++))
        fi

        echo ""
    done < <(jq -r 'to_entries | .[] | "\(.key):\(.value)"' "$file")

    # Print summary
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}SUMMARY - $file_label${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total stations: ${station_count}"
    echo -e "${GREEN}Working: ${working_count}${NC}"
    echo -e "${RED}Failing: ${failing_count}${NC}"
    echo ""

    if [ ${failing_count} -gt 0 ]; then
        echo -e "${RED}Failed stations:${NC}"
        for station in "${failing_stations[@]}"; do
            echo -e "  - ${station}"
        done
        echo ""
    fi

    if [ ${working_count} -gt 0 ]; then
        echo -e "${GREEN}Working stations:${NC}"
        for station in "${working_stations[@]}"; do
            echo -e "  - ${station}"
        done
        echo ""
    fi

    echo -e "${BLUE}========================================${NC}"
    if [ ${station_count} -gt 0 ]; then
        success_rate=$(echo "scale=1; ($working_count / $station_count) * 100" | bc)
        echo "Success rate: ${success_rate}%"
    else
        echo "Success rate: 0%"
    fi
    echo ""
}

# Main execution
if [ "$TEST_BOTH" = true ]; then
    # Test both files
    test_stations_file "default_stations.json" "Default Stations"
    echo ""
    test_stations_file "custom_stations.json" "Custom Stations"
else
    # Test single file
    if [ "$STATION_FILE" = "default_stations.json" ]; then
        test_stations_file "$STATION_FILE" "Default Stations"
    else
        test_stations_file "$STATION_FILE" "Custom Stations"
    fi
fi
