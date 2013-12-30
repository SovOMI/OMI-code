#
#  Payment related library routines
#
#  L. Stewart
#  stewart@openmarket.com
#
# originally by payne

if [info exists env(SECRET_KEY)] {set secret_key $env(SECRET_KEY)}
if [info exists env(SECRET_KEY_ID)] {set secret_key_id  $env(SECRET_KEY_ID)}

# ---------------------------------------------------------------------------
#
#  Payment stuff
#
#
#  Base link of all URLs referring to the payment system:
#
set paylinkbase "$payment_server_root/bin/nph-payment.cgi?"

proc paylink {args} {
    parseargs argvals {-text} $args
    set url [payurl $args]
    return "<a href=\"$url\">$argvals(-text)</a>"
}

# Create a payment URL.  This is used by paylink and others.

proc payurl {args} {
    global paylinkbase secret_key secret_key_id
    parseargs nv {-cost -url -domain -ttl -desc} [lindex $args 0]
    set fields(url) $nv(-url)
    set fields(amt) $nv(-cost)
    set fields(kid) $secret_key_id
    set fields(domain) $nv(-domain)
    set fields(expire) $nv(-ttl)
    set fields(desc) $nv(-desc)
    set paylink [create-ticket $secret_key fields]
    return $paylinkbase$paylink
}

#
# Create an access URL
#
proc accessurl { url domain expire ip kid mid  key} {
    # split the url
    if {$domain != ""} {
	regexp {([^\/]+\/\/[^\/]+)\/(.*)} $url dummy front end
	if { $expire != 0 } { set tmp(expire) $expire }
	set tmp(domain) $domain
	if {$ip != ""} { set tmp(ip) $ip }
	set tmp(kid) [pay_makekeyidpair $mid $kid]
	set ticket [create-ticket $key tmp]
	set result "$front/@$ticket/$end"
    }
}

#
# expected fields: expire domain ip
proc pay_accessurl {url a_fields a_secretkey} {
    upvar $a_fields fields
    upvar $a_secretkey secretkey

    regexp {([^\/]+\/\/[^\/]+)\/(.*)} $url dummy front end
    set fields(kid) [pay_makekeyidpair $secretkey(principal_id) \
	    $secretkey(secretkey_id)]
    set ticket [create-ticket $secretkey(secret_key) fields]
    set result $front/@$ticket/$end
}


# ---------------------------------------------------------------------------
#
# construct a smart link to the thing purchased, for purposes
# of putting into a smart statement
#
proc pay_build_smartlink {domain url expiration a_secretkey} {
  global env 
  upvar $a_secretkey secretkey

  if {$domain != ""} then {
      set nv(domain) $domain
      # origin=ss means this URL came from the smart statement
      set nv(origin) ss
      set nv(expire) $expiration
      set nv(ip) $env(REMOTE_ADDR)
      pay_accessurl $url nv secretkey
  } else {
      set result url
  }
}

#
# build a keyid suitable for transmission
#
proc pay_makekeyidpair { mid kid } {
  regsub "\.0$" $mid "" mid
  regsub "\.0$" $kid "" kid
  set result $mid.$kid
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


# ---------------------------------------------------------------------------
#
#  Verify merchant stuff:
#	- valid merchant ID
#	- valid merchant signature on payment URL
#
#  Any errors here are fatal (i.e. someone's been mucking with the URL)
#

proc pay_verify_signature {hash remainder a_fields a_secretkey a_merchant} {
    upvar $a_fields fields
    upvar $a_secretkey secretkey
    upvar $a_merchant merchant
    if {![info exists fields(kid)]} {
	log "payment url received with no kid"
	return 0
    }
    set kid_split [split $fields(kid) .]
    if {[llength $kid_split] != 2} {
	log "kid_split $kid_split bad format"
	return 0
    }
    
    set mid [lindex $kid_split 0]
    set kid [lindex $kid_split 1]
    if {[db_read_record secretkey secretkey_id $kid secretkey] != 1} {
	log "failed to read key $kid from database"
	return-error
    }

    if {$mid != $secretkey(principal_id) } {
	log "merchant keyid mismatch"
	return-error
    }

    if {[db_read_record principal principal_id $mid merchant] != 1} {
	log "failed to read merchant $mid record from database"
	return 0
    }

    set signature [md5 "$secretkey(secret_key) $remainder"]
    if {[string compare $hash $signature] != 0} {
	log "Invalid merchant signature"
	return 0
    }
    return 1
}

#
# get user name and password
#

proc pay_getuser {a_user } {
    global env
    upvar $a_user user
    if {![info exists env(REMOTE_USER)]} {
	return-auth-required
    }
    
    if [catch {get_principal $env(REMOTE_USER) user}] {
	syslog local0 info "Invalid user id: $env(REMOTE_USER)"
	return-auth-required 
    }
    if {$env(REMOTE_PASSWD) != $user(access_password)} {
	syslog local0 info "Invalid password for $env(REMOTE_USER):  expected '$user(access_password)', got'$env(REMOTE_PASSWD)'"
	return-auth-required 
    }
}


#
# copy key fields from principal record to secretkey record
#
proc pay_prin_to_key {a_prin a_key} {
  upvar $a_prin prin
  upvar $a_key key
  set key(principal_id) $prin(principal_id)
  set key(secretkey_id) $prin(secretkey_id)
  set key(secret_key) $prin(secret_key)
}



# duplicate_check scans the duplicate table for any
# record where the initiator matches cid and the
# benificiary matches mid and the domain matches domain
# and the access has not yet expired.
proc duplicate_check { cid mid domain } {
  global syb
  set now [currenttime]
  case [execsql "select transaction_log_id from duplicate
    where (initiator = $cid 
    AND benificiary = $mid AND domain = \"$domain\" AND
    expiration > $now)"] {
        {NO_MORE_ROWS} {
	    return 0
	}
        {REG_ROW} {
	    return [sybnext $syb]
	}
    }
}


#####
#
#####

# Enter a transaction in the database
#
# cid: numeric customer id
# mid: numeric merchant id
# amount: money
# ipaddr: format xx.xx.xx.xx as a string
# domain: varchar(40)
# expiration: a delta interval in seconds
# url: varchar(255)
# description varchar(40)
#
# at the moment, the only transaction code is "   p" for payment
# this will be extended for returns, disputes, preauth, credit, etc.

proc enter_transaction {initiator benificiary from_account to_account
  amount currency ip_address domain expiration url description date} {
  #
  # create record for transaction_log
  #
  set t(amount)            $amount
  set t(currency)          $currency
  set t(transaction_date)  $date
  set t(initiator)         $initiator
  set t(benificiary)       $benificiary
  set t(from_account)      $from_account
  set t(to_account)        $to_account
  set t(transaction_type)  "   p"
  set t(ip_address)        $ip_address
  set t(domain)            $domain
  set t(expiration)        $expiration
  set t(url)               $url
  set t(description)       $description
  #
  # insert record into transaction_log
  #
  set tid [insert_row transaction_log t]
  #
  # now put the requisite information into the duplicate table
  #
  set d(transaction_log_id) $tid
  set d(initiator) $t(initiator)
  set d(benificiary) $t(benificiary)
  set d(domain) $t(domain)
  set d(expiration) [expr $t(expiration) + $date]
  insert_row duplicate d
}
