#
#  General routines for manipulating URL name/value pairs and ticket 
#  signatures.
#
#  Andrew Payne
#  payne@openmarket.com
#

# ---------------------------------------------------------------------------
#
#  Return a string with "bad" characters escaped using the URL escaping
#  mechanism (i.e. "%XX" where "XX" is the hex representation for the 
#  escaped character).
#
proc url-escape {what} {
    regsub -all {\%} $what "%25" what
    regsub -all {\#} $what "%23" what
    regsub -all {\/} $what "%2F" what
    regsub -all {\&} $what "%26" what
    regsub -all {\=} $what "%3D" what
    regsub -all { }  $what "%20" what
    regsub -all {\+} $what "%2B" what
    regsub -all {\:} $what "%3A" what
    regsub -all {\?} $what "%3F" what
    regsub -all {
} $what "%0A" what
    return $what
}

proc url_unparse {array} {
    upvar $array a
    foreach item [array names a] {
	lappend list "$item=[url-escape $a($item)]"
    }
    return [join $list "&"]
}

# ---------------------------------------------------------------------------
#
#  Create a "ticket" of name/value pairs, signed by a specified hash.
#  The return string format is:
#
#	{hash}:name1=value1&name2=value2...
#
proc create-ticket {key array} {
    upvar $array a

    set list {}
    foreach item [array names a] {
#	if {$a($item) != ""} {
# if != "" deleted by L. Stewart,  what was he thinking?
	    lappend list "$item=[url-escape $a($item)]"
#	}
    }
    set string [join $list "&"]
    return "[md5 "$key $string"]:$string"
}


#
# wrapper for create-ticket which adds the keyid and calls
# create_ticket
#
proc sec_create_ticket {a_key array} {
    upvar $array a
    upvar $a_key key
    set a(kid) [pay_makekeyidpair $key(principal_id) $key(secretkey_id)]
    return [create-ticket $key(secret_key) a]
}


#
# sec_create_ticket_list is the same as sec_create_ticket
# except that nv is a name value list instead of an array
#
proc sec_create_ticket_list {a_secretkey list_nv} {
    upvar $a_secretkey secretkey
    list_to_array $list_nv nv
    return [sec_create_ticket secretkey nv]
}
