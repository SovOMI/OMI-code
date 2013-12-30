#!/usr/local/bin/tclsh-misc
#
#  Part of payment system prototype
#
#   This is the CGI script that takes a customer name
#   and produces a smart statement
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
source $library/smartstatement.tcl

sysloginit nph-statement.cgi pid

open_database_as_statement

#  Verify user identity

pay_getuser user

# OK, now we have a valid account, so build the statement



# handle processing of commands
if {![info exists env(QUERY_STRING)]} { set env(QUERY_STRING) ""}

# parse the GET fields, if any, into fields
if {[string length $env(QUERY_STRING)] == 0} {
    smart_statement user
} else {
    cgi_parse_querystring $env(QUERY_STRING) fields omi omisecretkey
    
    if {![cgi_fieldcheck fields id]} {
	cgi_error GET_missing_id [array_to_list fields]
    }
    
    if {$user(principal_id) != $fields(id)} {
	cgi_error user_mismatch [concat [array_to_list fields] \
		[list user $user(principal_id)]]
    }
    if {![cgi_fieldcheck fields op]} {
	cgi_error missing_op [array_to_list fields]
    }
	
    switch $fields(op) {
	interval {
	    if {![cgi_fieldcheck fields {first last}]} {
		cgi_error op_remove "missing first or last"
	    }
	    smart_statement user $fields(first) $fields(last)
	    exit
	}
    }
    
}

}
