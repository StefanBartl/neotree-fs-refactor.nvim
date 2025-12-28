#!/usr/bin/env bash
# Test runner for neotree-fs-refactor.nvim

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Neotree-FS-Refactor Test Suite ==="
echo "Plugin directory: $PLUGIN_DIR"
echo ""

# Check if plenary is available
if ! command -v nvim &> /dev/null; then
    echo -e "${RED}Error: nvim not found${NC}"
    exit 1
fi

# Install plenary if not present
PLENARY_DIR="$HOME/.local/share/nvim/site/pack/vendor/start/plenary.nvim"
if [ ! -d "$PLENARY_DIR" ]; then
    echo -e "${YELLOW}Installing plenary.nvim...${NC}"
    git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$PLENARY_DIR"
fi

# Run tests
echo -e "${GREEN}Running unit tests...${NC}"
nvim --headless \
    --noplugin \
    -u NONE \
    +"set rtp+=$PLENARY_DIR" \
    +"set rtp+=$PLUGIN_DIR" \
    +"lua require('plenary.test_harness').test_directory('$SCRIPT_DIR', {minimal_init='$SCRIPT_DIR/minimal_init.lua'})" \
    +qa

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
else
    echo -e "${RED}Tests failed with exit code $EXIT_CODE${NC}"
fi

# Run benchmark if requested
if [ "$1" == "benchmark" ]; then
    echo ""
    echo -e "${GREEN}Running benchmarks...${NC}"
    nvim --headless \
        --noplugin \
        -u NONE \
        +"set rtp+=$PLUGIN_DIR" \
        +"lua require('tests.benchmark').quick()" \
        +qa
fi

exit $EXIT_CODE
