#!/bin/bash

# Test script for HTTPS Redirect v3 - Custom Exemptions + Security Headers
# Validates redirect functionality, custom exemptions, and security headers

set -e

BIGIP_HOST="192.168.5.103"
HTTP_PORT="80"
HTTPS_PORT="443"

echo "=== HTTPS Redirect v3 Test Suite ==="
echo "Testing F5 BIG-IP: $BIGIP_HOST"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

test_passed() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
}

test_failed() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    exit 1
}

test_info() {
    echo -e "${YELLOW}ℹ️  INFO:${NC} $1"
}

section_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Helper function to check for security headers
check_security_headers() {
    local response="$1"
    local test_name="$2"
    
    if echo "$response" | grep -qi "strict-transport-security" && \
       echo "$response" | grep -qi "x-frame-options" && \
       echo "$response" | grep -qi "x-content-type-options" && \
       echo "$response" | grep -qi "x-xss-protection" && \
       echo "$response" | grep -qi "referrer-policy"; then
        test_passed "$test_name - Security headers present"
        return 0
    else
        test_failed "$test_name - Missing security headers"
        return 1
    fi
}

section_header "Basic Redirect Functionality (should still work)"

# Test 1: Basic HTTP to HTTPS redirect
echo "Test 1: Basic HTTP→HTTPS redirect"
response=$(curl -s -I "http://$BIGIP_HOST/")
if echo "$response" | grep -q "308 Permanent Redirect" && echo "$response" | grep -q "Location: https://$BIGIP_HOST/"; then
    test_passed "Basic redirect working"
    check_security_headers "$response" "Basic redirect"
else
    test_failed "Basic redirect not working"
fi

# Test 2: Method preservation
echo
echo "Test 2: POST method preservation"
response=$(curl -s -I -X POST "http://$BIGIP_HOST/api/data")
if echo "$response" | grep -q "308 Permanent Redirect" && echo "$response" | grep -q "Location: https://$BIGIP_HOST/api/data"; then
    test_passed "POST method redirect working"
    check_security_headers "$response" "POST redirect"
else
    test_failed "POST method redirect not working"
fi

# Test 3: Query string preservation
echo
echo "Test 3: Query string preservation"
response=$(curl -s -I "http://$BIGIP_HOST/api?param=value")
if echo "$response" | grep -q "308 Permanent Redirect" && echo "$response" | grep -q "Location: https://$BIGIP_HOST/api?param=value"; then
    test_passed "Query string preservation working"
    check_security_headers "$response" "Query string redirect"
else
    test_failed "Query string preservation not working"
fi

# Test 4: Custom host header
echo
echo "Test 4: Custom host header handling"
response=$(curl -s -I -H "Host: test.example.com" "http://$BIGIP_HOST/")
if echo "$response" | grep -q "308 Permanent Redirect" && echo "$response" | grep -q "Location: https://test.example.com/"; then
    test_passed "Custom host header working"
    check_security_headers "$response" "Custom host redirect"
else
    test_failed "Custom host header not working"
fi

section_header "Exemption Path Testing"

# Test 5: ACME challenge passthrough (default exemption)
echo "Test 5: ACME challenge passthrough"
response=$(curl -s -I "http://$BIGIP_HOST/.well-known/acme-challenge/test-token-123")
if ! echo "$response" | grep -q "308 Permanent Redirect"; then
    test_passed "ACME challenge passthrough working"
    test_info "Response: $(echo "$response" | head -1)"
else
    test_failed "ACME challenge was redirected instead of passed through"
fi

# Test 6: Health check exemption
echo
echo "Test 6: Health check exemption"
response=$(curl -s -I "http://$BIGIP_HOST/health")
if ! echo "$response" | grep -q "308 Permanent Redirect"; then
    test_passed "Health check exemption working"
    test_info "Response: $(echo "$response" | head -1)"
else
    test_failed "Health check was redirected instead of passed through"
fi

# Test 7: Status check exemption
echo
echo "Test 7: Status check exemption"
response=$(curl -s -I "http://$BIGIP_HOST/status")
if ! echo "$response" | grep -q "308 Permanent Redirect"; then
    test_passed "Status check exemption working"
else
    test_failed "Status check was redirected instead of passed through"
fi

# Test 8: Ping exemption
echo
echo "Test 8: Ping exemption"
response=$(curl -s -I "http://$BIGIP_HOST/ping")
if ! echo "$response" | grep -q "308 Permanent Redirect"; then
    test_passed "Ping exemption working"
