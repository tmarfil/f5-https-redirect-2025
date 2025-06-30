# F5 HTTPS Redirect 2025 v0.01.1 - Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying and configuring the F5 HTTPS Redirect 2025 v0.01.1 iRule on F5 BIG-IP systems.

## Prerequisites

### System Requirements
- F5 BIG-IP running TMOS version 11.4 or later
- iControl REST API access with administrative privileges
- Virtual server configured for HTTP traffic (typically port 80)
- Corresponding HTTPS virtual server (typically port 443)

### Network Requirements
- Backend pool configured for exempted paths (health checks, ACME challenges)
- DNS resolution for target domains
- Network connectivity for HTTPS redirection testing

### Access Requirements
- SSH access to F5 BIG-IP management interface
- Administrative credentials for iControl REST API
- Access to log files for debugging (`/var/log/ltm`)

## Configuration

### User-Configurable Parameters

#### Redirect Behavior
```tcl
set redirect_code 308    # HTTP status code (308 recommended, 301 for legacy)
set https_port 443       # Target HTTPS port (443 for standard)
```

#### Exemption Paths
```tcl
set exemption_paths {
    "/.well-known/acme-challenge/*"    # Let's Encrypt ACME challenges
    "/health"                          # Health check endpoint
    "/status"                          # Status monitoring
    "/ping"                            # Ping endpoint
    "/api/webhook/*"                   # Webhook endpoints (wildcard)
}
```

### Customization Guidelines

#### Adding Exemption Paths
1. **Exact Paths**: Use `/specific/path` for exact matches
2. **Wildcard Patterns**: Use `/path/*` for directory matching
3. **Case Sensitivity**: Paths are case-sensitive (`/Health` ≠ `/health`)

#### Common Exemption Patterns
- Health checks: `/health`, `/healthz`, `/status`
- Monitoring: `/metrics`, `/stats`, `/ping`
- Webhooks: `/api/webhook/*`, `/hooks/*`
- Legacy APIs: `/api/v1/legacy/*`

## Deployment Procedure

### Step 1: iRule Creation
```bash
# Using iControl REST API
curl -k -u admin:password -X POST \
  https://your-bigip/mgmt/tm/ltm/rule \
  -H "Content-Type: application/json" \
  -d '{"name":"https_redirect_2025","apiAnonymous":"[iRule code here]"}'
```

### Step 2: Virtual Server Attachment
```bash
# Attach to HTTP virtual server
curl -k -u admin:password -X PATCH \
  https://your-bigip/mgmt/tm/ltm/virtual/your-http-vs \
  -H "Content-Type: application/json" \
  -d '{"rules":["/Common/https_redirect_2025"]}'
```

### Step 3: Configuration Verification
```bash
# Verify iRule attachment
curl -k -u admin:password \
  https://your-bigip/mgmt/tm/ltm/virtual/your-http-vs?expandSubcollections=true
```

## Testing Procedures

### Basic Functionality Tests

#### Test 1: Standard Redirect
```bash
curl -I http://your-domain.com/
# Expected: 308 Permanent Redirect
# Expected: Location: https://your-domain.com/
```

#### Test 2: Method Preservation
```bash
curl -I -X POST http://your-domain.com/api/data
# Expected: 308 Permanent Redirect (not 302)
# Expected: Location: https://your-domain.com/api/data
```

#### Test 3: Query String Preservation
```bash
curl -I "http://your-domain.com/search?q=test&page=1"
# Expected: Location: https://your-domain.com/search?q=test&page=1
```

### Exemption Path Tests

#### Test 4: Health Check Exemption
```bash
curl -I http://your-domain.com/health
# Expected: 200 OK (or backend response)
# Expected: No redirect headers
```

#### Test 5: ACME Challenge Exemption
```bash
curl -I http://your-domain.com/.well-known/acme-challenge/test-token
# Expected: Backend response (not redirect)
```

### Security Header Validation

#### Test 6: Security Headers Present
```bash
curl -I http://your-domain.com/test
# Expected headers:
# Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
# X-Frame-Options: DENY
# X-Content-Type-Options: nosniff
# X-XSS-Protection: 1; mode=block
# Referrer-Policy: strict-origin-when-cross-origin
```

