#
#
# build smart statement for user
#
# L. Stewart
# stewart@openmarket.com
#



# parray is an array containing the principal record from the
# payment database

# the database should be open as global syb

proc smart_statement { a_prin {first 0} {last 0x7fffffff}} {
  upvar $a_prin user
  global sybmsg env payment_server_root secretkey

    # OK, now we have a valid account, so build the statement
    #

    puts [cgi_begin "Smart Statement for $user(principal_name)"]
    
    puts "Your Smart Statement is a record of recent transactions
you have made on the network. Each line contains the date of the
transaction, the merchant involved, a description of the item purchased,
and the amount. <p> 
You will notice that the item description is in fact a hypertext link. 
Where this link goes depends on what kind of item is involved:\n"

    puts "<ul>
<li>Hard Goods - The link goes to the current order status 
<li> Information product - The link goes to the item you bought 
<li> Information service - The link goes to more information about the item
</ul>
"

puts "In addition, the date field of an item is also a link.  This
link will take you to more detailed information about the item.<p>
"

if {$first == 0} {
    set dtl [fmtclock [currenttime] "%Y %m"]
    set first [convertclock "[lindex $dtl 1]/1/[lindex $dtl 0]"]
    set last [currenttime]
}
set my [fmtclock $first "%B %Y"]

puts "<h2>Transactions in [lindex $my 0], [lindex $my 1]</h2>"

# read all the transactions, and put them into an array

set query  "select * from transaction_log
   where (initiator = $user(principal_id)) and
   (transaction_date >= $first) and
   (transaction_date < $last)"

set result [execsql "$query"]

set numtrans 0
while {$sybmsg(nextrow) == "REG_ROW"} {
  loadresult res.$numtrans
  if {$sybmsg(nextrow) != "REG_ROW"} { break }
  incr numtrans
}

# go through the list, getting merchant information for
# all merchants who appear at least once

set i 0
while {$i < $numtrans} {
  set mvar res.${i}(benificiary)
  set mid [set $mvar]
  if {![info exists merchant.${mid}(principal_id)] } {
      set ok [db_read_record principal principal_id $mid merchant.$mid]
      pay_prin_to_key merchant.${mid} secretkey.${mid}
  }
  incr i
}

db_read_record principal access_name \"openmarket@openmarket.com\" omi
pay_prin_to_key omi secretkey

# now process the whole list
set sum 0
set i 0
  puts "<P>"
while {$i < $numtrans} {
  set tvar res.${i}
  set mid [set ${tvar}(benificiary)]
  if {[string index [set ${tvar}(transaction_type)] 0] == "g"} {
      set fmt get
  } else {
      set fmt int
  }
  set ourl [pay_build_smartlink  [set ${tvar}(domain)] \
	   [set ${tvar}(url)] \
	   [expr [set ${tvar}(transaction_date)] + [set ${tvar}(expiration)]] \
	   [set ${tvar}(transaction_log_id)] secretkey.$mid $fmt]

  set tdate [string range [ctime [set ${tvar}(transaction_date)]] 0 9]
#
#
# create ticket link to detail server
#

  set nv(expire)  [expr [currenttime]+3600]
  set nv(id) [set ${tvar}(transaction_log_id)]
  set nv(ip) $env(REMOTE_ADDR)
  set nv(domain)  detail
  set domain statementdomain

  set detailurl [pay_accessurl $payment_server_root/bin/detail/detail.cgi \
	  nv secretkey]

#

  puts "<a href=\"$detailurl\">$tdate</a>"
  puts " [set merchant.${mid}(principal_name)] "
  puts " <a href=\"$ourl\">[set ${tvar}(description)]</a>"
  puts "amount: \$ [set ${tvar}(amount)]"
  puts "<br>"
  set sum [expr $sum + [set ${tvar}(amount)]]
  incr i
  }


puts [format "<p>Your total is $%6.2f." $sum]
puts "<h2>Previous Statements</h2>"
puts "<ul>"
set tk(op) interval
set tk(id) $user(principal_id)
set tk(last) $first
incr tk(last) -1
set my [fmtclock $tk(last) "%Y %m %e"]
set month [lindex $my 1]
set year [lindex $my 0]
set tk(first) [convertclock "$month/1/$year"]

set my [fmtclock $tk(first) "%B %Y"]

puts "<li> [cgi_link [cgi_self_link {} tk] "[lindex $my 0], [lindex $my 1]"]"

set tk(last) $tk(first)
incr tk(last) -1
set my [fmtclock $tk(last) "%Y %m %e"]
set month [lindex $my 1]
set year [lindex $my 0]
set tk(first) [convertclock "$month/1/$year"]

set my [fmtclock $tk(first) "%B %Y"]

puts "<li> [cgi_link [cgi_self_link {} tk] "[lindex $my 0], [lindex $my 1]"]"

puts "</ul>"
puts "Return to your [cgi_link $env(SCRIPT_NAME) "Newest Statement"]."

puts "<h2>Feedback</h2>"

puts "You can send us comments and suggestions "
puts [feedback-link here SmartStatement]
puts ".<p>"
end-html
exit

}
