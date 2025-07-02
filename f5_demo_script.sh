#!/bin/bash

# F5 HTTPS Redirect 2025 Demo Script
# For asciinema recording - Terminal Demo
# Duration: ~2-3 minutes

# ============================================================================
# DEMO TIMING CONFIGURATION
# ============================================================================
# Customize pause durations for different demo speeds
# Usage: ./script.sh [speed_preset]
# Speed presets: fast, normal, slow, manual
# Or set custom timing with environment variables

# Parse command line speed preset or use environment variables
SPEED_PRESET="${1:-normal}"

case "$SPEED_PRESET" in
    "fast")
        HEADER_PAUSE=${HEADER_PAUSE:-1}
        STEP_PAUSE=${STEP_PAUSE:-0.5}
        CODE_PAUSE=${CODE_PAUSE:-1}
        TYPING_DELAY=${TYPING_DELAY:-0.02}
        RESULT_PAUSE=${RESULT_PAUSE:-1.5}
        ;;
    "slow")
        HEADER_PAUSE=${HEADER_PAUSE:-4}
        STEP_PAUSE=${STEP_PAUSE:-2}
        CODE_PAUSE=${CODE_PAUSE:-3}
        TYPING_DELAY=${TYPING_DELAY:-0.08}
        RESULT_PAUSE=${RESULT_PAUSE:-4}
        ;;
    "manual")
        HEADER_PAUSE=${HEADER_PAUSE:-0}
        STEP_PAUSE=${STEP_PAUSE:-0}
        CODE_PAUSE=${CODE_PAUSE:-0}
        TYPING_DELAY=${TYPING_DELAY:-0.01}
        RESULT_PAUSE=${RESULT_PAUSE:-0}
        MANUAL_MODE=1
        ;;
    "normal"|*)
        HEADER_PAUSE=${HEADER_PAUSE:-2}
        STEP_PAUSE=${STEP_PAUSE:-1}
        CODE_PAUSE=${CODE_PAUSE:-2}
        TYPING_DELAY=${TYPING_DELAY:-0.05}
        RESULT_PAUSE=${RESULT_PAUSE:-3}
        ;;
esac

# Colors and formatting
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
CLEAR='\033[2J\033[H'

# Demo configuration
F5_HTTP_VIP="10.1.1.100"
F5_HTTPS_VIP="10.1.1.100"
HTTP_PORT="80"
HTTPS_PORT="443"

# Utility functions
wait_for_input() {
    if [[ $MANUAL_MODE -eq 1 ]]; then
        echo -e "${BLUE}[Press ENTER to continue...]${NC}"
        read -r
    fi
}

print_header() {
    wait_for_input  # Wait BEFORE clearing screen
    echo -e "${CLEAR}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${YELLOW}  $1${NC}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    sleep $HEADER_PAUSE
}

print_step() {
    echo -e "${BOLD}${GREEN}▶ $1${NC}"
    echo ""
    wait_for_input
    sleep $STEP_PAUSE
}

simulate_typing() {
    local text="$1"
    local delay=${2:-$TYPING_DELAY}
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo ""
}

show_code_snippet() {
    local title="$1"
    local pattern="$2"
    local file="https_redirect_2025_v0_01_00.tcl"
    echo -e "${BOLD}${YELLOW}$title${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
    if command -v bat >/dev/null 2>&1; then
        grep -A3 -B1 "$pattern" "$file" 2>/dev/null | bat --language=tcl --style=plain --color=always || \
        grep -A3 -B1 "$pattern" "$file" 2>/dev/null || echo "Code snippet: $pattern"
    else
        grep -A3 -B1 "$pattern" "$file" 2>/dev/null || echo "Code snippet: $pattern"
    fi
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
    echo ""
    wait_for_input
    sleep $CODE_PAUSE
}

show_config_option() {
    local title="$1"
    local config="$2"
    echo -e "${BOLD}${CYAN}$title${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}$config${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
    echo ""
    wait_for_input
    sleep $CODE_PAUSE
}

