# MLN Openstack plugin
# written by Kyrre Begnum


my $OPENSTACK_USER;
my $OPENSTACK_PASSWORD; 
my $OPENSTACK_TENANT; 
my $OPENSTACK_PLUGIN_VERSION = "0.9";
my $OPENSTACK_URL;
my $OS_CREDS;
my $OPENSTACK_MEMBER_ROLE_NAME = "_member_";
my $OS_DEFAULT_CIDR_BASE = "10.0.";
my $OS_EXT_NET = "Hotel";
my $OPENSTACK_MEMBER_ID = "";
my $OPENSTACK_MANAGED_CREDS = "";
my $GATEWAY_ROUTER = "c15b1569-a60a-4a7e-b8f0-83fcd1d69716";
my $OPENSTACK_CREDENTIALS_FILE = "$ENV{'HOME'}/.openstack";
my $PREFIX = "OpenStack: ";
my %OPENSTACK_STORE = ();
my %OPENSTACK_NOVA_QUOTA_LIST = ( "instances" => 1, "ram" => 1,
    "cores" => 1,
    "fixed-ips" => 1,
    "metadata-items" => 1,
    "injected-files" => 1,
    "injected-file-content-bytes" => 1,
    "injected-file-path-bytes" => 1,
    "key-pairs" => 1,
    "security-groups" => 1,
    "security-group-rules" => 1 );

my %OPENSTACK_CINDER_QUOTA_LIST = ( "volumes" => 1, "gigabytes" => 1 );

my %OPENSTACK_NEUTRON_QUOTA_LIST = ( "floatingip" => 1 );

# --dns-nameserver DNS_NAMESERVER
# quantum router-interface-add 310df5c6-4294-4a09-b16c-3a6b2206c4a5




# my $PROJECT = $ARGV[0];
# my $project_user = $ARGV[1];
# my $project_user_passwd = $ARGV[2];
# my $project_user_email = $ARGV[3];

my @DEFAULT_SECURITY_GROUP_RULES = ( " --no-cache secgroup-add-rule default icmp -1 -1 0.0.0.0/0",
" --no-cache secgroup-add-rule default tcp 22 22 0.0.0.0/0"," --no-cache secgroup-add-rule default tcp 80 80 0.0.0.0/0");
 

# my $member_id = openstack_get_role_id("Member");


# my $l3_agent_id = openstack_get_l3_agent_id();


# print "member id: $member_id\n";

# print "l3_agent_id: $l3_agent_id\n";
# create tenant / project
# keystone tenant-create --name project_one
#  152  put_id_of_project_one=f468564e338b4bd292abf9e179192177

# my $project_id = openstack_tenant_create();

# print "project id: $project_id\n";

# my $user_id = openstack_create_user($project_user,$project_user_passwd,$project_id,$project_user_email);

# print "user_id: $user_id\n";

# openstack_user_role_add($user_id,$member_id,$project_id);

# $base_network_name = "$PROJECT" . "_net";

# my $network_id = openstack_create_net($project_id,$base_network_name);

# verbose("network_id: $network_id\n");

# my $vacant_sub = openstack_find_vacant_subnet();

# my $subnet_id = openstack_subnet_create($project_id,$base_network_name,$vacant_sub);

# $router_name = $PROJECT . "_router";
# $router_id = openstack_router_create($project_id,$router_name);

# openstack_l3_router_add($l3_agent_id,$router_name);
# openstack_router_interface_add($GATEWAY_ROUTER,$subnet_id);

# my $ext_net_id = openstack_get_network_id($OS_EXT_NET);

# openstack_router_gateway_set($router_id,$ext_net_id);

# openstack_set_security_rules($project_user,$project_user_passwd,$PROJECT,\@DEFAULT_SECURITY_GROUP_RULES);

# exit 0;

sub openstack_removeHost {
    
    my $hostname = $_[0];
    my $project = $_[1];
    my $root = $_[2];
    $root = $DATA_ROOT unless $root;
    if ( getScalar("/host/$hostname/openstack",$root)){
	openstack_checkCredentials() unless $OPENSTACK_CREDS;
    # check if up

	# terminate the host
	
	if ( not checkIfUp($hostname,$project,$root)){
	    verbose("$PREFIX host is down\n");
#	    out("$PREFIX deleting $hostname.$project\n");
	    if ( $OPENSTACK_STORE{"$hostname.$project"}{'id'} ){


		my @volumes = getArray("/host/$hostname/openstack/volume",$root);
		verbose("$PREFIX removing and deleting non-persistent volumes\n");
		foreach my $vol (@volumes ){
		    verbose("$PREFIX volume line $vol\n");
		    my @vola = split /\s+/,$vol;
		    
		    my $at_id = openstack_get_volume_attachment_id($vola[0],$OPENSTACK_STORE{"$hostname.$project"}{'id'});
		    system("nova $OPENSTACK_CREDS volume-detach $hostname.$project $at_id");
		    if ( not $vola[3] eq "persistent" ){
			system("nova $OPENSTACK_CREDS volume-delete $vola[0]");
		    }
#		    my $volid = openstack_create_volume($vola[0],$vola[1],$vola[3]);
#		    $OPENSTACK_STORE{$hostname}{"volume"}{$vola[0]}{"id"} = $volid;
#		    $OPENSTACK_STORE{$hostname}{"volume"}{$vola[0]}{"dev"} = $vola[3];
		}

		out("$PREFIX removing host $hostname.$project\n");		
		system("nova $OPENSTACK_CREDS delete " . $OPENSTACK_STORE{"$hostname.$project"}{'id'});
		
		if( stat("$PROJECT_PATH/$PROJECT/openstack/$hostname.floating-ip")){
		    system("nova $OPENSTACK_CREDS floating-ip-delete \$(cat $PROJECT_PATH/$PROJECT/openstack/$hostname.floating-ip)");
		}
		
	    }
	} else {
	    verbose("$PREFIX host is up\n");
	    out("$PREFIX host is up, will not delete it\n");
	}
    }
            
}

