#!/usr/local/bin/tclsh-misc
#
#  Part of payment system prototype
#
#   This is the CGI script that takes URLs, processes them as payment orders,
#   and returns a redirect to the real URL.
#
#  Andrew Payne
#  payne@openmarket.com
#

#
#  Load support routines.
#
set library {../lib}
source $library/mall.conf
source $library/log.tcl
source $library/database.tcl
source $library/ticket.tcl
source $library/cgilib.tcl
source $library/payment.tcl

run_with_log {

sysloginit nph-p1.cgi pid

# open database for read-write use
open_database

#
# Write out the details of the payment order, in HTML  (this routine is
# used in the various (return-*) routines)
#
proc payment_details {} {
    global merchant fields
set msg {<p><blockquote><b>Merchant:</b> $merchant(principal_name)<br>
<b>Description:</b> $fields(desc)<br>
<b>Amount:</b> $fields(amt) ($fields(cc) currency)<br>
</blockquote><p>
}
    return [subst $msg]
}


#
# Write out the details of the payment order, in HTML  (this routine is
# used in the various (return-*) routines)
#
proc payment_details_pre {} {
    global merchant fields
set msg {Merchant: $merchant(principal_name)
Description: $fields(desc)
Amount: $fields(amt) ($fields(cc) currency)
}
    return [subst $msg]
}

# ---------------------------------------------------------------------------
#
#  Return an pre-confirmation page to the client.  This page is returned
#  before we know the identity of the user, and gives the user the 
#  opportunity to establish an account if they don't already have one.
#
# new_account_link and demo_details are imported from mall.conf
#
proc return_confirm {confirm_url} {
    global new_account_link demo_details

set msg {[cgi_begin "Open Market Payment"]
You have selected an item that requires payment:
[payment_details]
If you have an Open Market account, click on "continue" below
and you will be prompted for your
account name and password.  If you do not have an account, you can
establish one on-line and return to this page to continue your
purchase.
<p><a href="$new_account_link">
<img src ="/images/open-button.gif"> an account on-line.</a><p>
<a href="$confirm_url"><img src="/images/continue-button.gif">
with payment transaction.</a>
$demo_details
[cgi_end]
}
    puts [subst $msg]
    exit
}

# ---------------------------------------------------------------------------
#
#  Return a form rejecting the challenge response that was entered.
#
proc return-bad-response {} {
set msg {[cgi_begin "Open Market Bad Response"]
You have entered an invalid payment reponse.  Without the 
correct response, we cannot process your payment transaction.
<p>Please return to the previous page (using your browser's
``Back'' function) and enter the correct information.
[cgi_end]
}
    puts [subst $msg]
    exit
}
    
set response_bad {[cgi_begin "Open Market Bad Response"]
You have entered an invalid response to a challenge.  Without the 
correct response, we cannot process your payment transaction.
<p>Please return to the previous page (using your browser's
``Back'' function) and try again.
[cgi_end]
}

set response_retry_limit {[cgi_begin "Open Market Retry Limit"]
For security reasons, we only allow a certain number of tries
to get a correct response.  We are unable to process your transaction.
[cgi_end]
}

set payment_duplicate {[cgi_begin "Duplicate Payment Declined"]
We have received an HTTP request which would have the effect of
duplicating a payment.  The most frequent cause of this is 
"backing up" with your browser and re-fetching a page by accident.<p>
Open Market systems detect this case and return this page instead
of allowing a duplicate payment.  (This is subtly different than
deliberately buying something twice - which is fine by us.)<p>
Thank you for using Open Market.
[cgi_end]
}
# ----------------------------------------------------------------------------
#
#  Parse the URL:  extract the hash (signature) from the front of the URL,
#  and parse the remainder of the URL.
#

# this block of code sets up default values for important fields
set fields(url) ""
set fields(kid) ""
set fields(cc) "US"
set fields(amt) ""
set fields(hash) ""
set fields(domain) ""
# default expiration is 30 days
set fields(expire) "2592000"
set fields(desc) "(unknown transaction)"
# last valid time
set fields(valid) 2147483647
set fields(fmt) "int"
set fields(billto) 0

# parse the URL, validate key and signature
cgi_parse_querystring $env(QUERY_STRING) fields secretkey merchant

if [info exists fields(mkid)] {
    set kid_split [split $fields(mkid) .]
    if {[llength $kid_split] != 2} {
	cgi_error verify_signature "kid_split bad format: $env(QUERY_STRING)"
    }
    set mid [lindex $kid_split 0]
    set kid [lindex $kid_split 1]
    if {[db_read_record secretkey secretkey_id $kid secretkey] != 1} {
	cgi_error mkid "bad key $mkid: $env(QUERY_STRING)"
    }

    if {$mid != $secretkey(principal_id) } {
	cgi_error mkid "merchant keyid mismatch: $env(QUERY_STRING)"
    }

    if {[db_read_record principal principal_id $mid merchant] != 1} {
	cgi_error mkid "bad merchant $mid: $env(QUERY_STRING)"
    }

}

# check for expiration of the payment URL
if {([currenttime] - $fields(valid)) > 0} {
    cgi_error validuntil "expired payment URL: $env(QUERY_STRING)"
}


# ---------------------------------------------------------------------------
#
#  If the user ID wasn't supplied (i.e. it hasn't been cached by the
#  client) and the "preconf" field doesn't exist (or is expired), return 
#  a pre-confirmation page.  This page lists the merchant, item, and amount,
#  and asks the user to continue with the payment transaction.
#
#  This mechanism exists so that users without OMI accounts have an opportunity
#  to jump off and establish one.
#
if {![info exists env(REMOTE_USER)]} {
    if {![info exists fields(preconf)] || ($fields(preconf) < [currenttime])} {
	set fields(preconf) [expr [currenttime]+600]
	return_confirm [cgi_self_link {} fields]
    } else {
	cgi_return_auth_required
    }
}

# ---------------------------------------------------------------------------
#
#  Verify user stuff:
#	- user ID was supplied
#	- valid user ID
#	- valid user password
#
#  Any errors here are reflected back to the client with an "authorization
#  required" message, which will make the client prompt for username/password.
#
pay_getuser user

if {![info exists fields(dupok)]} {
    set msg {[cgi_begin "Open Market Payment"]
You have clicked on a link which requires payment:<br>
[payment_details]
but our records show that you have already purchased this item.
<p>It may be that you would like to buy the item again, or
it may have happened by accident.   For example, you may be attempting
to purchase a subscription which overlaps an earlier subscription.<p>
You can:
<ul>
<li> <a href="$surl">Go directly to the previous item</a>
<li> <a href="$purl">Go ahead and buy the item again</a>
</ul>
[cgi_end]
}
    set dupid [duplicate_check $user(principal_id) $merchant(principal_id) \
	    $fields(domain)]
    if {$dupid != 0} {
	db_read_record transaction_log transaction_log_id $dupid old
	set surl [pay_build_smartlink $old(domain) $old(url) \
		[expr $old(transaction_date) + $old(expiration)] \
		$dupid secretkey $fields(fmt)]

	set fields(dupok) [uid_get 1 [expr [currenttime] + 600]]
	set purl [cgi_self_link {} fields]
	puts [subst $msg]
	exit
    }
} else {
    # dupok field, so validate it!
}

#
# fetch principal_account records for both buyer and merchant
# in order to get the limit fields
#
#
# get primary account for user and merchant
#
proc defaultaccount { pid a_ary} {
    upvar $a_ary ary
    set cmd "select * from principal_account \
	    where principal_id = $pid \
	    and flags = \"p\""
    return [db_query_read $cmd ary]
}

if {![defaultaccount $user(principal_id) useraccount]} {
    cgi_error defaultaccount "No account for user $user(principal_id)"
}

if {$fields(billto) != 0} {
    set cmd "select * from principal_account \
	    where principal_id = $merchant(principal_id) \
	    and account_id = $fields(billto)"
    set rc [db_query_read $cmd merchantaccount]
    if {$rc == 0} {
	cgi_error billto "bad account: $env(QUERY_STRING"
    }
} else {
    if {![defaultaccount $merchant(principal_id) merchantaccount]} {
	cgi_error defaultaccount \
		"No account for merchant $merchant(principal_id)"
    }
}

#
# useraccount is the principal_account field for the user
# merchantaccount is the principal_account field for the merchant

# ---------------------------------------------------------------------------
#
#  Check transaction amount:
#	- positive, but not excessive
#	- doesn't exceed the merchant's floor limit
#
#
if {$fields(amt) < 0 || $fields(amt) > $merchantaccount(max_threshold)} {
    cgi_error merchantlimit "$env(QUERY_STRING)"
}

#
# check user limits
#
if {$fields(amt) > $useraccount(max_threshold)} {
    set msg {[cgi_begin "Account Limit Exceeded"]
Your account profile is set up so that the maximum amount of a single 
transaction is $useraccount(max_threshold).  This transaction is for
$fields(amt), which is too much.  You can change your own account
profile by going to customer service.
[cgi_end]
}
    puts [subst $msg]
    exit
}

#
# challenge
#
if {![info exists fields(response)] && \
	($fields(amt) >= $useraccount(confirm_threshold))} {
    # find out if the user has a scheme registered
    if {[db_query_read "select * from principal_authentication \
	    where principal_id = $user(principal_id)" a]} {
	set scheme $a(scheme)
    } else {
	set scheme uc
    }
    set fname $library/auth-$scheme.tcl
    if {![file exists $fname]} {
	cgi_error challenge "File missing $fname"
    }
    source $fname
    auth_getchallenge user challenge
    log "$scheme challenge $challenge(challenge_name) response \
	    $challenge(challenge_value)"
    set fields(response) \
	    [md5 "[string tolower $challenge(challenge_value)] $secretkey(secret_key)"]
    set fields(as) $scheme
#	set fields(postconf) [expr [currenttime]+600]
    set fields(uid) [uid_get 2 [expr [currenttime] + 600]]
    auth_return_challenge [cgi_self_link {} fields] $env(REMOTE_USER) \
	    $challenge(challenge_name)
}



# ---------------------------------------------------------------------------
#
#  If a response was requested, check response.  This should be a POST
#  method, and the hash of the reponse should match the expected field.
#  If they don't deny payment and return an error.
#
#  The response needs some "salt", instead of being a simple MD5 hash
#  of the expected result, to prevent dictionary attacks.
#
if [info exists fields(as)] {
    set fname $library/auth-$fields(as).tcl
    if {![file exists $fname]} {
	cgi_error challenge "File missing $fname"
    }
    source $fname
    # now the authentication scheme procedures are defined
    if {$env(REQUEST_METHOD) == "POST"} {
        if {![info exists env(CONTENT_LENGTH)]} { set env(CONTENT_LENGTH) 0 }
	cgi_parse [read stdin $env(CONTENT_LENGTH)] postfields
    } else {
	# now check for a response in the query
	set query [split $env(QUERY_STRING) ?]
	if {[llength $query] > 1} {
	    cgi_parse [lindex $query 1] postfields
	} else {
	    cgi_error_list [list \
		    [list prog no_response] \
		    [list get  $env(QUERY_STRING)]]
	}
    }

    switch -- [auth_validateresponse fields postfields] {
	-2 {
	    puts [subst $response_retry_limit]
	    exit
	}
	-1 {
	    puts [subst $response_bad]
	    exit
	}
    }
    auth_nextchallenge $user(principal_id)
}

#
# last backstop, check the uid, if there is one, to reject bad duplicates
#
if [info exists fields(dupok)] {
    if {[uid_valid $fields(dupok)] == 0} {
	# this is a duplicate, and probably innocuous, so just return
	# a friendly page, but log the event, for now
	puts [subst $payment_duplicate]
	syslog_log [list \
		[list prog uid_dup] \
		[list get $env(QUERY_STRING)]]
	exit
    }
}


#
#  Enter the transaction into the transaction database
#
set date [currenttime]
set tid [enter_transaction $user(principal_id) $merchant(principal_id) \
    $useraccount(account_id) $merchantaccount(account_id) \
    $fields(amt) $fields(cc) $env(REMOTE_ADDR) $fields(domain) \
    $fields(expire) \
    $fields(url) $fields(desc) $date $fields(fmt)]

# ----------------------------------------------------------------------------
#
#  Write a URL that grants access to this domain for a client
#  coming from the specified IP address.  Return a redirect that reflects
#  the client to the real URL. Put the transaction id into the
#  access URL in case we want to understand its origin
#

set aurl(domain) $fields(domain)
set aurl(expire)  [expr $date + $fields(expire)]
set aurl(ip) $env(REMOTE_ADDR)
set aurl(tid) $tid

set url [pay_accessurl $fields(url) aurl secretkey $fields(fmt)]

puts [cgi_return_redirect $url "Payment Accepted" \
    "Your payment has been accepted and processed." \
    "Select here to continue."]

}
# end of run_with_log

# XXX need to use payment server keys for intermediate steps