# Main demo script
main() {
    print_header "F5 HTTPS Redirect 2025 iRule Demo"
    
    echo "🚀 Modern HTTP→HTTPS redirection with advanced features"
    echo "   ✅ 308 redirect (preserves POST/PUT methods)"
    echo "   ✅ IPv6 support with proper bracket handling"
    echo "   ✅ Configurable exemptions for ACME, health checks"
    echo "   ✅ Optional security headers"
    echo "   ✅ Context-aware deployment (HTTP vs HTTPS virtual servers)"
    echo ""
    sleep 2

    # Part 1: Show the problems with legacy redirect
    print_header "1️⃣  Why Replace _sys_https_redirect?"
    
    print_step "Legacy F5 redirect has several limitations"
    echo "❌ Always uses 302 redirect (breaks POST forms)"
    echo "❌ Can't handle IPv6 addresses like [2001:db8::1]:8080"
    echo "❌ No exceptions for Let's Encrypt or health checks"
    echo "❌ No security headers in redirect response"
    echo "❌ Everything hardcoded - no admin-friendly config"
    echo "❌ Zero logging for troubleshooting"
    echo ""
    wait_for_input
    sleep $RESULT_PAUSE

    # Part 2: Show modern solution
    print_header "2️⃣  HTTPS Redirect 2025 Solutions"
    
    print_step "✅ 308 Permanent Redirect (preserves HTTP methods)"
    show_config_option "iRule Configuration:" "set redirect_code 308
HTTP::respond \$redirect_code Location \$redirect_location"
    
    print_step "✅ Smart IPv6 + Port Handling"
    show_config_option "IPv6 Detection Logic:" "if {[string match \"\\[*\\]*\" \$host]} {
    set ipv6_end [string first \"]\" \$host]
    set ipv6_addr [string range \$host 1 [expr {\$ipv6_end - 1}]]
    # Parse IPv6 address and port separately
}"

    print_step "✅ Configurable Path Exemptions"
    show_config_option "Exemption Configuration:" "set exemption_paths {
    \"/.well-known/acme-challenge/*\"
    \"/health\"
    \"/status\"
    \"/ping\"
    \"/api/webhook/*\"
}"

    # Part 3: Test Basic Redirect
    print_header "3️⃣  Basic HTTP→HTTPS Redirect (308)"
    
    print_step "Testing method-preserving redirect"
    echo -e "${YELLOW}Command:${NC}"
    simulate_typing "curl -I -X POST http://$F5_HTTP_VIP/api/submit-form"
    echo ""
    
    echo -e "${GREEN}✓ F5 BIG-IP Response:${NC}"
    echo -e "${BOLD}HTTP/1.1 308 Permanent Redirect${NC}  ← 🎯 Preserves POST method!"
    echo "Location: https://$F5_HTTPS_VIP/api/submit-form"
    echo "Connection: close"
    echo "Cache-Control: no-cache, no-store, must-revalidate"
    echo ""
    echo "💡 Browser will retry the POST to HTTPS (unlike 302→GET conversion)"
    echo ""
    wait_for_input
    sleep $RESULT_PAUSE

    # Part 4: Test IPv6 Support
    print_header "4️⃣  IPv6 Host Header Support"
    
    print_step "Testing IPv6 address with port parsing"
    echo -e "${YELLOW}Command:${NC}"
    simulate_typing "curl -I -H 'Host: [2001:db8::1]:8080' http://$F5_HTTP_VIP/"
    echo ""
    
    echo -e "${GREEN}✓ F5 BIG-IP Response:${NC}"
    echo -e "${BOLD}HTTP/1.1 308 Permanent Redirect${NC}"
    echo -e "${BOLD}Location: https://[2001:db8::1]/${NC}  ← 🎯 Clean IPv6 handling!"
    echo "Connection: close"
    echo ""
    echo "💡 Properly extracts IPv6 address and uses standard HTTPS port"
    echo ""
    wait_for_input
    sleep $RESULT_PAUSE

    # Part 5: Test Exemptions
    print_header "5️⃣  Smart Path Exemptions"
    
    print_step "ACME Challenge exemption (Let's Encrypt)"
    echo -e "${YELLOW}Command:${NC}"
    simulate_typing "curl -I http://$F5_HTTP_VIP/.well-known/acme-challenge/test-token-123"
    echo ""
    
    echo -e "${GREEN}✓ F5 BIG-IP Response:${NC}"
    echo -e "${BOLD}HTTP/1.1 200 OK${NC}  ← 🎯 No redirect! Exemption working!"
    echo "Server: nginx/1.20.1"
    echo "Content-Type: text/plain"
    echo ""
    echo "💡 Certificate validation can proceed over HTTP"
    echo ""
    wait_for_input
    sleep $STEP_PAUSE

    print_step "Health check exemption"
    echo -e "${YELLOW}Command:${NC}"
    simulate_typing "curl -I http://$F5_HTTP_VIP/health"
    echo ""
    
    echo -e "${GREEN}✓ F5 BIG-IP Response:${NC}"
    echo -e "${BOLD}HTTP/1.1 200 OK${NC}  ← 🎯 Load balancer health checks work!"
    echo "Server: nginx/1.20.1"
    echo "Content-Type: application/json"
    echo ""
    wait_for_input
    sleep $RESULT_PAUSE

    # Part 6: Deployment Modes
    print_header "6️⃣  Two Deployment Strategies"
    
    print_step "📦 Basic Deployment (Most Common)"
    show_config_option "Configuration:" "security_headers_enabled = 0  (default)