sub openstack_getStatus {
    openstack_checkCredentials() unless $OPENSTACK_CREDS;
    open(STATUS,"nova $OPENSTACK_CREDS list |");
    while( my $line = <STATUS> ){
# | 9daebac8-53c1-43f1-9e35-1d986a211008 | one.ostest | ACTIVE |                   |
#	print "found line: $line\n";
	if ( $line =~ /\|\s+(\S+)\s+\|\s+(\S+)\s+\|\s+(\S+)\s+\|\s+(.*)\s+\|/ ){
#	    print "found $1\n";
	    $OPENSTACK_STORE{$2}{"status"} = $3;
	    $OPENSTACK_STORE{$2}{"info"} = $4;
	    $OPENSTACK_STORE{$2}{"id"} = $1;
	    
	}
	
    }
    close(STATUS);
}

sub openstack_checkIfUp {
    
    my $hostname = $_[0];
    my $project = $_[1];
    my $root = $_[2];
    $root = $DATA_ROOT unless $root;
    
    if ( getScalar("/host/$hostname/openstack",$root) ){
	
#	print "$PREFIX checking status for $hostname.$project\n";
	openstack_getStatus() unless %OPENSTACK_STORE;
	if (  $OPENSTACK_STORE{"$hostname.$project"}{"status"} eq "ACTIVE" ){
	    return "1 " . $OPENSTACK_STORE{"$hostname.$project"}{"info"};
	} else {
	    return "-1";
	}
    } else {
	return 0;
    }
}

sub openstack_removeProject {
    my $project = $_[0];
    $root = $DATA_ROOT unless $root;
    verbose("$PREFIX removing project $project: $PROJECT_PATH/$project/openstack/managed\n");
    
    if( stat("$PROJECT_PATH/$project/openstack/managed") ){
	openstack_checkCredentials() unless $OPENSTACK_CREDS;
	open(TI,"$PROJECT_PATH/$project/openstack/tenantid");
	my $tenantid = <TI>;
	chomp $tenantid;
	close(TI);

	verbose("$PREFIX starting openstack removal procedure\n");
	
	my @users = getArray("/global/openstack/managed_users",$root);
	foreach my $user (@users){
	verbose("managed user: $user\n");
	    my @uarray = split /\s+/,$user;
	    my $delcom = "keystone $OPENSTACK_CREDS user-delete $uarray[0]";
	    verbose("$PREFIX running $delcom\n");
	    system($delcom);
	    
	}
        openstack_release_floating_ips($tenantid);
	my %router = getHash("/global/openstack/router",$root);
	foreach my $rkey (keys %router){
#	    verbose("$PREFIX deleting router attachments $rkey\n");
#	    system("quantum $OPENSTACK_CREDS router-delete $rkey >/dev/null");	    
	    foreach $anet ( keys %{$router{$rkey}{"attach"}} ){
		out("$PREFIX deleting attatched $rkey port to $anet\n");
#		openstack_router_interface_add($routerID,$OPENSTACK_STORE{"subnets"}{"${anet}_subnet"}{"id"});
		system("neutron $OPENSTACK_CREDS router-interface-delete $rkey ${anet}_subnet");
	    }
	    
	}
	
	
	my %network = getHash("/global/openstack/network",$root);
	foreach my $net (keys %network ){

#	    my $netID = openstack_create_net($tenantID,$net);
	    if ( $network{$net}{"subnet"} ){
		# verbose("$PREFIX creating subnet: $tenantID,$net,$cidr,$name,$network{$net}{'dhcp'},$network{$net}{'nameserver'}\n");
		# my $subnetID = openstack_subnet_create($tenantID,$net,$cidr,$name,$network{$net}{"dhcp"},$network{$net}{"nameserver"});
		verbose("$PREFIX Removing subnet ${net}_subnet\n");
		system("neutron $OPENSTACK_CREDS subnet-delete ${net}_subnet"); 
	    }
	    verbose("$PREFIX Removing net $net\n");
	    # delete network
	    system("neutron $OPENSTACK_CREDS net-delete $net");
	}


	foreach my $rkey (keys %router){
	    verbose("$PREFIX deleting router $rkey\n");
	    system("neutron $OPENSTACK_CREDS router-delete $rkey >/dev/null");	    
	}

	
	
	out("$PREFIX removing tenant $tenantid\n");
	system("keystone $OPENSTACK_CREDS tenant-delete $tenantid");
    }    
}


