# Gather every IP address on device, add to an object group, and then add permit rule for object group in pre-defined ACL

namespace import ::cisco::eem::*
namespace import ::cisco::lib::*

###########
# Variables
###########
set errorInfo ""
set obj_group_name "local_ips"
set acl_name "external_acl"
###########

# Open CLI connection
if [catch {cli_open} result] {
    error $result $errorInfo
} else {
    array set cli1 $result
}


proc get_intf_ips {} {
    # Returns list with every local interface IP
    set int_brief [exec "show ip interface brief"]
    return [regexp -all -inline {\d+\.\d+\.\d+\.\d+} $int_brief]
    # RegExp to match IP
    # (?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)
    # Router doesn't allow bad IP to be configured, so not necessary
}

proc get_intf_info {} {
    # Returns list with interfaces and ACLs
    #
    # Intentionally does not match admin down interfaces because
    # the router will not return usable ACL information
    set show_int [exec "show ip interface | include is up,|is down,|Outgoing access]"]
    return [string map {"not set" not_set} $show_int]
}

proc intf_list {} {
    # Returns list with every interface
    return [regexp -all -inline -line {^\S+} [get_intf_info]]
}

proc acl_list {} {
    # Returns list of ACLs (or not_set) on every interface
    set acl_line [regexp -all -inline -line {Outgoing access.*} [get_intf_info]]
    #^Adding extra characters to list, not sure why
    return
}

proc get_acl_ints {} {    
    # Returns list of interface names to switch desired ACL is applied
    set result ""
    set int [intf_list]
    set acl [acl_list]

    # Compare intf_list with acl_list; if lengths don't match, throw error
    if {[llength $int eq llength $acl]} {
        set length [llength $int]
    } else {
        # Throw error and terminate script
    }

    for {set i 0} {i<$length} {incr i} {
        if {[lindex $acl $i] eq $acl_name} {
            lappend $result [lindex $acl $i]
        }
    }
    return $result
}

##########################

# Create object group local_ip with every local interface IP on device
foreach ip [get_intf_ips] {
    ios_config "object-group network $obj_group_name" "host $ip"
}

# Remove ACL acl_ext from every interface to which is is currently applied
foreach int [get_acl_ints] {
    ios_config "interface $int" "no access-group $acl_name out"
}

# Create new rule for object group local_ips
ios_config "ip access-list extended $acl_name" ""

# Re-apply ACL acl_ext to every interface in array acl_int
foreach int [get_acl_ints] {
    ios_config "interface $int" "access-group $acl_name out"
}