# Tim Rothenberg

# Gather every IP address on device, add to an object group, and then add permit rule for object group in pre-defined ACL

namespace import ::cisco::eem::*
namespace import ::cisco::lib::*

###########
# Variables
###########
set errorInfo ""
set obj_group_name "local_ips"
#######

# Open CLI connection
if [catch {cli_open} result] {
    error $result $errorInfo
} else {
    array set cli1 $result
}


proc get_intf_ips {
    # Returns list with every local interface IP

    set int_brief [exec "show ip interface brief"]
    return [regexp -all -inline {\d+\.\d+\.\d+\.\d+} $int_brief]

    # RegExp to match IP
    # (?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)
    # Router doesn't allow bad IP to be configured, so not necessary
}

# Create object group local_ip with every IP from array local_ip
foreach ip [get_intf_ips] {
    ios_config "object-group network $obj_group_name" "host $ip"
}

# Find every interface that ACL acl_ext is applied to and store in array acl_int

# Remove ACL acl_ext from every interface in array acl_int

# Create new rule for object group local_ips

# Re-apply ACL acl_ext to every interface in array acl_int