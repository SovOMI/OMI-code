#
#  Useful library routines for generating HTML
#
#  Andrew Payne
#  payne@openmarket.com
#

 #
#  The merchant key and ID used for all files in this demo:
#
set merchantkey "testmerchant"
set merchantid  testmerchant@openmarket.com

# ---------------------------------------------------------------------------
#
#  Shortcut routines for making HTML--these routines return their result
#
proc title {text} {
    return "<title>$text</title><h1>$text</h1>"
}

proc signature {} {
    global merchant_server_root merchant_demo_path
set msg {<p><hr><A HREF="$merchant_server_root/">
<IMG ALIGN="top" SRC="$merchant_server_root$merchant_demo_path/images/omicon32.gif" ALT="OMI Home"></A>
<I>Copyright &#169; 1994 Open Market, Inc. All Rights Reserved.</I>
}
    return [subst $msg]
}

#
#  Generate a link to the feedback pages about the specified subject
#
proc feedback-link {text subject} {
    global payment_server_root
    set subject [url-escape $subject]
    return "<a href=\"$payment_server_root/bin/feedback.cgi?$subject\">$text</text></a>"
}

#
#  Generate a link to the dollar sign image
#
proc dollar-image {} {
    return "<img src=\"/images/dollar.gif\">"
}

#
#  Generate a link to the SmartStatment
#
proc online-statement-link {} {
    global payment_server_root

    return "<a href=\"$payment_server_root/bin/nph-statement.cgi\">
		    View your SmartStatement</a>"
}

# ---------------------------------------------------------------------------
#
#  Shorthand for starting and ending HTML documents
#   (note that these routines write to stdout--they are intended to be
#   used in CGI scripts)
#
proc begin-html {title} {
    puts "Content-type: text/html"
    puts ""
    puts [title $title]
}

proc end-html {} {
    puts [signature]
}


# Create a user ticket

proc userurl {url id domain} {
    global env merchant_server_root merchant_demo_path
#    set nv(expire)  [expr [currenttime]+60000]
    set nv(domain) $domain
    set nv(principal) $id
    set secret_key testmerchant
    set hash [create-ticket "$secret_key $env(REMOTE_ADDR) $domain" nv]
    return "$merchant_server_root/@$hash$merchant_demo_path/members/$url"
}

# Write a hypertext link

set linklist ""
proc link {args} {
        global linklist
        parseargs argvals {-url -name} $args
        append linklist "<LI> <A HREF=\"$argvals(-url)\">$argvals(-name)</A>\n"
}

# Parse an argument vector.
# Usage: parseargs array-name list-of-options arg-vector
#   array-name is the name of an array that will get the options
#   list-of-options is a list of option names
#   arg-vector is the argument list to be processed.

proc parseargs {name argnames arglist} {
        upvar $name a
        foreach i $argnames {
                set a($i) ""
        }
        for {set i 0} {$i < [llength $arglist]} {incr i} {
                set opt [lindex $arglist $i]
                incr i
                set val [lindex $arglist $i]
                set a($opt) $val
        }
}

# Make hypertext links from a file.  Links are given on two lines:
# URL and then name.
# XXX needs error checking
 
#proc makelinks {filename} {
#       set f [open $filename r]
#       set links ""
#       while {[gets $f url] >= 0} {
#               gets $f name
#               append links "<LI> <A HREF=\"$url\">$name</A>\n"
#       }
#       return $links
#}      
        
proc makelinks {filename} {
}        
        
proc load {file} {
        global linklist
        source $file
        set retval $linklist
        set linklist ""
        return $retval
}
