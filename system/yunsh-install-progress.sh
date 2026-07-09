#!/bin/bash
# YUNSH OS v1.0 - Installation Progress Display
# Full-screen framebuffer progress with YUNSH branding

export TERM=linux
export PATH=/usr/bin:/usr/sbin:/bin:/sbin

# Clear screen and hide cursor
printf "\e[2J\e[?25l"
printf "\e[1;1H"

# Colors
CYAN='\e[36m'
GREEN='\e[32m'
WHITE='\e[97m'
DIM='\e[2m'
RESET='\e[0m'
BOLD='\e[1m'

# Terminal size
ROWS=$(tput lines 2>/dev/null || echo 40)
COLS=$(tput cols 2>/dev/null || echo 80)

draw_frame() {
    local progress=$1
    local status_text=$2
    local step_num=$3
    local total_steps=$4
    
    printf "\e[2J\e[1;1H"
    
    # Center calculations
    local term_width=$COLS
    local title="YUNSH OS v1.0"
    local subtitle="首次安装 · 请勿断电"
    
    # Top padding
    printf "\n\n"
    
    # YUNSH ASCII logo
    printf "%*s\n" $(( (term_width + 0) / 2 )) ""
    printf "%*s\e[36m  ╔═══════════════════════════════╗\e[0m\n" $(( (term_width - 35) / 2 )) ""
    printf "%*s\e[36m  ║                               ║\e[0m\n" $(( (term_width - 35) / 2 )) ""
    printf "%*s\e[36m  ║    YYYY  UU   UU  NNNN   SSS  ║\e[0m\n" $(( (term_width - 35) / 2 )) ""
    printf "%*s\e[36m  ║     YY   UU   UU  NN NN  SS   ║\e[0m\n" $(( (term_width - 35) / 2 )) ""
    printf "%*s\e[36m  ║     YY   UU   UU  NN NN  SSS  ║\e[0m\n" $(( (term_width - 35) / 2 )) ""
    printf "%*s\e[36m  ║     YY   UU   UU  NN NN    SS ║\e[0m\n" $(( (term_width - 35) / 2 )) ""
    printf "%*s\e[36m  ║     YY    UUUUU   NN NN  SSS  ║\e[0m\n" $(( (term_width - 35) / 2 )) ""
    printf "%*s\e[36m  ║                               ║\e[0m\n" $(( (term_width - 35) / 2 )) ""
    printf "%*s\e[36m  ╚═══════════════════════════════╝\e[0m\n" $(( (term_width - 35) / 2 )) ""
    
    printf "\n"
    printf "%*s\e[1m\e[36m  YUNSH OS v1.0  AR Glasses OS\e[0m\n" $(( (term_width - 28) / 2 ))
    printf "\n\n"
    
    # Step counter
    printf "%*s\e[2m  步骤 %d / %d\e[0m\n" $(( (term_width - 10) / 2 )) "" $step_num $total_steps
    printf "\n"
    
    # Status text
    printf "%*s\e[97m  %s\e[0m\n" $(( (term_width - ${#status_text} - 2) / 2 )) "" "$status_text"
    printf "\n"
    
    # Progress bar
    local bar_width=50
    local fill=$(( progress * bar_width / 100 ))
    local empty=$(( bar_width - fill ))
    
    printf "%*s" $(( (term_width - bar_width - 2) / 2 )) ""
    printf "\e[36m["
    for ((i=0; i<fill; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "]\e[0m\n"
    
    # Percentage
    printf "%*s\e[1m\e[97m  %3d%%\e[0m\n" $(( (term_width - 6) / 2 )) "" $progress
    printf "\n\n"
    
    # Tips at bottom
    printf "%*s\e[2m  首次安装需要下载并配置系统组件\e[0m\n" $(( (term_width - 26) / 2 )) ""
    printf "%*s\e[2m  请确保网络连接正常，请勿断电\e[0m\n" $(( (term_width - 26) / 2 )) ""
}

# Calculate total steps (rough estimate)
TOTAL_STEPS=10

# Export function for use in first-boot script
export -f draw_frame