Deploy to: HTTP virtual server only (port 80)

Benefits:
• Optimal performance (no HTTPS processing)
• Simple setup - matches legacy behavior
• HTTP redirects, HTTPS passes through untouched"

    print_step "🔒 Full Deployment (Maximum Security)"
    show_config_option "Configuration:" "security_headers_enabled = 1
Deploy to: Both HTTP and HTTPS virtual servers

Benefits:
• Security headers on redirects AND direct HTTPS
• Consistent security policy
• HSTS, X-Frame-Options, CSP headers everywhere"

    # Part 7: Security Headers Demo
    print_header "7️⃣  Optional Security Headers"
    
    print_step "Full deployment with security headers enabled"
    echo -e "${YELLOW}Command:${NC}"
    simulate_typing "curl -I http://$F5_HTTP_VIP/secure-app"
    echo ""
    
    echo -e "${GREEN}✓ F5 BIG-IP Response (Full Deployment):${NC}"
    echo "HTTP/1.1 308 Permanent Redirect"
    echo "Location: https://$F5_HTTPS_VIP/secure-app"
    echo -e "${BOLD}Strict-Transport-Security: max-age=31536000; includeSubDomains; preload${NC}"
    echo -e "${BOLD}X-Frame-Options: DENY${NC}"
    echo -e "${BOLD}X-Content-Type-Options: nosniff${NC}"
    echo -e "${BOLD}X-XSS-Protection: 1; mode=block${NC}"
    echo -e "${BOLD}Referrer-Policy: strict-origin-when-cross-origin${NC}"
    echo ""
    echo "🛡️ Security headers protect during redirect AND on HTTPS responses"
    echo ""
    wait_for_input
    sleep $RESULT_PAUSE

    # Part 8: Context Detection
    print_header "8️⃣  Intelligent Context Detection"
    
    print_step "Context-aware processing eliminates configuration errors"
    show_config_option "Automatic Detection Logic:" "set local_port [TCP::local_port]
set is_http_vs [expr {\$local_port == 80}]
set is_https_vs [expr {\$local_port == 443}]

# HTTP VS: Apply redirects and exemptions
# HTTPS VS: Allow passthrough + optional security headers"

    echo "💡 Same iRule works correctly on both virtual server types"
    echo "   No separate configurations to maintain!"
    echo ""
    wait_for_input
    sleep $RESULT_PAUSE

    # Part 9: Logging and Troubleshooting
    print_header "9️⃣  Built-in Logging & Diagnostics"
    
    print_step "Real-time troubleshooting with detailed logs"
    echo -e "${YELLOW}tail -f /var/log/ltm | grep F5_HTTPS_Redirect_2025${NC}"
    echo ""
    
    echo -e "${GREEN}Log Output:${NC}"
    echo "$(date '+%b %d %H:%M:%S') F5_HTTPS_Redirect_2025: Context - Port:80 HTTP_VS:1 HTTPS_VS:0"
    echo "$(date '+%b %d %H:%M:%S') F5_HTTPS_Redirect_2025: Exemption matched '/.well-known/acme-challenge/*' for /.well-known/acme-challenge/test-token-123"
    echo "$(date '+%b %d %H:%M:%S') F5_HTTPS_Redirect_2025: IPv6 pattern detected in host: '[2001:db8::1]:8080'"
    echo -e "${BOLD}$(date '+%b %d %H:%M:%S') F5_HTTPS_Redirect_2025: Redirecting to https://example.com/app with code 308${NC}"
    echo ""
    echo "🔍 Every redirect decision is logged with context"
    echo ""
    wait_for_input
    sleep $RESULT_PAUSE

    # Part 10: Testing Framework
    print_header "🔟  Comprehensive Test Suite"
    
    print_step "Automated testing for both deployment modes"
    echo -e "${YELLOW}Command:${NC}"
    simulate_typing "./test-redirect-v4.sh --basic"
    echo ""
    
    echo -e "${GREEN}✓ Test Results:${NC}"
    echo "✅ PASS: Basic redirect working"
    echo "✅ PASS: POST method redirect working"
    echo "✅ PASS: Query string preservation working"
    echo "✅ PASS: ACME challenge exemption working"
    echo "✅ PASS: Health check exemption working"
    echo "✅ PASS: Webhook exemption working"
    echo "✅ PASS: IPv6 host header processing working"
    echo ""
    echo -e "${YELLOW}Alternative:${NC}"
    simulate_typing "./test-redirect-v4.sh --full   # Test with security headers"
    echo ""
    wait_for_input
    sleep $RESULT_PAUSE

    # Part 11: Migration Guide
    print_header "🔄  Migration from Legacy _sys_https_redirect"
    
    print_step "Simple drop-in replacement process"
    show_config_option "Migration Steps:" "1. Remove old iRule: _sys_https_redirect
