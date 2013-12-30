#
#  Generally useful
#
#  L. Stewart
#  stewart@openmarket.com
#


# send a screen back to the user explaining something about the error
# and record the message in syslog
proc cgi_error { {branch ""} {etext ""} {opt ""}} {
    set msg {[cgi_begin "Transaction Error"]
An error has occurred during the processing of your transaction.
It has been logged to our attention.<p>
$opt
[cgi_end]
}
    puts [subst $msg]
    syslog_log [list [list prog $branch] [list text $etext]]
    exit
}

proc cgi_error_list { log_list {opt ""}} {
    set msg {[cgi_begin "Transaction Error"]
An error has occurred during the processing of your transaction.
It has been logged to our attention.<p>
$opt
[cgi_end]
}
    puts [subst $msg]
    syslog_log $log_list
    exit
}

# cgi_parse_querystring will typically be used to process something which
# has the form of a payment URL - there are signed name-value pairs
# in the query string.
#
# the query string is everything after the "?"
# the u_merchant argument is the name of an array to be filled in with
#   the principal record for the merchant who wrote the query string
# the u_secretkey argument is the name of an array to be filled in with
#   the right key for this merchant
# the u_fields argument is the name of an array to be filled in with
#   the name value pairs.
#
# in a case where there are multiple ?'s, cgi_parse_querystring throws
# away everything after the second ?
proc cgi_parse_querystring { query u_fields u_secretkey u_merchant} {
    upvar $u_secretkey secretkey
    upvar $u_merchant merchant
    upvar $u_fields fields
    global env
    # handle multiple ?'s, if any
    set first [split $query ?]
    if {[llength $first] > 1} {
	set query [lindex $first 0]
    }
    # parse the GET fields, if any
    if {[string length $query] > 0} {
	if [regexp {([^:]+):(.*)} $query dummy hash remainder] {
	    cgi_parse $remainder fields
	    if {![pay_verify_signature $hash $remainder fields \
		    secretkey merchant]} {
		cgi_error cgi_parse_querystring "bad key: $query" \
			"There was a problem with the URL"
	    }
	} else {
	    cgi_error cgi_parse_querystring "bad script arguments: $query" \
		    "There was a problem with the script arguments"
	}
    }
    
}

#
# cgi_fieldcheck takes an array and a list of required fieldnames
#   if any of the fieldnames are not defined as elements of the array
#   then cgi_fieldcheck returns 0
#
#   If all the fields exist, then each one is strimmed of whitespace
#   at the ends and any quotes are removed.
#   XXX Should expand to remove other bad stuff that might be in there
#

proc cgi_fieldcheck { a_fields fieldlist {missing xxx}} {
    upvar $a_fields a
    if {[string compare $missing xxx] != 0} {
	upvar $missing mlist
    }
    set mlist {}
    foreach field $fieldlist {
	if {![info exists a($field)]} { 
	    lappend mlist $field
	    continue
	}
	set a($field) [string trim [string trim $a($field)] {\"}]
	if {[string length $a($field)] == 0} {
	    lappend mlist $field
	}
    }
    if {[llength $mlist] > 0} { return 0 }
    return 1
}


#
# cgi_begin_nph
#
# deprecated
#

proc cgi_begin_nph { {title ""}} {
    return [cgi_begin $title]
}


proc cgi_title { t} {
    return "<html><head><title>$t</title></head> 
            <body><h1>$t</h1>"
}

#
# cgi_begin
#
# transmits the stuff that you need at the beginning of a screen
# accepts an optional title
#
# text returned as a string, suitable for use in [subst] pages
#

proc cgi_begin { {title ""}} {
    global env
    if {[string first "nph-" [file tail $env(SCRIPT_NAME)]] == 0} {
	append res "HTTP/1.0 200 OK
Server: OMI/1.1
"
    }
    append res "Content-type: text/html

"
    append res [cgi_title $title]
    return $res
}

#
# cgi_end
# returns a signature line
#
proc cgi_end {} {
    global merchant_server_root merchant_demo_path
set msg {<p><hr><A HREF="$merchant_server_root/">
<IMG ALIGN="top" SRC="$merchant_server_root$merchant_demo_path/images/omicon32.gif" ALT="OMI Home"></A>
<I>Copyright &#169; 1994 Open Market, Inc. All Rights Reserved.</I>
</body></html>
}
    return [subst $msg]}



proc cgi_return_error { {branch {}} { etext {}}} {
    set msg {[cgi_begin "Error"]
An error has occurred during the processing of your request.
It has been logged to our attention.<P>

[cgi_end]
}
    puts [subst $msg]
    syslog_log [list [list prog $branch] [list text $etext]]
    exit
}

#
# returns a really simple link
#
proc cgi_link { target text } {
  return "<a href=\"$target\">$text</a>"
}

proc cgi_form { target } {
  return "<form method=POST action=\"$target\">"
}

#
# cgi_self_link 
#
# this is used to build links from a cgi script to itself which
# incorporate additional fields in a GET style
#
# cgi expects the name of "self" to be in env(SCRIPT_NAME)
# cgi expects "secretkey" to be an array with the appropriate key
# 
#
proc cgi_self_link { {field_list {}} {a_fields xxx}} {
    global env secretkey
    upvar $a_fields fields
    # the following two statements create an empty array
    # in the case that match was not passed in
    set fields(xyzzy) plugh
    unset fields(xyzzy)
    foreach item [array names fields] {
	set nv($item) $fields($item)
    }
    foreach item $field_list {
	if {[llength $item] != 2} {
	    error "Bad value passed to cgi_self_link $item"
	} else {
	    set nv([lindex $item 0]) [lindex $item 1]
	}
    }
    set ticket [sec_create_ticket secretkey nv]
    return http://$env(SERVER_NAME)$env(SCRIPT_NAME)?$ticket
}

#
# stuff that was in http.tcl
# originally authored by A. Payne
#


# ---------------------------------------------------------------------------
#
#  Return an "authorized required" reply to the client.  This will force
#  prompting for username/password.
#
proc cgi_return_auth_required {{realm "Open Market Account"}} {
set msg {HTTP/1.0 401 Unauthorized
Content-type: text/html
WWW-Authenticate: Basic realm="$realm"

[cgi_title "Authorization Required"]
Browser not authentication-capable or authentication failed.<p>
The username and password you entered were not
valid for access to the $realm.
[cgi_end]
}
  return [subst $msg]
}

# ---------------------------------------------------------------------------
#
#  -- Returns an HTTP redirect to the client
#
#    Many clients have length restrictions on the redirect URL,
#    so we may need to return an intermediate page if the URL is
#    longer than what the client can handle.
#
proc cgi_return_redirect {url title desc linktext} {
    global env

    switch -glob -- $env(HTTP_USER_AGENT) {
        {NCSA Mosaic for the X Window System*}  {set maxlen 256}
        {Lynx*}                                 {set maxlen 1024}
        default                                 {set maxlen 128}
    }

    if {[string length $url] < $maxlen} {
        return [subst {HTTP/1.0 302 Found
Location: $url
Content-type: text/html

[cgi_title "Redirect"]
You appear to have a very old World Wide Web browser, that doesn't
support the redirect operation.  We strongly suggest upgrading to
the latest software.<p>
Here's the <a href=\"$url\">actual document</a>.
[cgi_end]}]}

    subst {HTTP/1.0 200 OK
Content-type: text/html

[cgi_title $title] $desc
<p><a href="$url">$linktext</a>
[cgi_end]}
}
