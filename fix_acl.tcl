# Gather every IP address on device, add to an object group, and then add permit rule for object group in pre-defined ACL

namespace import ::cisco::eem::*
namespace import ::cisco::lib::*

###########
# Variables
###########
set errorInfo ""
set obj_group_name "local_ips"
set acl_name "external_acl"
set int_br [exec "show ip interface brief"]

##########
#Functions
##########
proc get_intf_names {} {
    # Returns list of every interface on device, regardless \
    # of whether or not it has an IP address assigned.
    return [regexp -all -line -inline {^\S+} $int_br]
}

proc get_intf_ips {} {
    # Returns list with every local interface IP
    # **Will not catch secondary IPs**
    return [regexp -all -inline {\d+\.\d+\.\d+\.\d+} $int_br]
    
    # RegExp to match IP
    # (?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)
    # Router doesn't allow a bad IP to be configured, so an exact match is not necessary
}

proc get_intf_conf {int} {
    # Returns running config for specific interface
    return [exec "show running-config interface $int | include $acl_name in"]
}

proc check_acl {conf} {
    # Checks if $acl_name is applied to interface
    # in the inbound direction
    return [string match "*access-group $acl_name in" $conf]
}

proc acl_ints {int_list} {
    # Creates a list of interfaces if check_acl returns true
    set result ""
    foreach int $int_list {
        if [check_acl [get_intf_conf $int]] {
            lappend $result $int
        }
    }
    return $result
}

##########################

# Open CLI connection
if [catch {cli_open} result] {
    error $result $errorInfo
} else {
    array set cli1 $result
}

# Create object group local_ip with every local interface IP on device
foreach ip [get_intf_ips] {
    ios_config "object-group network $obj_group_name" "host $ip"
}

# Finds all interfaces with $acl_name applied inbound
set active_int [acl_ints [get_intf_names]]

# Remove ACL acl_ext from every interface to which is is currently applied
foreach int $active_int {
    ios_config "interface $int" "no access-group $acl_name in"
}

# Resequence ACL to ensure 
ios_config "ip access-list resequence $acl_name 10 10"

# Create new rule for object group local_ips
# Putting new rule at beginning for now, but it might make more sense at the end \
# in case there are deny entries that need to process first
ios_config "ip access-list extended $acl_name seq 5 permit ip any object-group $obj_group_name"

# Re-apply ACL acl_ext to every interface in array acl_int
foreach int $active_int {
    ios_config "interface $int" "access-group $acl_name in"
}

# Clean-up tasks