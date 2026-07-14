#!/bin/bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
CONFIG_DIR="${HOME}/.smartproxy"
CONFIG_FILE="${CONFIG_DIR}/config.json"
LOG_FILE="${CONFIG_DIR}/smartproxy.log"
PROXY_LIST_FILE="${CONFIG_DIR}/proxy_list.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Init
init_config() {
    mkdir -p "${CONFIG_DIR}"
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        cat > "${CONFIG_FILE}" << 'EOF'
{
  "current_proxy": "",
  "current_country": "",
  "last_update": "",
  "history": []
}
EOF
    fi
    touch "${LOG_FILE}"
}

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              SmartProxy - Proxy Selector                      ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

test_proxy() {
    local proxy=$1
    local success=0
    
    for ((i=1; i<=3; i++)); do
        if timeout 5 curl -s -x "http://${proxy}" -m 3 "https://www.google.com" > /dev/null 2>&1; then
            ((success++))
        fi
    done
    
    [[ ${success} -ge 2 ]] && return 0 || return 1
}

fetch_proxies() {
    print_header
    echo -e "${CYAN}Fetching proxy list...${NC}\n"
    
    python3 "${SCRIPT_DIR}/proxy_finder.py" > "${PROXY_LIST_FILE}" 2>> "${LOG_FILE}"
    
    if [[ ! -f "${PROXY_LIST_FILE}" ]]; then
        echo -e "${RED}ERROR: Failed to fetch proxies${NC}"
        log_message "ERROR: Failed to fetch proxies"
        return 1
    fi
    
    local count=$(python3 -c "import json; print(len(json.load(open('${PROXY_LIST_FILE}', 'r'))))" 2>/dev/null || echo "0")
    echo -e "${GREEN}OK: ${count} proxies fetched${NC}\n"
}

find_best_proxy() {
    print_header
    
    if ! fetch_proxies; then
        return 1
    fi

    echo -e "${CYAN}Testing proxies (3 times each)...${NC}\n"

    local best_proxy=""
    local best_country=""
    
    while read -r proxy; do
        echo -ne "${YELLOW}Testing: ${proxy}...${NC}"
        if test_proxy "${proxy}"; then
            echo -e " ${GREEN}OK${NC}"
            best_proxy="${proxy}"
            break
        else
            echo -e " ${RED}FAIL${NC}"
        fi
    done < <(python3 -c "import json; [print(p['proxy']) for p in json.load(open('${PROXY_LIST_FILE}', 'r'))[:10]]" 2>/dev/null)

    if [[ -z "${best_proxy}" ]]; then
        echo -e "\n${RED}ERROR: No working proxy found${NC}"
        log_message "ERROR: No working proxy found"
        return 1
    fi
    
    echo ""
    return 0
}

set_proxy_systemwide() {
    local proxy=$1
    
    export http_proxy="http://${proxy}"
    export https_proxy="http://${proxy}"
    export HTTP_PROXY="http://${proxy}"
    export HTTPS_PROXY="http://${proxy}"
    
    if [[ -f "${HOME}/.bashrc" ]]; then
        sed -i '/export.*proxy=/d' "${HOME}/.bashrc" 2>/dev/null || true
        cat >> "${HOME}/.bashrc" << EOF

# SmartProxy Configuration
export http_proxy="http://${proxy}"
export https_proxy="http://${proxy}"
export HTTP_PROXY="http://${proxy}"
export HTTPS_PROXY="http://${proxy}"
EOF
    fi
    
    echo -e "${GREEN}OK: Proxy set to ${proxy}${NC}"
    log_message "INFO: Proxy configured: ${proxy}"
}

