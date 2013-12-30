#
#  Common routines for talking to the payment database
#
# L. Stewart
# stewart@openmarket.com

# library has to be defined
source $library/dbschema.tcl

# also requires
# source $library/log.tcl

#
# ----------------------------------------------------------------------------
#
#  Open up the payment system database; leave database handle in $syb
#  use this one for read-write purposes
#
proc open_database {} {
    global syb rwaccount rwpassword
    set syb [sybconnect $rwaccount $rwpassword]
}
#
# ----------------------------------------------------------------------------
#
#  Open up the payment system database; leave database handle in $syb
#  use this one for getting statements or other read-only info
#
proc open_database_as_statement {} {
    global syb roaccount ropassword
    set syb [sybconnect $roaccount $ropassword]
}


# ----------------------------------------------------------------------------
#
#  Run a SQL command, raising a Tcl error (with the SQL error text) if
#  it completed with error
#
# XXX what does the error call do?
#
proc execsql {cmd} {
    global syb sybmsg

    if [catch {sybsql $syb $cmd} msg] {
        error "execsql error <$msg> in $cmd: $sybmsg(msgtext)"
    }
    return $msg
}

# ----------------------------------------------------------------------------
#
#  Load a (row) result into Tcl array
#
proc loadresult {array} {
    global syb sybmsg
    upvar $array a
    set row [sybnext $syb]
    set nextrow $sybmsg(nextrow)
    foreach column [sybcols $syb] {
        set a($column) [lindex $row 0]
        set row [lrange $row 1 end]
    }
   set sybmsg(nextrow) $nextrow
}


#
# read record
#
# select the record in <table> where field = value
# and load all the fields into ary
#
# if the value needs to be quoted in the SQL query, that has to be done
# by the caller
#
proc db_read_record {table field value ary} {
  upvar $ary a
  global syb
  if [info exists a] {unset a}
  case [sybsql $syb "select * from $table where $field = $value"] {
        {NO_MORE_ROWS} {
	    return 0
	}
        {REG_ROW} {
	    loadresult a
	    return 1
	}
    }
}

#
# read a record given a sql query
#
proc db_query_read {query a_ary} {
    upvar $a_ary ary
    global syb
    if [info exists ary] { unset ary }
    case [sybsql $syb $query] {
	{NO_MORE_ROWS} { 
	    return 0 
	}
	{REG_ROW} {
	    loadresult ary
	    return 1
	}
    }
}
    

#
#  Get the principal record for name and return it in array
#
proc get_principal {name array} {
    upvar $array a
    return [db_read_record principal access_name "\"$name\"" a]
}

proc insert_row {table a_ary} {
    upvar $a_ary p
    db_insert_row $table p
}

proc db_insert_row {table valuearray} {
    global syb tables identity
    upvar $valuearray p
    set id ""
    set elements $tables($table)
    set query "insert $table ([join [fieldnames_noid $table] ","])
               values ( [subst $elements] )"
    execsql $query
    sybsql $syb "select @@identity"
    set id [sybnext $syb]
    set p($identity($table)) $id
    syslog_log [list [list prog db_insert_row] [list table $table] \
	    [array_to_list p]]
    return $id
}



# useful routines
#