else
    test_failed "Ping was redirected instead of passed through"
fi

# Test 9: Webhook exemption (wildcard pattern)
echo
echo "Test 9: Webhook exemption (wildcard)"
response=$(curl -s -I "http://$BIGIP_HOST/api/webhook/github")
if ! echo "$response" | grep -q "308 Permanent Redirect"; then
    test_passed "Webhook exemption working"
else
    test_failed "Webhook was redirected instead of passed through"
fi

# Test 10: Non-exempt webhook should redirect
echo
echo "Test 10: Non-webhook API should redirect"
response=$(curl -s -I "http://$BIGIP_HOST/api/users")
if echo "$response" | grep -q "308 Permanent Redirect"; then
    test_passed "Non-webhook API correctly redirected"
    check_security_headers "$response" "Non-webhook API redirect"
else
    test_failed "Non-webhook API should have been redirected"
fi

section_header "Security Headers Validation"

# Test 11: Detailed security header check
echo "Test 11: Detailed security headers validation"
response=$(curl -s -I "http://$BIGIP_HOST/test-security")
if echo "$response" | grep -q "308 Permanent Redirect"; then
    echo "Checking individual security headers:"
    
    # HSTS
    if echo "$response" | grep -qi "strict-transport-security.*max-age=31536000.*includeSubDomains.*preload"; then
        test_passed "  HSTS header correct"
    else
        test_failed "  HSTS header missing or incorrect"
    fi
    
    # X-Frame-Options
    if echo "$response" | grep -qi "x-frame-options.*DENY"; then
        test_passed "  X-Frame-Options header correct"
    else
        test_failed "  X-Frame-Options header missing or incorrect"
    fi
    
    # X-Content-Type-Options
    if echo "$response" | grep -qi "x-content-type-options.*nosniff"; then
        test_passed "  X-Content-Type-Options header correct"
    else
        test_failed "  X-Content-Type-Options header missing or incorrect"
    fi
    
    # X-XSS-Protection
    if echo "$response" | grep -qi "x-xss-protection.*1.*mode=block"; then
        test_passed "  X-XSS-Protection header correct"
    else
        test_failed "  X-XSS-Protection header missing or incorrect"
    fi
    
    # Referrer-Policy
    if echo "$response" | grep -qi "referrer-policy.*strict-origin-when-cross-origin"; then
        test_passed "  Referrer-Policy header correct"
    else
        test_failed "  Referrer-Policy header missing or incorrect"
    fi
    
else
    test_failed "Security header test path should have been redirected"
fi

section_header "Edge Cases"

# Test 12: Case sensitivity
echo "Test 12: Case sensitivity for exemptions"
response=$(curl -s -I "http://$BIGIP_HOST/HEALTH")
if echo "$response" | grep -q "308 Permanent Redirect"; then
    test_passed "Case-sensitive exemptions working (HEALTH redirected)"
else
    test_failed "Case sensitivity issue - HEALTH should redirect"
fi

# Test 13: Partial path matching
echo
echo "Test 13: Partial path matching"
response=$(curl -s -I "http://$BIGIP_HOST/healthcheck")
if echo "$response" | grep -q "308 Permanent Redirect"; then
    test_passed "Partial path matching working (healthcheck redirected)"
else
    test_failed "Partial path issue - healthcheck should redirect"
fi

echo
echo -e "${GREEN}🎉 All tests passed! HTTPS Redirect v3 is working correctly.${NC}"
echo
echo "Summary of v3 features tested:"
echo "  ✅ Basic HTTP→HTTPS redirect (308 status)"
echo "  ✅ Method preservation (POST, PUT, etc.)"
echo "  ✅ Query string preservation"
echo "  ✅ Custom host header handling"
echo "  ✅ Configurable exemption paths:"
echo "    - /.well-known/acme-challenge/* (ACME)"
echo "    - /health (health checks)"
echo "    - /status (status checks)"
echo "    - /ping (ping checks)"
echo "    - /api/webhook/* (webhooks)"
echo "  ✅ Enhanced security headers:"
echo "    - Strict-Transport-Security (HSTS)"
echo "    - X-Frame-Options"
echo "    - X-Content-Type-Options"
echo "    - X-XSS-Protection"
echo "    - Referrer-Policy"
echo "  ✅ Proper edge case handling"
echo
echo "Next: Check F5 logs to verify exemption pattern matching:"
echo "  sshpass -p \"\$BIGIP_PASSWORD\" ssh admin@bigip1.local \"tail -f /var/log/ltm | grep 'HTTPS Redirect'\""
