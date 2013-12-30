#
#  Library support routines for various HTTP returns.
#
#  Depends on:
#	html.tcl
#
#  Andrew Payne
#  payne@openmarket.com
#

# ---------------------------------------------------------------------------
#
#  Return an "authorized required" reply to the client.  This will force
#  prompting for username/password.
#
proc return-auth-required {{realm "Open Market Account"}} {
    log "return-auth-required $realm"
    puts "HTTP/1.0 401 Unauthorized"
    puts "Content-type: text/html"
    puts "WWW-Authenticate: Basic realm=\"$realm\""
    puts ""
    puts [title "Authorization Required"]
    puts "Browser not authentication-capable or authentication failed."
    puts "<p>"
    puts "The OpenMarket username and password you entered were not"
    puts "valid."
    end-html
    exit
}

# ---------------------------------------------------------------------------
#
#  Return a redirect response to the client to the specified URL
#
proc return-redirect {url} {
    puts "HTTP/1.0 302 Found"
    puts "Location: $url"
    puts "Content-type: text/html"
    puts ""
    puts [title "Redirect"]
    puts "You appear to have a very old World Wide Web browser, that doesn't"
    puts "support the redirect operation.  We strongly suggest upgrading to"
    puts "the latest software.<p>"
    puts "Here's the <a href=\"$url\">actual document</a>."
    end-html
    exit
}

# ---------------------------------------------------------------------------
#
#  Return an error page to the client.
#
proc return-error {} {
    puts "HTTP/1.0 200 OK"
    puts "Content-type: text/html"
    puts ""
    puts [title "Payment Transaction Error"]
    puts "An error occurred during the processing of your payment "
    puts "transaction. <p> The error has been logged to our attention."
    end-html
    exit
}