proc fieldnames {table} {
    global tables identity
    if {![info exists tables($table)]} {
	set res ""
    } else {  
	regsub -all {(\$p\()|\)}  $tables($table) "" x2
	regsub -all {(\\\")} $x2 "" x3
	regsub -all "\[ \t\r\n\]" $x3 "" x4 
	set res [split $x4 ,]
    }
    if [info exists identity($table)] {lappend res $identity($table)}
    set res
}


proc fieldnames_noid {table} {
    global tables identity
    if {![info exists tables($table)]} {
	set res ""
    } else {  
	regsub -all {(\$p\()|\)}  $tables($table) "" x2
	regsub -all {(\\\")} $x2 "" x3
	regsub -all "\[ \t\r\n\]" $x3 "" x4 
	set res [split $x4 ,]
    }
    set res
}



proc quotedfields {table ary} {
    global tables identity
    upvar $ary a
    if [info exists a] { unset a}
    regsub -all {(\$p\()|\)}  $tables($table) "" x2
    foreach el [split $x2 ,] {
	set n [string trim $el]
	set a([string trim $n {\"}]) [regexp  {\\\"[^\"]+\\\"}  $n]
    }
    if [info exists identity($table)] {set a($identity($table)) 0}
}

# the array new has new(field) = value pairs.  Each one is
# checked against the requirements put upon it by the database
# Fields that need to be quoted are quoted.
# If any fields fail the checks, then the procedure returns 0
#
proc db_validatefields { table a_new } {
    upvar $a_new new

    # field validation goes here
    # 1. trim whitespace and quotes
    # 2. check for bad characters
    # 3. check for size limits
    foreach item [array names new] {
	regsub -all {"} $new($item) { } t
	set new($item) [string trim $t]
    }
    
    # quote all fields in new which need it
    quotedfields $table qf
    foreach item [array names new] {
	if {$qf($item)} { set new($item) \"$new($item)\" }
    }
}

#
# db_update_row table id old new
#
# updates one or more fields in a row.
#  table specifies which table
#  id    selects a record (this is a value in the $identity(table) column
#  old and new are arrays containing the old and new values for the fields
#  with old(field) == value
#  a transaction is opened, the record is read, if all the old values
#  match their current values, then the values in new are subsituted.
#  There is no need for the items in old to be the same as those in new
#
#  If a match failure occurs, a syslog entry is written and the procedure
#  returns -1
#  If the update fails, then the procedure returns -2
#  
proc db_update_row {table id a_match a_new} {
    global identity
    upvar $a_match match
    upvar $a_new new
    if {![db_read_record $table $identity($table) $id current]} {
	syslog_log [list [list prog db_update_row-missing] \
		[list table $table] [list id $id]]
	return -3
    }
    foreach item [array names match] {
	# XXX bug here, numerics read as .0
	if {[string compare [string tolower $match($item)] \
		[string tolower $current($item)]] != 0} {
	    syslog_log [list [list prog db_update_row-mismatch] \
		    [list table $table] \
		    [list current [array_to_list current]] \
		    [list match [array_to_list match]] \
		    ]
	    return -1
	}
    }
    # validate new record fields
    db_validatefields $table new

    set q "update $table set \n"
    foreach item [array names new] {
	lappend lr "$item = $new($item)"
	# record old state of items to be changed
	set old($item) $current($item)
    }
    append q [join $lr ",\n"] 
    append q "\n where $identity($table) = $id\n"

    # we write the log record before doing the update because if
    # execsql fails, it will write a stack trace and exit
    # XXX really want to add transaction and do this with no abnormal
    # flow of control
    syslog_log [list [list prog db_update_row] [list table $table] \
	    [list id $id] \
	    [list old [array_to_list old]] \
	    [list new [array_to_list new]] \
	    ]
    # do the update
    # XXX check return!
    execsql $q 

    return 0
}

#
# 
# db_delete_row table id match
#
# deletes a row
#  table specifies which table
#  id    selects a record (this is a value in the $identity(table) column
#  match is an array containing values which have to match the current
#     row
#
#  a transaction is opened, the record is read, if all the match values
#  match their current values, then the row is deleted
#
# if the record doesn't exist, then the procedure returns -3
# if a match failue occurs, the procedure returns -1
# if the delete fails, then the procedure returns -2
# The procedure returns 0 on success
#
proc db_delete_row { table id {a_match xxx}} {
    global identity
    upvar $a_match match
    # the following two statements create an empty array
    # in the case that match was not passed in
    set match(xyzzy) plugh
    unset match(xyzzy)
    if {![db_read_record $table $identity($table) $id current]} {
	syslog_log [list [list prog db_delete_row-missing] \
		[list table $table] [list id $id]]
	return -3
    }
    foreach item [array names match] {
	# XXX bug here, numerics read as .0
	if {[string compare [string tolower $match($item)] \
		[string tolower $current($item)]] != 0} {
	    syslog_log [list [list prog db_delete_row-mismatch] \
		    [list table $table] \
		    [list current [array_to_list current]] \
		    [list match [array_to_list match]] \
		    ]
	    return -1
	}
    }

    set q "delete from $table where $identity($table) = $id"

    # we write the log record before doing the delete because if
    # execsql fails, it will write a stack trace and exit
    # XXX really want to add transaction and do this with no abnormal
    # flow of control
    syslog_log [list [list prog db_delete_row] [list table $table] \
	    [list old [array_to_list current]] \
	    ]
    # do the update
    # XXX check return!
    execsql $q 

    return 0
}

#
# reads a record from the given table, matching on the identity column
#
proc db_read_row {table id ary} {
  upvar $ary a
  global syb identity
  if [info exists a] {unset a}
  case [sybsql $syb "select * from $table where $identity($table) = $id"] {
        {NO_MORE_ROWS} {
	    return 0
	}
        {REG_ROW} {
	    loadresult a
	    return 1
	}
    }
}


#
# map_query - call a procedure with rows matching a query
#
proc db_map_query {query pr} {
    global sybmsg
    set result [execsql $query]
    while {$sybmsg(nextrow) == "REG_ROW"} {
	loadresult temp
	if {$sybmsg(nextrow) != "REG_ROW"} { break }
	$pr temp
    }    
}



#
# unique id system
#

#
# uid_get <times_valid> <expiration>
#
# uid_get will return an id that can be used exactly so many times
# In other words, it will "expire" either when it has been used so
# many times or when it reaches its expiration date
#
proc uid_get {{ times_valid  1} { expiration_date 2147483647} } {
    global syb
    # This service will bypass logging for insert_row
    execsql "insert ntimes values ( 0, $times_valid, $expiration_date )"
    sybsql $syb "select @@identity"
    set id [sybnext $syb]
    return $id
}

#
#
proc uid_valid {id} {
    if {![db_read_record ntimes ntimes_id $id a]} { return 0 }
    set now [currenttime]
    if {([currenttime] - $a(expiration)) > 0} { return 0 }
    incr a(uses)
    if {$a(uses) > $a(maxuses)} { return 0 }
    execsql "update ntimes set uses = $a(uses) where ntimes_id = $id"
    return $a(uses)
}