sub openstack_createFilesystem {
    my $hostname = $_[0];
    my $os = getScalar("/host/$hostname/openstack");
    if  ( $os ){
	out("openstack enabled\n");
	my $use = getScalar("/host/$hostname/openstack/use");
	my $image = getScalar("/host/$hostname/openstack/image");	
	my $quick = getScalar("/host/$hostname/openstack/quickbuild");
	if ( ( $use and $use ne "$hostname") or $quick){
	    out("$PREFIX Quick build, start/stop scripts only\n");	    
	    return 1;
	} elsif ($image ) {
	    verbose("$PERFIX using OpenStack image $image\n");
	    return 1;
	} else {
	    return ;
	}
	
    }
    
}


sub openstack_configureEntireFilesystem {
    my $hostname = $_[0];
    my $os = getScalar("/host/$hostname/openstack");
    if  ( $os ){
	my $use = getScalar("/host/$hostname/openstack/use");
	my $quick = getScalar("/host/$hostname/openstack/quickbuild");
	my $image = getScalar("/host/$hostname/openstack/image");
	if ( ( $use and $use ne "$hostname") or $quick){
	    out("$PREFIX Quick build, start/stop scripts only\n");
	    openstack_createStartStopScripts($hostname);
	    $RESTART_ME{$key} = 1;
	    return 1;
	} elsif ( $image ) {
#	    out("$PREFIX This Vm will use AMI $ami\n");
	    openstack_createStartStopScripts($hostname);
	    $RESTART_ME{$key} = 1;
	    return 1;
	} else {
	    return ;
	}
	
    }
    
}

