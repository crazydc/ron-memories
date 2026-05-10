#!/bin/bash
# test-runner.sh — Main test runner for Ron-Memory v3 test suite
#
# Usage:
#   ./test-runner.sh           Run all tests
#   ./test-runner.sh --test <name>   Run specific test
#   ./test-runner.sh --list         List available tests
#
# Exit codes:
#   0 = All tests passed
#   1 = One or more tests failed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Available tests
TESTS=(
    "test-memory-set.sh"
    "test-memory-get.sh"
    "test-memory-sync.sh"
    "test-memory-rank.sh"
    "test-memory-list.sh"
)

# List available tests
list_tests() {
    echo "Available tests:"
    for test in "${TESTS[@]}"; do
        echo "  - ${test%.sh} (./${test})"
    done
}

# Run a single test
run_test() {
    local test_name="$1"
    local test_file="$SCRIPT_DIR/$test_name"
    
    if [ ! -f "$test_file" ]; then
        echo -e "${RED}✗ $test_name: Test file not found${NC}"
        return 1
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Running: $test_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Make executable
    chmod +x "$test_file"
    
    # Run with local PATH to ensure scripts are found
    local result=0
    local output
    output=$("$test_file" 2>&1) || result=$?
    
    # Print output
    echo "$output"
    
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}✓ $test_name: PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ $test_name: FAILED (exit code: $result)${NC}"
        return 1
    fi
}

# Parse arguments
RUN_SPECIFIC=""
LIST_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --test|-t)
            RUN_SPECIFIC="$2"
            shift 2
            ;;
        --list|-l)
            LIST_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--test <name>] [--list] [--help]"
            echo ""
            echo "Options:"
            echo "  --test <name>   Run specific test (e.g., test-memory-set)"
            echo "  --list          List available tests"
            echo "  --help          Show this help"
            echo ""
            list_tests
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

if [ "$LIST_ONLY" = true ]; then
    list_tests
    exit 0
fi

echo ""
echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║   Ron-Memory v3 Test Suite             ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
echo ""

# Determine which tests to run
if [ -n "$RUN_SPECIFIC" ]; then
    # Expand test name if needed
    if [[ "$RUN_SPECIFIC" != *.sh ]]; then
        RUN_SPECIFIC="${RUN_SPECIFIC}.sh"
    fi
    
    # Check if valid test
    valid=false
    for test in "${TESTS[@]}"; do
        if [ "$test" = "$RUN_SPECIFIC" ]; then
            valid=true
            break
        fi
    done
    
    if [ "$valid" = false ]; then
        echo -e "${RED}Invalid test: $RUN_SPECIFIC${NC}"
        echo ""
        list_tests
        exit 1
    fi
    
    TESTS=("$RUN_SPECIFIC")
fi

# Run tests
failed=0
passed=0
total=${#TESTS[@]}

for test in "${TESTS[@]}"; do
    if run_test "$test"; then
        ((passed++))
    else
        ((failed++))
    fi
    echo ""
done

# Summary
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Results: $passed passed, $failed failed (total: $total)"
echo ""

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. ✗${NC}"
    exit 1
fi