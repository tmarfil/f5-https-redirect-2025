# Bringing F5’s HTTPS Redirect iRule into the Modern Age

F5’s old `*sys*https_redirect` iRule was simple and got the job done, but it’s starting to show its age. It has some issues handling today’s web apps, so let’s take a look at how we can bring it up to speed.

## What’s wrong with the original iRule?

The code is pretty basic:

```tcl
ltm rule *sys*https_redirect {
    when HTTP_REQUEST {
       HTTP::redirect https://[getfield [HTTP::host] ":" 1][HTTP::uri] 
    }
}
```

It works for simple HTTPS redirects, but runs into problems with modern deployments:

1. **It always sends a 302 redirect.** This changes POST requests to GET, breaking things like form submissions. We really want to use a 308 to preserve the request method.
1. **It chokes on IPv6 host headers.** If you have an IPv6 address like `[2001:db8::1]:8080`, the `getfield` command used to parse out the host will fail. We need a smarter way to handle that.
1. **There’s no way to make exceptions.** Sometimes you need HTTP for things like Let’s Encrypt validation or health checks. The iRule redirects everything to HTTPS unconditionally.
1. **It doesn’t set any security headers.** The redirect response is pretty bare-bones. It’s a missed chance to enable some extra protections.
1. **Everything is hardcoded.** Want to change something? You have to edit the iRule directly. Not the most admin-friendly.
1. **Zero visibility.** If something isn’t working right, good luck figuring out why. The iRule doesn’t log anything for troubleshooting.

## Building a better HTTPS redirect

So how can we tackle these issues? Here’s what I came up with:

### Use a 308 redirect and preserve the request method

```tcl
set redirect_code 308  
HTTP::respond $redirect_code Location $redirect_location
```

A 308 status tells the browser “this resource has permanently moved to a new location, and you should use the same request method you used on the original request.” Perfect for our needs.

### Handle IPv6 addresses properly

```tcl
if {[string match "\[*\]*" $host]} {
    set ipv6_end [string first "\]" $host]
    set ipv6_addr [string range $host 1 [expr {$ipv6_end - 1}]]
    # Complex IPv6 + port parsing logic
}  
```

We check if the host header starts with a bracket `[`, which indicates an IPv6 address. If it does, we find the closing bracket and extract everything between them as the IPv6 address. Then we can handle the port separately.

### Allow exceptions for certain paths

```tcl
set exemption_paths {
    "/.well-known/acme-challenge/*" 
    "/health"
    "/status"
    "/ping"
    "/api/webhook/*"
}
foreach pattern $exemption_paths {
    if {[string match $pattern $uri]} {
        return
    }
}
```

We define a list of paths that should be exempt from the redirect, like `/.well-known/acme-challenge/*` for Let’s Encrypt. If the request URI matches any of those patterns, we just return and let the request through without redirecting.

### Add some security headers

```tcl
HTTP::respond $redirect_code Location $redirect_location \
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" \
    X-Frame-Options "DENY" \
    X-Content-Type-Options "nosniff" \
    X-XSS-Protection "1; mode=block" \  
    Referrer-Policy "strict-origin-when-cross-origin"
```

We can improve security by attaching a few key headers to the redirect response:

- `Strict-Transport-Security` to enforce HTTPS
- `X-Frame-Options` to prevent clickjacking
- `X-Content-Type-Options` to stop MIME sniffing vulnerabilities
- `X-XSS-Protection` to enable browser XSS filters
- `Referrer-Policy` to limit sensitive info in the `Referer` header

### Make the config user-friendly

```tcl
set redirect_code 308
set https_port 443 
set exemption_paths { ... }
```

I pulled the configurable pieces up to the top of the iRule in a clearly marked section. This way admins can tweak the behavior without having to understand all the underlying logic.

### Add some logging

```tcl
log local0. "$::IRULE_NAME v$::IRULE_VERSION: Exemption matched '$pattern' for $uri"
log local0. "$::IRULE_NAME v$::IRULE_VERSION: Redirecting to $redirect_location"  
```

Finally, I sprinkled in some logging statements using the standard syslog format. This gives us breadcrumbs to follow if we need to troubleshoot a redirect issue. The iRule name and version are included to help keep things organized.

## Wrapping it up

There you have it - an HTTPS redirect iRule tuned up for the modern web! It handles the intricacies of contemporary deployments while still being straightforward to understand and configure. The full iRule puts all these pieces together in a structured way.

Obviously there’s always room for enhancement, but I think this is a solid foundation to build on. It’s been working well for me in production. Let me know if you have any suggestions or questions!