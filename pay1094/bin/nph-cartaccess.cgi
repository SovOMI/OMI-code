#!/usr/local/bin/tclsh-misc
#
#  Part of payment system prototype
#
#   This is the CGI script that takes an access URL
# for a shopping cart.
#  It marks the cart paid, if it isn't already, and causes
#  the order to be sent to the vendor.
#
#  Lawrence C. Stewart
#  stewart@openmarket.com
#

#
#  Load support routines.
#
set library {../lib}
source $library/mall.conf
source $library/log.tcl
run_with_log {

source $library/database.tcl
source $library/ticket.tcl
source $library/cgilib.tcl
source $library/html.tcl
source $library/payment.tcl
source $library/shoppingcart.tcl


set returnpage {[cgi_begin "Operation Completed"]
[cgi_link $env(SCRIPT_NAME) "Return to Shopping Cart"]
[cgi_end]
}

set purchasemsg {[cgi_begin "Purchase"]
This function not implemented yet.<p>
What will happen is that the items from a particular merchant
will be purchased as a unit
and represented as a single item on your smart statement.  The
statement in turn will link back to descriptions of the 
individual items.
<p>[cgi_link $env(SCRIPT_NAME) "Return to Shopping Cart"]
[cgi_end]
}

sysloginit nph-cartaccess.cgi pid

open_database

#  Verify user identity

pay_getuser user

# handle processing of commands
if {![info exists env(QUERY_STRING)]} { set env(QUERY_STRING) ""}

# parse the GET fields, if any, into fields
if {[string length $env(QUERY_STRING)] == 0} {
    # there is no query yet, so this must be the initial entry
    # into the system.	
    #	
    # get necessary information to write tickets
    #
    db_read_record principal access_name \"openmarket@openmarket.com\" omi
    pay_prin_to_key omi omisecretkey
    
    # return a screen with initial choices]
    
    send_cart_view user 
    
} else {
    #
    # process GET string, making sure that it has not been tampered with
    #
    cgi_parse_querystring $env(QUERY_STRING) fields omi omisecretkey
    
    
    if {![cgi_fieldcheck fields {domain expire tid}]} {
	cgi_error GET_missing_id [array_to_list fields]
    }

    # now convert domain into cart id
    regexp {cart-(.*)} $fields(domain) xx cartid
    if {![info exists cartid]} {
	cgi_error bad_cartid [array_to_list fields]
    }
    if {![db_read_row shoppingcart $cartid old]} {
	cgi_error bad_cart [array_to_list fields]
    }
    if {$old(purchased) == 0} {
	set new(purchased) 1
	set rc [db_update_row shoppingcart $cartid old new]
	switch -- $rc {
	    -3 { cgi_error bad_cart }
	    -1 { cgi_error match_error }
	}
	# cart is now marked purchased, and we now need to send the order

    }
    send_invoice_view user $cartid $fields(tid)
 
}


}
    
