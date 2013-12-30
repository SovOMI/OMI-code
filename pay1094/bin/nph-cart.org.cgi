#!/usr/local/bin/tclsh-misc
#
#  Part of payment system prototype
#
#   This is the CGI script that takes a customer name
#   and produces a shopping cart statement
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

sysloginit nph-cart.cgi pid

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
    
    if {![cgi_fieldcheck fields id]} {
	cgi_error GET_missing_id [array_to_list fields]
    }
    
    if {$user(principal_id) != $fields(id)} {
	cgi_error user_mismatch [concat [array_to_list fields] \
		[list user $user(principal_id)]]
    }
    if {![cgi_fieldcheck fields op]} {
    }
	
    switch $fields(op) {
	remove {
	    if {![cgi_fieldcheck fields cid]} {
		cgi_error op_remove "missing cid"
	    }
	    db_delete_row scart_item $fields(cid)
	    puts [subst $returnpage]
	    exit
	}
	removecart {
	    if {![cgi_fieldcheck fields cid]} {
		cgi_error op_removecart "missing cid"
	    }
	    execsql "delete from scart_item \
		    where shoppingcart_id = $fields(cid)"
	    db_delete_row shoppingcart $fields(cid)
	    puts [subst $returnpage]
	    exit
	}
	purchase {
	    if {![cgi_fieldcheck fields cid]} {
		cgi_error op_purchase "missing cid"
	    }
	    puts [subst $purchasemsg]
	    exit
	}
    }
}


}
    