sub openstack_checkCredentials {
    open(OS,$OPENSTACK_CREDENTIALS_FILE) or warn( "Warning: failed to open $OPENSTACK_CREDENTIALS_FILE: $!\n");
    while ( my $line = <OS> ){
	
	if ( $line =~ /.*OS_TENANT_NAME=(\S+)$/ ){
	    $OPENSTACK_TENANT = $1;
	    chomp $OPENSTACK_TENANT;
	} elsif( $line =~ /.*OS_USERNAME=(\S+)$/ ) {
	    $OPENSTACK_USER = $1;
	    chomp $OPENSTACK_USER;
	} elsif( $line =~ /.*OS_PASSWORD=('.*')$/){
	    $OPENSTACK_PASSWORD = $1;
	    chomp $OPENSTACK_PASSWORD;
	}  elsif( $line =~ /.*OS_AUTH_URL=("|')(\S+)("|')$/){
	    $OPENSTACK_URL = $2;
	    chomp $OPENSTACK_URL;
	}
	
    }
    close(OS);
    
    $OPENSTACK_CREDS = "--os-username $OPENSTACK_USER --os-password $OPENSTACK_PASSWORD --os-tenant-name $OPENSTACK_TENANT --os-auth-url '$OPENSTACK_URL'";
    verbose("OPENSTACK_CREDS: $OPENSTACK_CREDS\n");
}


sub openstack_createProject {    

    if ( stat("$PROJECT_PATH/$PROJECT/openstack") ){
#	verbose("$PREFIX project already created");
    } else {
	verbose("$PREFIX this project will be managed by MLN\n");
	system("mkdir $PROJECT_PATH/$PROJECT/openstack");
	system("touch $PROJECT_PATH/$PROJECT/openstack/managed");
	
	my $tenantID = openstack_tenant_create($PROJECT);
	verbose("$PREFIX tenant ID: $tenantID\n");
	open(TI,">$PROJECT_PATH/$PROJECT/openstack/tenantid") or die("Failed to open: $PROJECT_PATH/$PROJECT/openstack/tenantid $!\n");
	print TI "$tenantID\n";
	close(TI);

	
	
	my $security_rules_set = 0;
	
	my @managed_users = getArray("/global/openstack/managed_users");
	foreach $user (@managed_users){
	    verbose("managed user: $user\n");
	    my @uarray = (); 
	    chomp $user;
	    $user =~ /^(\S+)\s+(.*)\s+(\S+\@\S+)$/;
	    $uarray[0] = $1;
	    $uarray[1] = $2;
	    $uarray[2] = $3;

	    my $userID = openstack_create_user($uarray[0],$uarray[1],$tenantID,$uarray[2]);
	    
	    verbose("$PREFIX user $uarray[0] created with id: $userID\n");
	    ( $OPENSTACK_MEMBER_ID = openstack_get_member_role_id() and verbose("$PREFIX member id: $OPENSTACK_MEMBER_ID\n")) unless $OPENSTACK_MEMBER_ID;
	    
	    openstack_user_role_add($userID,$OPENSTACK_MEMBER_ID,$tenantID);
	    
	    if ( not $OPENSTACK_MANAGED_CREDS ){
		$OPENSTACK_MANAGED_CREDS = "--os-username $uarray[0] --os-password $uarray[1] --os-tenant-name $PROJECT --os-auth-url '$OPENSTACK_URL'";
		verbose("$PREFIX setting managed creds to $OPENSTACK_MANAGED_CREDS\n");
	    }

	    ( openstack_set_security_rules($uarray[0],$uarray[1],$PROJECT,\@DEFAULT_SECURITY_GROUP_RULES) and $security_rules_set = 1 ) unless $security_rules_set;	    	    	    
	}
	my @users = getArray("/global/openstack/users");
	foreach $user (@users){
	    verbose("User: $user\n");
	    my @uarray = (); 
	    chomp $user;

	    my $userID = openstack_get_user_id($user); # get the user id of that user  # openstack_create_user($uarray[0],$uarray[1],$tenantID,$uarray[2]);
	    
	    verbose("$PREFIX user $user has id: $userID\n");
	    ( $OPENSTACK_MEMBER_ID = openstack_get_member_role_id() and verbose("$PREFIX member id: $OPENSTACK_MEMBER_ID\n")) unless $OPENSTACK_MEMBER_ID;
	    
	    openstack_user_role_add($userID,$OPENSTACK_MEMBER_ID,$tenantID);
	    
	}
	
	my %network = getHash("/global/openstack/network");
	foreach my $net (keys %network ){
	    verbose("$PREFIX Creating net $net\n");
	    my $netID = openstack_create_net($tenantID,$net);
	    if ( $network{$net}{"subnet"} ){
		my $cidr =  $network{$net}{"subnet"};
		if ( $network{$net}{"subnet"} eq "auto" ){
		    $cidr = openstack_find_vacant_subnet();
		}
		
		verbose("$PREFIX creating subnet: $tenantID,$net,$cidr,$network{$net}{'dhcp'},$network{$net}{'nameserver'}\n");
		my $subnetID = openstack_subnet_create($tenantID,$net,$cidr,"${net}_subnet",$network{$net}{"dhcp"},$network{$net}{"nameserver"});
		$OPENSTACK_STORE{"subnets"}{"${net}_subnet"}{"id"} = $subnetID;
	    }
	}
	my %router = getHash("/global/openstack/router");
	foreach my $rkey (keys %router){
	    out("$PREFIX Building router $rkey\n");
	    my $routerID = openstack_router_create($tenantID,$rkey);
	    
	    if ( $router{$rkey}{"gateway"}){
		out("$PREFIX setting $rkey gateway to $router{$rkey}{'gateway'}\n");
		my $netID = openstack_get_network_id($router{$rkey}{"gateway"});
		openstack_router_gateway_set($routerID,$netID);
	    }
	    
	    foreach $anet ( keys %{$router{$rkey}{"attach"}} ){
		out("$PREFIX attatching $rkey to $anet\n");
		openstack_router_interface_add($routerID,$OPENSTACK_STORE{"subnets"}{"${anet}_subnet"}{"id"});
		
	    }
	    
	}
	
	my %quotas = getHash("/global/openstack/quota");
	my $nova_quota_list = "";
	my $cinder_quota_list = "";
	my $neutron_quota_list = "";
	foreach my $qkey (keys %quotas ){
	    if ( $OPENSTACK_NOVA_QUOTA_LIST{$qkey} ){
		verbose("$PREFIX setting $qkey quota to $quotas{$qkey}\n");
		$nova_quota_list .= " --$qkey $quotas{$qkey} ";
	    } elsif ( $OPENSTACK_CINDER_QUOTA_LIST{$qkey} ){
		verbose("$PREFIX setting $qkey quota to $quotas{$qkey}\n");
		$cinder_quota_list .= " --$qkey $quotas{$qkey} ";	       
	    } elsif ( $OPENSTACK_NEUTRON_QUOTA_LIST{$qkey} ){
		verbose("$PREFIX setting $qkey quota to $quotas{$qkey}\n");
		$neutron_quota_list .= " --$qkey $quotas{$qkey} ";	       
	    }
	}
	if ( $nova_quota_list ){
	    my $qcom = "nova $OPENSTACK_CREDS quota-update $nova_quota_list $tenantID";
	    verbose("$PREFIX running $qcom\n");
	    system($qcom);   
	}
	if ( $nova_quota_list ){
	    my $qcom = "cinder $OPENSTACK_CREDS quota-update $cinder_quota_list $tenantID";
	    verbose("$PREFIX running $qcom\n");
	    system($qcom);   
	}
	if ( $neutron_quota_list ){
	    my $qcom = "neutron $OPENSTACK_CREDS quota-update $neutron_quota_list --tenant-id $tenantID";
	    verbose("$PREFIX running $qcom\n");
	    system($qcom);   
	}
	
    }
    return "";
}

sub openstack_getFlavorID {
    my $flavor = $_[0];
#    verbose("Looking for flavor $flavor\n");
    if (    $OPENSTACK_STORE{"flavor.$flavor.id"} ){
	return $OPENSTACK_STORE{"flavor.$flavor.id"}
    }
#    verbose("Searching the nova image list\n");
    open(NOVA,"nova $OPENSTACK_CREDS flavor-list |");
    while( my $line = <NOVA> ){
# | 1  |  m1.tiny  |    512    |  
#	verbose("Line: $line");
	if ( $line =~ /\|\s+(\S+)\s+\|\s+$flavor\s+/ ){
	    verbose("returning flavor id for $flavor  $1\n");
	    $OPENSTACK_STORE{"flavor.$flavor.id"} = $1;
	    return $1;
	}
    }
    close(NOVA);    
}

sub openstack_getImageID {
    my $image = $_[0];
    if (    $OPENSTACK_STORE{"image.$image.id"} ){
	return $OPENSTACK_STORE{"image.$image.id"}
    }
    verbose("$PREFIX looking for image $image\n");
    open(NOVA,"openstack $OPENSTACK_CREDS image list |");
    while( my $line = <NOVA> ){
# | 1  |  m1.tiny  |    512    |  
# | e9005003-1282-4944-adf3-a081b1d43f9a | Ubuntu       | ACTIVE |
	if ( $line =~ /\|\s+(\S+)\s+\|\s+$image\s+/ ){
	    verbose("returning image id for $image  $1\n");
	    $OPENSTACK_STORE{"image.$image.id"} = $1;
	    return $1;
	}
    }
    close(NOVA);    
}

sub openstack_createStartStopScripts {
    my $hostname = $_[0];
    my $os = getScalar("/host/$hostname/openstack");
    openstack_checkCredentials($hostname);
    if  ( $os ){
	out("Creating start/stop scripts for $hostname on OpenStack\n");
	my $flavor = getScalar("/host/$hostname/openstack/flavor");
	my $image = getScalar("/host/$hostname/openstack/image");
	
	# is this a MLN managed project?
	my $managed = getScalar("/global/openstack/managed");
	if (  $managed ){
	# yes
	    openstack_createProject();
	    #   Is the project created?
	#   create project
	#  
	#   store in $PROJECT/openstack
	} 
	
	system("mkdir $PROJECT_PATH/$PROJECT/openstack") unless stat("$PROJECT_PATH/$PROJECT/openstack");
	# get the flavor ID
	
	my @volumes = getArray("/host/$hostname/openstack/volume");
	verbose("$PREFIX checking for volumes\n");
	foreach my $vol (@volumes ){
	    verbose("$PREFIX volume line $vol\n");
	    my @vola = split /\s+/,$vol;
	    my $volid = openstack_create_volume($vola[0],$vola[1],$vola[3]);
	    $OPENSTACK_STORE{$hostname}{"volume"}{$vola[0]}{"id"} = $volid;
	    $OPENSTACK_STORE{$hostname}{"volume"}{$vola[0]}{"dev"} = $vola[3];
	}
	
	my $flavorID = openstack_getFlavorID($flavor);
	out("$PREFIX got flavor ID $flavorID\n");
	
	# get the image ID

	my $imageID = openstack_getImageID($image);
	out("$PREFIX got image ID $imageID\n");

	my $bo = getScalar("/host/$hostname/boot_order");
	$bo = 99 unless $bo;
	
	my $comcreds = $OPENSTACK_CREDS;
	$comcreds = $OPENSTACK_MANAGED_CREDS if $OPENSTACK_MANAGED_CREDS;
	
	open(START,">$PROJECT_PATH/$PROJECT/start_${bo}_$hostname.sh") or warn "$PREFIX Warning, failed to open $PROJECT_PATH/$PROJECT/start_${bo}_$hostname.sh $!\n" ;
	print START "#!/bin/bash\n";
	
	print START "result=\$( nova $comcreds show $hostname.$PROJECT 2>/dev/null )\n";
	print START "active=\$( echo \$result | grep ACTIVE )\n";
	print START "build=\$( echo \$result | grep BUILD )\n";
	print START "shutoff=\$( echo \$result | grep SHUTOFF )\n";
	print START "if [ -n \"\$active\" ]; then \n";
	print START "echo \"Instance $hostname.$PROJECT is already running\"\n";
	print START "exit 1\n";
	print START "elif [ -n \"\$shutoff\" ]; then \n";
	print START "echo Starting $hostname.$PROJECT\n";
	$startcomm = "nova $comcreds start $hostname.$PROJECT >/dev/null\n";	
	print START $startcomm;
	print START "elif [ -n \"\$build\" ]; then \n";
	print START "echo Instance $hostname.$PROJECT is still building\n";
	print START "else\n";
	
		# --nic <net-id=net-uuid,v4-fixed-ip=ip-addr,port-id=port-uuid>
	
	my %networks = getHash("/host/$hostname/network");
	my $nic;
	my $floating_ip;
	foreach my $net (keys %networks ){

	    my $switch = $networks{$net}{"switch"};
	    $switch = $networks{$net}{"net"};
	    verbose("$PREFIX connecting $net to '$switch'\n");
	    my $netuuid = openstack_get_network_id($switch);
	    $nic .= "--nic net-id=$netuuid ";
	    if ( $networks{$net}{"floating-ip"} ){
		$OPENSTACK_STORE{$host}{$floating_ip} = $networks{$net}{"floating-ip"};
	    }
	}
	my $keyname = getScalar("/host/$hostname/openstack/keypair");
	$keyname = "--key-name $keyname" if $keyname;
	
	
	my @user_data = getArray("/host/$hostname/openstack/user_data");
	my $userd;
	# if ( @user_data ){
	    
	open(USERD,">$PROJECT_PATH/$PROJECT/openstack/$hostname.user-data") or warn("failed to open user data file: $!\n");
	print USERD "#!/bin/bash\n";
	foreach my $line (@user_data){
	    verbose("$PREFIX adding user_data: $line\n");
	    print USERD $line . "\n";
	}
	close(USERD);
	$userd = " --user-data $PROJECT_PATH/$PROJECT/openstack/$hostname.user-data ";
	# }
	my $startcomm = "nova $comcreds boot $hostname.$PROJECT $nic --image $imageID $keyname $userd --flavor $flavorID\n";
	print START $startcomm;
	my $volcom = "";
	foreach my $vol (@volumes ){
	    my @vola = split /\s+/,$vol;
#	    print START "sleep 1\n";

#	    print START "\n";
	    $volcom .= " nova $comcreds volume-attach $hostname.$PROJECT $OPENSTACK_STORE{$hostname}{'volume'}{$vola[0]}{'id'} $vola[2] &&";

	}
	if ( $volcom ){
	    $volcom =~ s/&&$//;
	
	    print START "while ! ( $volcom ); do sleep 3; done &\n";
	    
	}
	# = getScalar("/host/$hostname/network/
#	if ( $
	if ( $OPENSTACK_STORE{$host}{$floating_ip} =~ /auto\s+(\S+)/ ){
	    print START "nova $comcreds floating-ip-create $1 | grep -v Instance | cut -f2 -d ' ' | grep -v + >$PROJECT_PATH/$PROJECT/openstack/$hostname.floating-ip\n";
	    print START "sleep 3\n";
	    print START "while ! nova $comcreds add-floating-ip $hostname.$PROJECT \$(cat $PROJECT_PATH/$PROJECT/openstack/$hostname.floating-ip); do sleep 3; done &\n";
	} elsif ( $OPENSTACK_STORE{$host}{$floating_ip} =~ /(\S+\.\S+\.\S+\.\S+)/ ){
	    print START "sleep 3\n";
	    print START "while ! nova $comcreds add-floating-ip $hostname.$PROJECT $1; do sleep 3; done &\n";
	}
	print START "fi\n";  
	
	close(START);
	system("chmod +x $PROJECT_PATH/$PROJECT/start_${bo}_$hostname.sh");
	
	open(STOP,">$PROJECT_PATH/$PROJECT/stop_${bo}_$hostname.sh") or warn "$PREFIX Warning, failed to open $PROJECT_PATH/$PROJECT/stop_${bo}_$hostname.sh $!\n" ;
	print STOP "#!/bin/bash\n";
	my $stopcomm = "nova $comcreds stop $hostname.$PROJECT\n";	

	print STOP "echo Stopping $hostname.$PROJECT\n";
	print STOP $stopcomm;
	close(STOP);
	system("chmod +x $PROJECT_PATH/$PROJECT/stop_${bo}_$hostname.sh");
# nova boot $hostname --image f4addd24-4e8a-46bb-b15d-fae2591f1a35 --flavor 2 --key-name mykey
	
	# --meta description='Small test image' --meta creator=joecool
	
	# --user-data mydata.file
	
	# --security-groups
	

    }
}


sub openstack_version {
    out("OpenStack plugin version $OPENSTACK_PLUGIN_VERSION\n");
}

sub openstack_set_security_rules {
    
    my $user = $_[0];
    my $password = $_[1];
    my $tenant = $_[2];
    my $r = $_[3]; 
    my @rules = @{$r};

    
    my $creds = "--os-username $user --os-password $password --os-tenant-name $tenant --os-auth-url '$OPENSTACK_URL'";
    system("nova $creds secgroup-create $PROJECT '$PROJECT alternate rules (do not use)' >/dev/null");

    foreach my $rule ( @rules ){
	$rule = "nova $creds " . $rule;
	verbose("Adding rule: $rule\n");
	system("$rule");
    }
    system("nova $creds secgroup-delete $PROJECT");    
}

# Assign role
#  157  keystone user-role-add --tenant-id $put_id_of_project_one  --user-id $put_id_of_user_one --role-id $put_id_of_member_role

#  159  quantum subnet-create --tenant-id $put_id_of_project_one net_proj_one 50.50.1.0/24
#  166  put_subnet_id_here=96f98d20-97c9-4c17-9e39-0a1d2d75c3db

#  164  

# attatch router to network

# 167  quantum router-interface-add $put_router_proj_one_id_here $put_subnet_id_here

# really?
#  168  cd /etc/init.d/; for i in $( ls quantum-* ); do sudo service $i restart; done
#  169  keystone tenant-list

# external network: not mandatory
#  170  put_id_of_admin_tenant=232c5fc9a1e540bf964f34cffbac8e9e
#  171  quantum net-create --tenant-id $put_id_of_admin_tenant ext_net --router:external=True
#  172  quantum subnet-create --tenant-id $put_id_of_admin_tenant --allocation-pool start=128.39.73.216,end=128.39.73.220 --gateway 128.39.73.1 ext_net 128.39.73.0/24 --enable_dhcp=False
#  174  

# need to get $put_id_of_ext_net_here using quantum net-list
#  176  

# Use glance to upload images but as the appropriate user
#  179  glance image-create --name Ubuntu_12.04 --is-public true --container-format bare --disk-format qcow2 < /etc/init.d/precise-server-cloudimg-amd64-disk1.img 

# put_id_of_ext_net_here=0572c8d2-368f-439f-b4a8-fcb476115c1f

sub openstack_router_gateway_set {
    my $router_id = $_[0];
    my $ext_id = $_[1];
    system("neutron $OPENSTACK_CREDS router-gateway-set $router_id $ext_id");
}
# 


sub openstack_get_network_id {
    my $network = $_[0];
    
    open(QUANTUM,"openstack $OPENSTACK_CREDS network list |");
    while( my $line = <QUANTUM> ){
#	verbose("$PREFIX checking $line");
	if ( $line =~ /\|\s+(\S+)\s+\|\s+$network\s+/ ){
	    verbose("returning network id for $network $1\n");
	    return $1;
	}
    }
    close(QUANTUM);
}

sub openstack_get_subnet_id {
    my $network = $_[0];
    open(QUANTUM,"neutron $OPENSTACK_CREDS net-list |");
    while( my $line = <QUANTUM> ){
	if ( $line =~ /\|\s+(\S+)\s+\|\s+$network\s+/ ){
	    verbose("returning network id for $network $1\n");
	    return $1;
	}
    }
    close(QUANTUM);
}


sub openstack_get_member_role_id {
    verbose("$PREFIX Running keystone $OS_CREDS role-list\n");
    open(KS,"keystone $OPENSTACK_CREDS role-list |");
    while ( my $line = <KS> ){
#	print "line: $line";
	verbose("Line: $line");
	if ( $line =~ /\|\s+(\S+)\s+\|\s+$OPENSTACK_MEMBER_ROLE_NAME\s+/){ # wrong ...
	    verbose("returning $1\n");
	    return $1;
	}
    }
}

sub verbose {
	print "VERBOSE: " . $_[0] if $VERBOSE;
}

sub openstack_release_floating_ips {
    my $tenantID = $_[0];
    open(QUANTUM,"neutron $OPENSTACK_CREDS floatingip-list -f csv |") or die("Failed: $!");
    while( my $line = <QUANTUM> ){
	# | 26309af3-7045-42bd-b8cf-602b528a761f | L3 agent           | osgrizzly | :-)   | True           |
	if ( $line =~ /^"([^"]+)"/ and not $line =~ /^"id"/ ){
#	    verbose("investigating floating IP $1 for tenant: $tenantID\n");
	    my $fip = $1;
	    open(SHOW,"neutron $OPENSTACK_CREDS floatingip-show $fip |");
	    while ( my $nl = <SHOW> ){
#		verbose("checking: $nl");
		if ( $nl =~ /tenant_id\s+\|\s+$tenantID\s+/ ){
		    verbose("Found IP beloning to tenant, deleting\n");
		    system("neutron $OPENSTACK_CREDS floatingip-delete $fip");
		}
	    }
	}
    }
    
    
}