save_proxy_config() {
    local proxy=$1
    local country=$2
    local config_file="${CONFIG_FILE}"

    python3 << PYEOF
import json
from datetime import datetime

with open('${config_file}', 'r') as f:
    config = json.load(f)

config['current_proxy'] = '${proxy}'
config['current_country'] = '${country}'
config['last_update'] = datetime.now().isoformat()

if len(config['history']) >= 20:
    config['history'] = config['history'][-19:]

config['history'].append({
    'proxy': '${proxy}',
    'country': '${country}',
    'timestamp': datetime.now().isoformat()
})

with open('${config_file}', 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
PYEOF
}

show_menu() {
    print_header
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        python3 << PYEOF
import json
try:
    with open('${CONFIG_FILE}', 'r') as f:
        config = json.load(f)
        if config.get('current_proxy'):
            print(f"Current: {config.get('current_proxy')} ({config.get('current_country')})")
            print(f"Updated: {config.get('last_update')}\n")
except:
    pass
PYEOF
    fi

    echo -e "${BLUE}Options:${NC}"
    echo -e "  ${CYAN}1)${NC} Find best proxy"
    echo -e "  ${CYAN}2)${NC} Show history"
    echo -e "  ${CYAN}3)${NC} Use current proxy"
    echo -e "  ${CYAN}4)${NC} Set manual proxy"
    echo -e "  ${CYAN}5)${NC} Remove proxy"
    echo -e "  ${CYAN}6)${NC} Exit\n"

    read -p "Choice: " choice

    case $choice in
        1) find_and_configure ;;
        2) list_history ;;
        3) use_proxy ;;
        4) manual_set ;;
        5) remove_proxy ;;
        6) exit 0 ;;
        *) echo -e "${RED}Invalid choice${NC}"; sleep 1; show_menu ;;
    esac
}

find_and_configure() {
    if find_best_proxy; then
        print_header
        echo -e "${GREEN}OK: Best proxy found!${NC}\n"
        read -p "Set this proxy? (y/n): " confirm
        if [[ "${confirm}" == "y" ]]; then
            local proxy=$(python3 -c "import json; print(json.load(open('${PROXY_LIST_FILE}', 'r'))[0]['proxy'])" 2>/dev/null)
            local country=$(python3 -c "import json; print(json.load(open('${PROXY_LIST_FILE}', 'r'))[0].get('country', 'Unknown'))" 2>/dev/null)
            set_proxy_systemwide "${proxy}"
            save_proxy_config "${proxy}" "${country}"
            echo -e "${GREEN}OK: Done!${NC}"
            sleep 2
        fi
    fi
    show_menu
}

list_history() {
    print_header
    echo -e "${CYAN}History:${NC}\n"
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        python3 << PYEOF
import json
try:
    with open('${CONFIG_FILE}', 'r') as f:
        config = json.load(f)
        if config.get('history'):
            for i, item in enumerate(config['history'][-10:], 1):
                print(f"{i}. {item.get('proxy')} ({item.get('country')})")
        else:
            print("No saved proxies")
except:
    print("Error reading file")
PYEOF
    fi
    read -p "\nPress Enter to continue..."
    show_menu
}

use_proxy() {
    print_header
    if [[ -f "${CONFIG_FILE}" ]]; then
        python3 << PYEOF
import json
try:
    with open('${CONFIG_FILE}', 'r') as f:
        config = json.load(f)
        if config.get('current_proxy'):
            print(f"Current proxy: {config.get('current_proxy')}")
        else:
            print("No active proxy")
except:
    print("Error reading file")
PYEOF
    fi
    read -p "\nPress Enter to continue..."
    show_menu
}

manual_set() {
    print_header
    read -p "Enter proxy address (example: 192.168.1.1:8080): " proxy_input
    if [[ -z "${proxy_input}" ]]; then
        echo -e "${RED}ERROR: Proxy is empty${NC}"
    else
        set_proxy_systemwide "${proxy_input}"
        save_proxy_config "${proxy_input}" "Manual"
        echo -e "${GREEN}OK: Proxy set${NC}"
    fi
    sleep 2
    show_menu
}

remove_proxy() {
    print_header
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY 2>/dev/null || true
    if [[ -f "${HOME}/.bashrc" ]]; then
        sed -i '/# SmartProxy Configuration/,/export HTTPS_PROXY=/d' "${HOME}/.bashrc" 2>/dev/null || true
    fi
    
    python3 << PYEOF
import json
try:
    with open('${CONFIG_FILE}', 'r') as f:
        config = json.load(f)
    config['current_proxy'] = ""
    config['current_country'] = ""
    with open('${CONFIG_FILE}', 'w') as f:
        json.dump(config, f, indent=2)
    print("OK: Proxy removed")
except:
    print("ERROR: Failed to remove proxy")
PYEOF
    sleep 2
    show_menu
}

main() {
    init_config

    case "${1:-}" in
        --find) find_best_proxy ;;
        --list) list_history ;;
        --use) use_proxy ;;
        --remove) remove_proxy ;;
        --set) [[ -z "${2:-}" ]] && echo "Usage: $0 --set <proxy>" && exit 1; set_proxy_systemwide "$2"; save_proxy_config "$2" "Manual" ;;
        *) show_menu ;;
    esac
}

main "$@"
