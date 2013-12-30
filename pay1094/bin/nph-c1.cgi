#!/usr/local/bin/tclsh-misc
#
#   This is the CGI script that permits a buyer to add an item
#   to a shopping cart.
#
#   L. Stewart
#   stewart@openmarket.com
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

# handle errors
run_with_log {

set toomany {[cgi_begin "Too many items"]
We're sorry, shopping carts can only hold 25 items,
so we are unable to add one more.<p>
You can use the "back up" feature of your browser
to return to the page you were looking at before.
[cgi_end]
}

#
# new_account_link are imported from mall.conf
#
proc return_confirm {confirm_url} {
    global new_account_link

set msg {[cgi_begin "Open Market Shopping Cart"]
You have selected an item to be added to your shopping cart.<p>
If you have an Open Market account, click on "continue" below
and you will be prompted for your
account name and password.  If you do not have an account, you can
establish one on-line and return to this page to continue.

<p><a href="$new_account_link">
<img src ="/images/open-button.gif"> an account on-line.</a><p>
<a href="$confirm_url"><img src="/images/continue-button.gif">
with your transaction.</a>
[cgi_end]
}
    puts [subst $msg]
    exit
}


# define default logging headers
sysloginit nph-c1.cgi pid

# open database in read-write mode
open_database

#
# process the URL, to see if it is OK
#

# this block of code sets up default values for important fields
set fields(url) ""
set fields(aurl) ""
set fields(kid) ""
set fields(cc) "US"
set fields(amt) ""
set fields(domain) ""
# default expiration is 30 days
set fields(expire) "2592000"
set fields(desc) "(unknown transaction)"
# last valid time
set fields(valid) 2147483647
set fields(billto) 0
set fields(detail) ""
set fields(qty) 1
#
# XXX what about fmt?
#

# parse the URL, validate key and signature
cgi_parse_querystring $env(QUERY_STRING) fields secretkey merchant

# check for expiration of the payment URL
if {([currenttime] - $fields(valid)) > 0} {
    cgi_error validuntil "expired payment URL: $env(QUERY_STRING)"
}

#
#find out who is the user
#

#  If the user ID wasn't supplied (i.e. it hasn't been cached by the
#  client) and the "preconf" field doesn't exist (or is expired), return 
#  a pre-confirmation page.
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

#
# find out if there is an existing shopping cart
# if not, create one
#

set query "select * from shoppingcart \
	where principal_id = $user(principal_id) \
	and merchant_id = $merchant(principal_id) \
	and purchased = 0 \
	and (expiration_date - [currenttime]) > 0"

if {![db_query_read $query cart]} {
    set cart(principal_id) $user(principal_id)
    set cart(merchant_id) $merchant(principal_id)
    set cart(create_date) [currenttime]
    set cart(expiration_date) [expr [currenttime] + 86400]
    set cart(purchased) 0
    db_insert_row shoppingcart cart
}

#
# at this point, there is a shopping cart, maybe with nothing in it
#

#
# The new item is always added to the cart.
#
# XXX denial of service attack!  What happends on add-to-cart at high speed?
# need to limit quantity of items in a cart
#

execsql "select count(*) from scart_item \
	where shoppingcart_id = $cart(shoppingcart_id)"
set count [sybnext $syb]

if {$count >= 25} {
    puts [subst $toomany]
    exit
}

set item(shoppingcart_id)  $cart(shoppingcart_id)
set item(amount) $fields(amt)
set item(currency) $fields(cc)
set item(transaction_date) [currenttime]
set item(domain) $fields(domain)
set item(expiration) $fields(expire)
set item(url) $fields(url)
set item(aurl) $fields(aurl)
set item(description) $fields(desc)
set item(valid_until) $fields(valid)
set item(detail) $fields(detail)
set item(quantity) $fields(qty)
db_insert_row scart_item item

#
# return a view of the cart itself
#
source $library/shoppingcart.tcl

send_cart_view user $item(shoppingcart_id) $item(scart_item_id)

}
# end of run_with_log
