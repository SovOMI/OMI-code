#
# This file contains subroutines for shopping cart management
#

proc cart_make_payurl {total nitems currency} {
    global payment_server_root cart secretkey 
    set paylinkbase "$payment_server_root/bin/nph-payment.cgi?"
    set fields(url) $payment_server_root/bin/nph-cartaccess.cgi
    set fields(amt) $total
    set fields(cc) $currency
    regsub "\.0$" $cart(shoppingcart_id) "" cartid
    set fields(domain) cart-$cartid
    set fields(desc) "$nitems items"
    set fields(fmt) get

    set paylink [sec_create_ticket secretkey fields]
    return $paylinkbase$paylink
}

proc my_self_link { l } {
  global env
  set old $env(SCRIPT_NAME)
  set env(SCRIPT_NAME) /bin/nph-cart.cgi
  set result [cgi_self_link $l]
  set  env(SCRIPT_NAME) $old
  return $result
}

proc send_cart_item { a_ci } {
    upvar $a_ci ci
    global secretkey user
    global cart_total cart_items cart_currency
    incr cart_items
    if {[string compare $cart_currency ""] == 0} {
	set cart_currency $ci(currency)
    } else {
	if {[string compare $cart_currency $ci(currency)] != 0} {
	    set cart_error "Cart contains multiple currencies!"
	}
    }
    set cart_total [expr $cart_total + $ci(amount)]
    set url [pay_build_smartlink $ci(domain) $ci(url) \
	    [expr [currenttime] + 86400] \
	    $ci(scart_item_id) secretkey int]
    set purchase [my_self_link [list \
	    [list op purchase] \
	    [list cid $ci(scart_item_id)] \
	    [list id $user(principal_id)] \
	    ]]
    set remove [my_self_link [list \
	    [list op remove] \
	    [list cid $ci(scart_item_id)] \
	    [list id $user(principal_id)] \
	    ]]
    puts "<br><a href=\"$purchase\"> \
		<img src=\"../images/buy-item-button.gif\" \
		alt=\"\[ Buy Item \]\"></a> \
		<a href=\"$remove\"> \
		<img src=\"../images/delete-item-button.gif\" \
		alt=\"\[ Delete Item \]\"></a> \
		<a href=\"$url\"> $ci(description) ... $ci(amount) \
	    ($ci(currency))</a>"
}


proc send_invoice_item { a_ci } {
    upvar $a_ci ci
    global secretkey user
    global cart_total cart_items cart_currency
    incr cart_items
    set cart_currency $ci(currency)

    set cart_total [expr $cart_total + $ci(amount)]
    if {[string length $ci(aurl)] > 0} {
	set url [pay_build_smartlink $ci(domain) $ci(aurl) \
		$ci(expiration) \
		$ci(scart_item_id) secretkey int]
    } else {
	set url [pay_build_smartlink $ci(domain) $ci(url) \
		[expr [currenttime] + 86400] \
		$ci(scart_item_id) secretkey int]
    }
    puts "<li> <a href=\"$url\">   $ci(description) ... $ci(amount) \
	    ($ci(currency))</a>"
}


# send the user a view of the cart
# if shoppingcart_id is present, restrict the view to only
# the relevant manufacturer
#
# if scart_item_id is present, explain that this is the newest item
#
proc send_cart_view { a_user {shoppingcart_id 0} {scart_item_id 0}} {
    upvar $a_user user
    global secretkey sybmsg merchant cart
    global cart_total cart_items cart_currency

    # first build a list of the cart id's to represent
    if {$shoppingcart_id != 0} {
	lappend idlist $shoppingcart_id
    } else {
	set query "select * from shoppingcart \
		where principal_id = $user(principal_id) \
		and purchased = 0 \
		and (expiration_date - [currenttime]) > 0"
	set result [execsql "$query"]
	while {$sybmsg(nextrow) == "REG_ROW"} {
	    loadresult ctemp
	    if {$sybmsg(nextrow) != "REG_ROW"} { break }
	    lappend idlist $ctemp(shoppingcart_id)
	}
    }

    puts [cgi_begin]
	puts "<TITLE>Shopping cart for $user(principal_name)</TITLE>"
	puts "<H1><IMG SRC=\"../images/omicon50.gif\" ALT=\"Open Market\">"
	puts "Shopping cart for $user(principal_name)</H1>"

    # 
    puts {Your shopping cart can include items from one or more
    merchants.  Each item is a link that will take you back to
    the page on which that item is found.  In addition, each item
    has a "put back" button that will remove the item from the shopping
    cart.  Finally, you can purchase the items from each merchant.<p>
    A shopping cart will remain active for 24 hours.<p>}

    if {![info exists idlist]} {
	puts "Your shopping cart is empty."
	puts [cgi_end]
	exit
    }

    foreach cartid $idlist {
	if {![db_read_row shoppingcart $cartid cart]} {
	    cgi_error send_cart_view "Cart $cartid gone missing"
	}

	if {![db_read_row principal $cart(merchant_id) merchant]} {
	    cgi_error send_cart_view "Cart $cartid merchant gone missing"
	}
	pay_prin_to_key merchant secretkey
	set cart_total 0
	set cart_items 0
	set cart_currency ""
	puts "<h2>Items from $merchant(principal_name)</h2>"
	puts "These items will remain in the shopping cart until \
		[ctime $cart(expiration_date)]<p>"
	puts "<ul>"
	set query "select * from scart_item \
		where shoppingcart_id = $cartid"
	db_map_query $query send_cart_item
	puts "</ul>"

	puts "[cgi_link \
		[cart_make_payurl $cart_total $cart_items $cart_currency] \
		"<IMG SRC=\"../images/buy-all-button.gif\" ALT=\"Buy all items\"> \
		from $merchant(principal_name), \
		total is $cart_total ($cart_currency)"]<br>"
    }

	puts "[cgi_link [my_self_link \
		[list [list op removecart] [list cid $cartid] \
		[list id $user(principal_id)] \
		] \
		] "<IMG SRC=\"../images/empty-cart-button.gif\" ALT=\"Empty cart\"> \
		of all items from $merchant(principal_name)"]<br>"

    puts [cgi_end]
}



# send the user a view of the purchased collection of goods
# the arguments are the shopping cart id and tid
proc send_invoice_view { a_user shoppingcart_id tid} {
    upvar $a_user user
    global secretkey sybmsg merchant cart
    global cart_total cart_items cart_currency

    # first build a list of the cart id's to represent
    set cartid $shoppingcart_id


    if {![db_read_row shoppingcart $cartid cart]} {
	cgi_error send_invoice_view "Cart $cartid gone missing"
    }
    if {![db_read_row principal $cart(merchant_id) merchant]} {
	cgi_error send_invoice_view "Cart $cartid merchant gone missing"
    }
    if {![db_read_row transaction_log $tid trans]} {
	cgi_error send_invoice_view "Cart $cartid transaction gone missing"
    }
    pay_prin_to_key merchant secretkey
    set cart_total 0
    set cart_items 0
    set cart_currency ""
    puts [cgi_begin "Goods purchased from $merchant(principal_name)"]

    puts "<h2>Items</h2>"
    puts {These are the items included in this purchase.  Each item
    is a link that will take you back to the page from which the
    item was purchased.}
    puts "<ul>"
    set query "select * from scart_item \
	    where shoppingcart_id = $cartid"
    db_map_query $query send_invoice_item
    puts "</ul>"


    puts [cgi_end]

}