sub openstack_get_l3_agent_id {
	open(QUANTUM,"neutron $OPENSTACK_CREDS agent-list |") or die("Failed: $!");
	while( my $line = <QUANTUM> ){
		# | 26309af3-7045-42bd-b8cf-602b528a761f | L3 agent           | osgrizzly | :-)   | True           |
		if ( $line =~ /\|\s+(\S+)\s+.*L3 agent/ ){
			verbose("returning $1\n");
			return $1;
		}
	}
}

sub openstack_tenant_create {
    my $tenant = $_[0];
    my $description = getScalar("/global/openstack/description");
    $description = "--description $description" if $description;
	open(KS,"keystone $OPENSTACK_CREDS tenant-create --name $tenant $description |") or die("failed: $!\n");	
	while ( my $line = <KS> ){
		if ( $line =~ /id\s+\|\s+(\S+)\s+/){
			verbose("returning $1\n");
			return $1;
		}
	}
}





sub openstack_create_user {
	my $username = $_[0];
	my $password = $_[1];
	my $project_id = $_[2];
	my $email = $_[3];
	
	$email = "--email=$email" if $email;
	open(KS,"keystone $OPENSTACK_CREDS user-create --name=$username --pass=$password --tenant-id $project_id $email |");
	while ( my $line = <KS> ){
		if ( $line =~ /\sid\s+\|\s+(\S+)\s+/){
			verbose("returning $1\n");
			return $1;
		}
	}
}
# create user ( if user does not exist )
#  153  keystone user-create --name=kyrre --pass=vlabpass --tenant-id $put_id_of_project_one --email=kyrre.begnum@hioa.no
#  154  put_id_of_user_one=275901c6c77a4ca089693d86f3071bac