2. Import new iRule: F5_HTTPS_Redirect_2025_Unified
3. Apply to HTTP virtual server (port 80)
4. Test with: ./test-redirect-v4.sh --basic
5. Optional: Enable security headers and deploy to HTTPS VS"

    echo "🎯 Zero downtime migration - same virtual server requirements"
    echo "🔧 All configuration in clearly marked user section"
    echo "📊 Immediate benefits: better logging, IPv6 support, exemptions"
    echo ""
    wait_for_input
    sleep $RESULT_PAUSE

    # Final summary
    print_header "🎉  HTTPS Redirect 2025 Demo Complete!"
    
    echo "🔗 Key Advantages Demonstrated:"
    echo "   • 🔄 Method-preserving 308 redirects (no more broken forms)"
    echo "   • 🌐 Full IPv6 support with proper bracket handling"
    echo "   • ⚡ Smart exemptions for ACME, health checks, webhooks"
    echo "   • 🛡️ Optional security headers with consistent policies"
    echo "   • 🎯 Context-aware deployment (one iRule, two modes)"
    echo "   • 🔍 Comprehensive logging and troubleshooting"
    echo "   • 🧪 Built-in test suite for validation"
    echo ""
    echo "📈 Perfect for:"
    echo "   • Modern web applications with API calls"
    echo "   • Let's Encrypt certificate automation"
    echo "   • Load balancer health checking"
    echo "   • IPv6-enabled environments"
    echo "   • Security-conscious deployments"
    echo ""
    echo "📖 Full documentation: README.md"
    echo "💾 Download iRule: https_redirect_2025_v0_01_00.tcl"
    echo "🧪 Test script: test-redirect-v4.sh"
    echo ""
    wait_for_input
    sleep $STEP_PAUSE
    
    # Community engagement
    print_header "🤝  Join the F5 DevCentral Community"
    
    print_step "Share your migration success stories!"
    echo "🌐 We want to hear from you:"
    echo ""
    echo "   📋 Migration Stories:"
    echo "      • How did the upgrade solve your redirect issues?"
    echo "      • Which features made the biggest difference?"
    echo "      • Any unexpected benefits in your environment?"
    echo ""
    echo "   🚀 Feature Requests:"
    echo "      • Additional security headers?"
    echo "      • Custom exemption patterns?"
    echo "      • Enhanced logging options?"
    echo ""
    echo "   🐛 Issues & Enhancement:"
    echo "      • Open GitHub issues for bugs or feature requests"
    echo "      • Contribute test cases for edge scenarios"
    echo ""
    echo "🌐 Join the discussion: https://community.f5.com/"
    echo "📁 GitHub repository: https://github.com/tmarfil/f5-https-redirect-2025"
    echo ""
    wait_for_input
    sleep $STEP_PAUSE
}

# Check if running in demo mode or sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Direct execution
    echo "🎬 Starting F5 HTTPS Redirect 2025 Demo..."
    echo "   Speed preset: $SPEED_PRESET"
    if [[ $MANUAL_MODE -eq 1 ]]; then
        echo "   Manual mode: Press ENTER to advance each step"
    fi
    echo "   Perfect for asciinema recording!"
    echo ""
    sleep 1
    main
else
    # Sourced - provide functions for manual demo
    echo "Demo functions loaded. Available speed presets:"
    echo "  ./script.sh fast    - Quick demo (~1.5 min)"
    echo "  ./script.sh normal  - Standard demo (~2.5 min) [default]"
    echo "  ./script.sh slow    - Detailed demo (~4 min)"
    echo "  ./script.sh manual  - Manual advance mode"
    echo ""
    echo "Or set custom timing:"
    echo "  HEADER_PAUSE=1 STEP_PAUSE=0.5 ./script.sh"
    echo ""
    echo "Run: main"
fi
