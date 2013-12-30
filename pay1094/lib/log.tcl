# Tcl routines for logging from CGI scripts.
#
# Win Treese
# Open Market, Inc.
# treese@OpenMarket.com
#
# Created on Wed Jul 13 11:13:26 EDT 1994 by treese
# Last modified on Wed Jul 13 11:16:30 EDT 1994 by treese

proc run_with_log {script} {
    global argv0 errorInfo
    if [catch {uplevel #0 $script} errors] {
        set now [string trim [ctime [currenttime]]]
	puts stderr "\[$now\] $argv0: $errors"
	set dirs [split $argv0 /]
	set prog [lindex $dirs [expr [llength $dirs] - 1]]
	regsub -all "\n" $errorInfo "\n$prog: " backtrace
	puts stderr "\[$now\] $prog: $backtrace"
    }
}

# enter into the log
proc log {what} {
    global argv0
    set now [string trim [ctime [currenttime]]]
    puts stderr "\[$now\] $argv0: $what"
}


#
# syslog support
#

set syslog_facility local1
set syslog_level info

#
# syslog_init sets up the default string to be entered in syslog
# if pid == "pid" then the process id will be entered also
#
proc syslog_init {name pid} {
  sysloginit $name $pid
}

#
# syslog_log enters the given text in the log using the default
# facility and level
#
proc syslog_log { t } {
  global syslog_facility syslog_level
  syslog $syslog_facility $syslog_level [concat [log_user] $t]
# log " $syslog_facility $syslog_level [concat [log_user] $t]"
}

proc log_user {} {
    global env user
    set uid 0
    set addr 0
    if [info exists env(REMOTE_ADDR)] { set addr $env(REMOTE_ADDR) }
    if [info exists user(principal_id)] { set uid $user(principal_id) }
    return [list [list uid $uid] [list addr $addr]]
}

#
# convert a tcl array (name value pairs) into a tcl list
# with elements being name-value 2 element lists
#
proc array_to_list {a_ary} {
  upvar $a_ary ary
  set res "" 
  if [info exists ary] {
      foreach item [array names ary] {
	  lappend res [list $item $ary($item)]
      }
  }
  return $res
}

#
# translate a list composed of name value pairs back into an array
#
proc list_to_array { l a_ary} {
  upvar $a_ary ary
  foreach item $l {
    set name [lindex $item 0]
    set value [lindex $item 1]
    set ary($name) $value
  }
}