# my $member_id = openstack_get_role_id("Member");

# foreach: what roles do we assign the user?
# get appropriate ID
#  155  keystone role-list
#  156  put_id_of_member_role=cb459f24e2ae4c449542bd5f03ddfbdf

sub openstack_user_role_add {
    my $user_id = $_[0];
    my $member_id = $_[1];
    my $project_id = $_[2];
    verbose("keystone $OPENSTACK_CREDS user-role-add --tenant-id $project_id  --user-id $user_id --role-id $member_id\n");
    system("keystone $OPENSTACK_CREDS user-role-add --tenant-id $project_id  --user-id $user_id --role-id $member_id");
}


# Create the base network for the project
#  158  quantum net-create --tenant-id $put_id_of_project_one net_proj_one


sub openstack_create_net {
	my $project_id = $_[0];
	my $network_name = $_[1];
	open(QUANTUM,"neutron $OPENSTACK_CREDS net-create --tenant-id $project_id $network_name |") or die("Failed: $!\n");
	while( my $line = <QUANTUM> ){
		if ( $line =~ /\sid\s+\|\s+(\S+)\s+/){
			verbose("returning $1\n");
			return $1;
		}	
	}
	
}

sub openstack_find_vacant_subnet {
    
    my %subnets;
    open(QUANTUM,"neutron $OPENSTACK_CREDS subnet-list |");
    while ( my $line = <QUANTUM> ){
	# | 96f98d20-97c9-4c17-9e39-0a1d2d75c3db |             |
	if ( $line =~ /\|\s+\S+\s+\|.*\|\s+(\S+)\s+\| \{/){
#	    verbose("found subnet '$1'\n");
	    $subnets{"$1"} = 1;
	    
	}
    }
    
    for( $i = 0; $i < 256; $i++ ){
	my $sub = $OS_DEFAULT_CIDR_BASE . $i . ".0/24";
	if( not $subnets{$sub} ){
	    verbose("Found vacant subnet at '$sub'\n");
	    return $sub;
	}
    }
    
}


sub openstack_subnet_create {
    my $project_id = $_[0];
    my $network_name = $_[1];
    my $subnet_cidr = $_[2];
    my $name = $_[3];
    my $dns = $_[5];
    my $dhcp = "--enable_dhcp=True";
    $dhcp = "--enable_dhcp=False" if not $_[4];
    $name = "--name $name" if $name;
    $dns = "--dns-nameserver $dns" if $dns;
    verbose("$PREFIX neutron $OPENSTACK_CREDS subnet-create $name $dns $dhcp --tenant-id $project_id $network_name $subnet_cidr\n");
    open(QUANTUM,"neutron $OPENSTACK_CREDS subnet-create $name $dns $dhcp --tenant-id $project_id $network_name $subnet_cidr |") or die("Failed: $!\n");
    while( my $line = <QUANTUM> ){
	if ( $line =~ /\sid\s+\|\s+(\S+)\s+/){
	    verbose("returning subnet id:  $1\n");
	    return $1;
	}	
    }	
}

#  160  quantum router-create --tenant-id $put_id_of_project_one router_proj_one
#  165  put_router_proj_one_id_here=70b68719-8665-4da5-9756-5ea132ba6d44


sub openstack_router_create {
	my $project_id = $_[0];
	my $router_name = $_[1];
	open(QUANTUM,"neutron $OPENSTACK_CREDS router-create --tenant-id $project_id $router_name |") or die("Failed: $!\n");
	while( my $line = <QUANTUM> ){
		if ( $line =~ /\sid\s+\|\s+(\S+)\s+/){
			verbose("returning router id:  $1\n");
			return $1;
		}	
	}	
	close(QUANTUM);
}


# get the l3 agent
#  161  quantum agent-list
#  162  l3_agent_ID router_proj_one=26309af3-7045-42bd-b8cf-602b528a761f
#   163  l3_agent_ID=26309af3-7045-42bd-b8cf-602b528a761f


sub openstack_l3_router_add {
	my $l3_agent_id = $_[0];
	my $router_name = $_[1];
#	quantum l3-agent-router-add $l3_agent_ID router_proj_one
	open(QUANTUM,"neutron $OPENSTACK_CREDS l3-agent-router-add $l3_agent_id $router_name |") or die("Failed: $!\n");
	while ( my $line = <QUANTUM> ){
		print "$line";
	}
	close(QUANTUM);
}

sub openstack_router_interface_add {
	my $router_id = $_[0];
	my $subnet_id = $_[1];
	open(QUANTUM,"neutron $OPENSTACK_CREDS router-interface-add $router_id $subnet_id |") or die("Failed: $!\n");
	while( my $line = <QUANTUM> ){
		print "$line";
	}	
}

sub openstack_create_volume {
    my $name = $_[0];
    my $size = $_[1];
    my $persistent = $_[2];
    if ( $persistent ){
	open(SHOW,"nova $OPENSTACK_CREDS volume-show $name |") or die("Failed: $!\n");
	while ( $line = <SHOW> ){
	    if ( $line =~ /\sid\s+\|\s+(\S+)\s+/){
		verbose("returning persistent volume id: $1\n");
		return $1;
	    }
	}
	close(SHOW);
    }
    $persistent = "--display-description=Persisitent" if $persistent;
    open(NOVA,"openstack $OPENSTACK_CREDS volume create $persistent --size $size $name |") or die("Failed: $!\n");
    while( my $line = <NOVA> ){
	if ( $line =~ /\sid\s+\|\s+(\S+)\s+/){
	    verbose("returning volume id:  $1\n");
	    return $1;
	}	
    }	
    close(NOVA);

}

sub openstack_get_user_id {
    my $user = $_[0];
    open(USER,"keystone $OPENSTACK_CREDS user-list |") or die("Failed: $!\n");
    while ( my $line = <USER> ){
	if ( $line =~ /\s(\S+)\s+\|\s+$user\s+/){
	    verbose("returning user id:  $1\n");
	    return $1;
	}	
	
    }
    close(USER);
}

sub openstack_get_volume_attachment_id {
    my $name = $_[0];
    my $instance = $_[1];
    
    open(SHOW,"nova $OPENSTACK_CREDS volume-show $name |") or die("Failed: $!\n");
    while ( $line = <SHOW> ){
	if ( $line =~ /\sattachments\s+/){
	    verbose("$PREFIX found attatchment line for volume $name\n");
	    my @at = split /volume_id/, $line;
	    foreach my $a (@at){
		verbose("$PREFIX looking at attachment: $a\n");
		if ( $a =~ /server_id': u'$instance', u'id': u'(\S+)', / ){ 
		    verbose("$PREFIX returning attachment id $1\n");
		    return $1;
		}
	    }
	}
    }
    close(SHOW);
}
 

;