## Monitoring and Troubleshooting

### Log Monitoring
```bash
# Monitor iRule activity
tail -f /var/log/ltm | grep "F5_HTTPS_Redirect_2025"

# Example log entries:
# Exemption: "Exemption matched '/health' for /health - allowing passthrough"
# Redirect: "Redirecting to https://domain.com/path with code 308"
```

### Common Issues

#### Issue 1: Redirects Not Working
**Symptoms**: HTTP requests not redirected to HTTPS
**Diagnosis**: 
- Verify iRule attached to HTTP virtual server (not HTTPS)
- Check virtual server receiving HTTP traffic
- Confirm iRule syntax is valid

**Resolution**:
```bash
# Check virtual server configuration
tmsh list ltm virtual your-http-vs rules
```

#### Issue 2: Exemptions Not Working
**Symptoms**: Health checks or ACME challenges being redirected
**Diagnosis**:
- Verify exact path matching (case-sensitive)
- Check wildcard pattern syntax
- Confirm backend pool configuration

**Resolution**:
- Review exemption pattern syntax
- Test with exact path strings
- Check log entries for pattern matching

#### Issue 3: IPv6 Redirect Failures
**Symptoms**: Malformed redirect URLs with IPv6 addresses
**Diagnosis**:
- Check host header format `[::1]:8080`
- Verify IPv6 parsing logic

**Resolution**:
- Ensure proper IPv6 bracket notation
- Test with various IPv6 formats

## Performance Considerations

### Resource Usage
- **CPU Impact**: Minimal overhead for pattern matching (~1-2ms per request)
- **Memory Usage**: Negligible additional memory consumption
- **Network Impact**: Single redirect hop, no persistent connections

### Scaling Factors
- **Exemption Patterns**: Linear performance impact (5-10 patterns recommended)
- **Request Volume**: No significant impact on high-traffic virtual servers
- **Logging**: Production deployments should disable debug logging

### Production Optimizations
1. Remove debug logging statements
2. Limit exemption patterns to necessary paths only
3. Consider iRule priority for multiple iRule environments

## Security Considerations

### Security Headers Impact
- **HSTS**: Enforces HTTPS for 1 year, includes subdomains
- **X-Frame-Options**: Prevents clickjacking attacks
- **X-Content-Type-Options**: Prevents MIME type sniffing
- **X-XSS-Protection**: Enables browser XSS filtering
- **Referrer-Policy**: Controls referrer information disclosure

### Operational Security
- Regular review of exemption patterns
- Monitor for bypass attempts in logs
- Validate certificate automation functionality

## Maintenance Procedures

### Regular Tasks
1. **Monthly**: Review exemption path usage in logs
2. **Quarterly**: Validate security header policies
3. **Annually**: Assess performance impact and optimization opportunities

### Update Procedures
1. Test configuration changes in development environment
2. Deploy during maintenance windows
3. Monitor logs for unexpected behavior
4. Rollback plan: Remove iRule from virtual server

## Limitations

### Current Constraints
- Case-sensitive pattern matching only
- Shell-style wildcards only (no regex)
- Static configuration (requires redeployment for changes)
- F5 TCL limitations may affect complex patterns

### Known Issues
- Very large exemption lists may impact performance
- Complex IPv6 configurations require testing
- Some legacy F5 versions may have TCL syntax limitations

## Support and Troubleshooting

### Log Analysis
Enable detailed logging during initial deployment:
```tcl
log local0. "Debug: Processing request for $uri"
```

Remove debug statements in production for performance.

### Contact Information
For technical issues:
1. Review F5 documentation for TCL syntax
2. Consult F5 DevCentral community forums
3. Contact F5 support for platform-specific issues

## Appendix: Complete Configuration Example

```tcl
# Example complete iRule with custom exemptions
set exemption_paths {
    "/.well-known/acme-challenge/*"
    "/health"
    "/healthz" 
    "/status"
    "/metrics"
    "/api/webhook/*"
    "/api/monitoring/*"
}
```

This configuration provides comprehensive coverage for most operational requirements while maintaining security through HTTPS redirection.
