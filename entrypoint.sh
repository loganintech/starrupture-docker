#!/bin/bash
set -e

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Paths
STEAMCMD_DIR="/home/steam/steamcmd"
SERVER_DIR="/home/steam/starrupture"
SERVER_FILES_DIR="${SERVER_DIR}/server_files"
SAVES_DIR="${SERVER_DIR}/saves"
CONFIG_DIR="${SERVER_DIR}/config"

# Server executable (will be found after installation)
SERVER_EXE=""

# PID of the server process
SERVER_PID=""

# Signal handler for graceful shutdown
shutdown_handler() {
    log_info "Received shutdown signal, stopping server gracefully..."

    if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
        # Send SIGTERM to Wine process
        kill -TERM "${SERVER_PID}" 2>/dev/null || true

        # Wait for graceful shutdown (max 30 seconds)
        local count=0
        while kill -0 "${SERVER_PID}" 2>/dev/null && [[ ${count} -lt 30 ]]; do
            log_info "Waiting for server to stop... (${count}/30)"
            sleep 1
            ((count++))
        done

        # Force kill if still running
        if kill -0 "${SERVER_PID}" 2>/dev/null; then
            log_warn "Server did not stop gracefully, forcing shutdown..."
            kill -KILL "${SERVER_PID}" 2>/dev/null || true
        fi
    fi

    # Stop Wine server
    wineserver -k 2>/dev/null || true

    log_success "Server stopped"
    exit 0
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT SIGQUIT

# Ensure directories exist
ensure_directories() {
    log_info "Ensuring directory structure..."
    mkdir -p "${SERVER_FILES_DIR}"
    mkdir -p "${SAVES_DIR}"
    mkdir -p "${CONFIG_DIR}"
}

# Install or update the server via SteamCMD
install_or_update_server() {
    local validate_flag=""

    if [[ "${VALIDATE_ON_START}" == "true" ]]; then
        validate_flag="validate"
        log_info "Validation enabled, will verify all files"
    fi

    # Check if server is already installed
    if [[ -d "${SERVER_FILES_DIR}" ]] && [[ -n "$(ls -A ${SERVER_FILES_DIR} 2>/dev/null)" ]]; then
        if [[ "${UPDATE_ON_START}" != "true" ]]; then
            log_info "Server already installed and UPDATE_ON_START=false, skipping update"
            return 0
        fi
        log_info "Updating Starrupture Dedicated Server (App ID: ${STEAM_APP_ID})..."
    else
        log_info "Installing Starrupture Dedicated Server (App ID: ${STEAM_APP_ID})..."
    fi

    # Run SteamCMD
    "${STEAMCMD_DIR}/steamcmd.sh" \
        +@sSteamCmdForcePlatformType windows \
        +force_install_dir "${SERVER_FILES_DIR}" \
        +login anonymous \
        +app_update "${STEAM_APP_ID}" ${validate_flag} \
        +quit

    local exit_code=$?

    if [[ ${exit_code} -ne 0 ]]; then
        log_error "SteamCMD failed with exit code: ${exit_code}"

        # Provide helpful troubleshooting
        if [[ ${exit_code} -eq 8 ]]; then
            log_error "Exit code 8 usually means 'Missing configuration'"
            log_error "Try: Clear ${SERVER_FILES_DIR} and restart"
        fi

        return ${exit_code}
    fi

    log_success "Server installation/update completed"
}

# Find the server executable
find_server_executable() {
    log_info "Looking for server executable..."

    # Common patterns for dedicated server executables
    local patterns=(
        "StarRuptureServer*.exe"
        "*Server*.exe"
        "*Dedicated*.exe"
        "*.exe"
    )

    for pattern in "${patterns[@]}"; do
        local found=$(find "${SERVER_FILES_DIR}" -maxdepth 2 -iname "${pattern}" -type f 2>/dev/null | head -1)
        if [[ -n "${found}" ]]; then
            SERVER_EXE="${found}"
            log_success "Found server executable: ${SERVER_EXE}"
            return 0
        fi
    done

    log_error "Could not find server executable in ${SERVER_FILES_DIR}"
    log_info "Directory contents:"
    ls -la "${SERVER_FILES_DIR}" || true
    return 1
}

# Configure the server (create DSSettings.txt if needed)
configure_server() {
    log_info "Configuring server..."

    # Link saves directory if the game uses a specific location
    # This will depend on where Starrupture stores saves

    log_info "Server configuration:"
    log_info "  - Port: ${SERVER_PORT}"
    log_info "  - Additional args: ${ADDITIONAL_ARGS:-none}"
}

# Start the server
start_server() {
    log_info "Starting Starrupture Dedicated Server..."

    cd "$(dirname "${SERVER_EXE}")"

    # Build command line arguments
    local args=""

    # Add port if supported (adjust based on actual server args)
    if [[ -n "${SERVER_PORT}" ]]; then
        args="${args} -port=${SERVER_PORT}"
    fi

    # Add any additional arguments
    if [[ -n "${ADDITIONAL_ARGS}" ]]; then
        args="${args} ${ADDITIONAL_ARGS}"
    fi

    log_info "Launching: wine ${SERVER_EXE} ${args}"

    # Use xvfb-run for headless Wine execution
    xvfb-run --auto-servernum --server-args="-screen 0 1024x768x24" \
        wine "${SERVER_EXE}" ${args} &

    SERVER_PID=$!

    log_success "Server started with PID: ${SERVER_PID}"

    # Wait for server process
    wait ${SERVER_PID}
    local exit_code=$?

    log_info "Server exited with code: ${exit_code}"
    return ${exit_code}
}

# Main execution
main() {
    log_info "=========================================="
    log_info "  Starrupture Dedicated Server Container"
    log_info "=========================================="
    log_info ""
    log_info "Configuration:"
    log_info "  STEAM_APP_ID:      ${STEAM_APP_ID}"
    log_info "  SERVER_PORT:       ${SERVER_PORT}"
    log_info "  UPDATE_ON_START:   ${UPDATE_ON_START}"
    log_info "  VALIDATE_ON_START: ${VALIDATE_ON_START}"
    log_info "  ADDITIONAL_ARGS:   ${ADDITIONAL_ARGS:-<none>}"
    log_info ""

    ensure_directories

    install_or_update_server || {
        log_error "Failed to install/update server"
        exit 1
    }

    find_server_executable || {
        log_error "Failed to find server executable"
        exit 1
    }

    configure_server

    start_server
}

main "$@"
