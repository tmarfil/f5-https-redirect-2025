# ============================================================================
# F5 HTTPS Redirect 2025 v0.01.1
# ============================================================================
# HTTP to HTTPS redirect iRule with configurable exemptions and security
# headers. Supports ACME challenges, health checks, webhooks, and custom
# exemption patterns. Preserves HTTP methods, query strings, and IPv6 hosts.
# Adds modern security headers to all redirect responses.
# ============================================================================

when HTTP_REQUEST {
    # ========================================================================
    # System initialization
    # ========================================================================
    set ::IRULE_VERSION "0.01.1"
    set ::IRULE_NAME "F5_HTTPS_Redirect_2025"
    
    # ========================================================================
    # USER CONFIGURATION SECTION
    # ========================================================================
    
    # Redirect configuration
    set redirect_code 308  ;# Use 308 to preserve HTTP method (301 for traditional)
    set https_port 443     ;# Target HTTPS port
    
    # Exemption paths - Add your own paths to this list
    # These paths will NOT be redirected and will pass through to the backend pool
    set exemption_paths {
        "/.well-known/acme-challenge/*"
        "/health"
        "/status" 
        "/ping"
        "/api/webhook/*"
    }
    
    # Security headers applied to redirect responses (configured above for reference)
    # These are applied directly in the HTTP::respond command below
    
    # ========================================================================
    # EXEMPTION PROCESSING
    # ========================================================================
    
    # Get the URI to check for exemptions before any processing
    set uri [HTTP::uri]
    
    # Check if this URI matches any exemption pattern
    set is_exempt 0
    foreach pattern $exemption_paths {
        if {[string match $pattern $uri]} {
            set is_exempt 1
            log local0. "$::IRULE_NAME v$::IRULE_VERSION: Exemption matched '$pattern' for $uri - allowing passthrough"
            break
        }
    }
    
    # If exempt, allow request to pass through to pool
    if {$is_exempt} {
        return
    }
    
    # ========================================================================
    # HOST HEADER PROCESSING
    # ========================================================================
    
    # Extract host header and handle IPv6 addresses
    set host [HTTP::host]
    
    # Handle IPv6 addresses in brackets (e.g., [2001:db8::1]:8080)
    if {[string match "\[*\]*" $host]} {
        # Extract IPv6 address and port if present
        set ipv6_end [string first "\]" $host]
        set ipv6_addr [string range $host 1 [expr {$ipv6_end - 1}]]
        
        # Check for port after closing bracket
        if {[string first ":" $host [expr {$ipv6_end + 1}]] > -1} {
            # Has port, extract it
            set port_start [expr {$ipv6_end + 2}]
            set orig_port [string range $host $port_start end]
            # Use the IPv6 address with brackets for redirect
            set host "\[$ipv6_addr\]"
        } else {
            # No port specified, just use the IPv6 address with brackets
            set host "\[$ipv6_addr\]"
        }
    } else {
        # Handle regular hostnames and IPv4 addresses
        # Remove port if present (we'll use our configured HTTPS port)
        set colon_pos [string first ":" $host]
        if {$colon_pos > -1} {
            set host [string range $host 0 [expr {$colon_pos - 1}]]
        }
    }
    
    # ========================================================================
    # REDIRECT URL CONSTRUCTION
    # ========================================================================
    
    # Construct the HTTPS URL
    # Add port to host if not standard HTTPS port
    if {$https_port != 443} {
        set redirect_location "https://${host}:${https_port}${uri}"
    } else {
        set redirect_location "https://${host}${uri}"
    }
    
    # Log the redirect for debugging (remove in production)
    log local0. "$::IRULE_NAME v$::IRULE_VERSION: Redirecting to $redirect_location with code $redirect_code"
    
    # ========================================================================
    # REDIRECT RESPONSE WITH SECURITY HEADERS
    # ========================================================================
    
    # Send the redirect response with security headers
    HTTP::respond $redirect_code Location $redirect_location \
        Connection "close" \
        Cache-Control "no-cache, no-store, must-revalidate" \
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" \
        X-Frame-Options "DENY" \
        X-Content-Type-Options "nosniff" \
        X-XSS-Protection "1; mode=block" \
        Referrer-Policy "strict-origin-when-cross-origin"
}
