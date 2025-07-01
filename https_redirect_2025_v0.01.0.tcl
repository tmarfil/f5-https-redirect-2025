# ============================================================================
# F5 HTTPS Redirect 2025 v0.01.0
# ============================================================================
# Unified HTTP/HTTPS iRule with configurable redirect and security headers.
# 
# DEPLOYMENT STRATEGY:
# - Always deploy to HTTP virtual server (port 80) for redirect functionality
# - Deploy to HTTPS virtual server (port 443) ONLY when security_headers_enabled=1
#   
# WHY deploy to HTTPS VS when security headers enabled?
# - Ensures consistent security headers whether user arrives via redirect or direct HTTPS
# - Prevents security policy gaps for users bypassing HTTP redirect
# - Single source of truth for security header configuration
# - No deployment when headers disabled = no unnecessary processing overhead
#
# Context-aware processing with minimal performance impact.
# Supports ACME challenges, health checks, webhooks, and custom exemptions.
# ============================================================================

when HTTP_REQUEST {
    # ========================================================================
    # SYSTEM INITIALIZATION
    # ========================================================================
    set ::IRULE_VERSION "0.01.0"
    set ::IRULE_NAME "F5_HTTPS_Redirect_2025_Unified"
    
    # ========================================================================
    # DEPLOYMENT CONFIGURATION
    # ========================================================================
    
    # Feature toggles - Enable/disable functionality independently
    set redirect_enabled 1
    set security_headers_enabled 0
    set exemption_processing 1
    set debug_logging 0
    
    # Redirect configuration (only used when redirect_enabled = 1)
    set redirect_code 308
    set https_port 443
    
    # Exemption paths (only processed when exemption_processing = 1)
    # These paths will NOT be redirected and will pass through to backend pool
    set exemption_paths {
        "/.well-known/acme-challenge/*"
        "/health"
        "/status" 
        "/ping"
        "/api/webhook/*"
    }
    
    # Security headers configuration (only used when security_headers_enabled = 1)
    # Individual headers can be enabled/disabled by setting to empty string ""
    # To disable a header: set the value to ""
    # To modify a header: change the value
    set hsts_header "max-age=31536000; includeSubDomains; preload"
    set frame_options_header "DENY"
    set content_type_options_header "nosniff"
    set xss_protection_header "1; mode=block"
    set referrer_policy_header "strict-origin-when-cross-origin"
    
    # ========================================================================
    # RUNTIME CONTEXT DETECTION
    # ========================================================================
    
    # Detect virtual server context automatically
    set local_port [TCP::local_port]
    set is_http_vs [expr {$local_port == 80}]
    set is_https_vs [expr {$local_port == 443}]
    
    # Support for non-standard ports by checking if we're processing SSL traffic
    # Alternative method: check for SSL context
    if {[catch {HTTP::header Host}]} {
        # If we can't get HTTP headers, might be SSL negotiation issue
        # Default to port-based detection
    } else {
        # Override port detection for non-standard configurations
        # Port 80 = HTTP, anything else with SSL capability = HTTPS
        if {$local_port != 80} {
            set is_http_vs 0
            set is_https_vs 1
        }
    }
    
    # Debug context detection
    if {$debug_logging} {
        log local0. "$::IRULE_NAME v$::IRULE_VERSION: Context - Port:$local_port HTTP_VS:$is_http_vs HTTPS_VS:$is_https_vs"
    }
    
    # ========================================================================
    # HTTPS VIRTUAL SERVER PROCESSING (Early Exit)
    # ========================================================================
    
    # HTTPS virtual servers: Allow all requests to pass through
    # Security headers will be added in HTTP_RESPONSE event
    if {$is_https_vs} {
        if {$debug_logging} {
            log local0. "$::IRULE_NAME v$::IRULE_VERSION: HTTPS VS - Request passed through for [HTTP::uri]"
        }
        return
    }
    
    # ========================================================================
    # HTTP VIRTUAL SERVER PROCESSING
    # ========================================================================
    
    # Only process HTTP virtual servers beyond this point
    if {!$is_http_vs} {
        return
    }
    
    # Check if redirect functionality is disabled
    if {!$redirect_enabled} {
        if {$debug_logging} {
            log local0. "$::IRULE_NAME v$::IRULE_VERSION: HTTP VS - Redirect disabled, passing through [HTTP::uri]"
        }
        return
    }
    
    # ========================================================================
    # EXEMPTION PROCESSING
    # ========================================================================
    
    # Get URI for exemption checking
    set uri [HTTP::uri]
    
    # Process exemptions if enabled
    set is_exempt 0
    if {$exemption_processing} {
        foreach pattern $exemption_paths {
            if {[string match $pattern $uri]} {
                set is_exempt 1
                log local0. "$::IRULE_NAME v$::IRULE_VERSION: Exemption matched '$pattern' for $uri - allowing passthrough"
                break
            }
        }
    }
    
    # If exempt, allow request to pass through (security headers added in HTTP_RESPONSE)
    if {$is_exempt} {
        return
    }
    
    # ========================================================================
    # HOST HEADER PROCESSING FOR REDIRECT
    # ========================================================================
    
    # Extract and clean host header for redirect URL construction
    set host [HTTP::host]
    
    if {$debug_logging} {
        log local0. "$::IRULE_NAME v$::IRULE_VERSION: Original host header: '$host'"
    }
    
    # Handle IPv6 addresses in brackets (e.g., [2001:db8::1]:8080)
    if {[string match {\[*\]*} $host]} {
        if {$debug_logging} {
            log local0. "$::IRULE_NAME v$::IRULE_VERSION: IPv6 pattern detected in host: '$host'"
        }
        
        # Extract IPv6 address and port if present
        set bracket_end [string first "\]" $host]
        
        if {$debug_logging} {
            log local0. "$::IRULE_NAME v$::IRULE_VERSION: Bracket end position: $bracket_end"
        }
        
        if {$bracket_end > 0} {
            set ipv6_addr [string range $host 1 [expr {$bracket_end - 1}]]
            
            if {$debug_logging} {
                log local0. "$::IRULE_NAME v$::IRULE_VERSION: Extracted IPv6 address: '$ipv6_addr'"
            }
            
            # Check for port after closing bracket
            if {[string first ":" $host [expr {$bracket_end + 1}]] > -1} {
                # Has port, extract it but don't use it (we'll use configured HTTPS port)
                set port_start [expr {$bracket_end + 2}]
                set orig_port [string range $host $port_start end]
                
                if {$debug_logging} {
                    log local0. "$::IRULE_NAME v$::IRULE_VERSION: Found port: '$orig_port'"
                }
                
                # Use the IPv6 address with brackets for redirect
                set host "\[$ipv6_addr\]"
            } else {
                # No port specified, just use the IPv6 address with brackets
                set host "\[$ipv6_addr\]"
            }
            
            if {$debug_logging} {
                log local0. "$::IRULE_NAME v$::IRULE_VERSION: Final processed host: '$host'"
            }
        } else {
            # Malformed IPv6, use as-is
            # This handles edge cases where bracket parsing fails
            if {$debug_logging} {
                log local0. "$::IRULE_NAME v$::IRULE_VERSION: IPv6 bracket parsing failed, using original host"
            }
        }
    } else {
        # Handle regular hostnames and IPv4 addresses
        # Remove port if present (we'll use our configured HTTPS port)
        if {$debug_logging} {
            log local0. "$::IRULE_NAME v$::IRULE_VERSION: Processing regular hostname: '$host'"
        }
        
        set colon_pos [string first ":" $host]
        if {$colon_pos > -1} {
            if {$debug_logging} {
                log local0. "$::IRULE_NAME v$::IRULE_VERSION: Found colon at position: $colon_pos"
            }
            set host [string range $host 0 [expr {$colon_pos - 1}]]
            if {$debug_logging} {
                log local0. "$::IRULE_NAME v$::IRULE_VERSION: Host after port removal: '$host'"
            }
        }
    }
    
    # ========================================================================
    # REDIRECT URL CONSTRUCTION AND RESPONSE
    # ========================================================================
    
    # Construct the HTTPS URL
    if {$https_port != 443} {
        set redirect_location "https://${host}:${https_port}${uri}"
    } else {
        set redirect_location "https://${host}${uri}"
    }
    
    # Log the redirect
    log local0. "$::IRULE_NAME v$::IRULE_VERSION: Redirecting to $redirect_location with code $redirect_code"
    
    # Send redirect response with security headers (if enabled)
    if {$security_headers_enabled} {
        # Build redirect response with individual security headers
        HTTP::respond $redirect_code Location $redirect_location \
            Connection "close" \
            Cache-Control "no-cache, no-store, must-revalidate" \
            Strict-Transport-Security $hsts_header \
            X-Frame-Options $frame_options_header \
            X-Content-Type-Options $content_type_options_header \
            X-XSS-Protection $xss_protection_header \
            Referrer-Policy $referrer_policy_header
    } else {
        # Send redirect without security headers
        HTTP::respond $redirect_code Location $redirect_location \
            Connection "close" \
            Cache-Control "no-cache, no-store, must-revalidate"
    }
}

when HTTP_RESPONSE {
    # ========================================================================
    # SECURITY HEADERS FOR ALL RESPONSES
    # ========================================================================
    
    # Early exit if security headers disabled (minimal performance impact)
    if {!$security_headers_enabled} {
        return
    }
    
    # Add security headers to all responses (HTTPS direct + HTTP exemptions)
    # Use 'replace' to override any backend headers with same names
    if {$hsts_header ne ""} {
        HTTP::header replace "Strict-Transport-Security" $hsts_header
    }
    if {$frame_options_header ne ""} {
        HTTP::header replace "X-Frame-Options" $frame_options_header
    }
    if {$content_type_options_header ne ""} {
        HTTP::header replace "X-Content-Type-Options" $content_type_options_header
    }
    if {$xss_protection_header ne ""} {
        HTTP::header replace "X-XSS-Protection" $xss_protection_header
    }
    if {$referrer_policy_header ne ""} {
        HTTP::header replace "Referrer-Policy" $referrer_policy_header
    }
    
    # Debug logging for response processing
    if {$debug_logging} {
        set local_port [TCP::local_port]
        log local0. "$::IRULE_NAME v$::IRULE_VERSION: Added security headers to response on port $local_port"
    }
}
