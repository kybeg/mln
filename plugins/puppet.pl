
my $PREFIX = "PUPPET: ";
my $PUPPET_VERSION = "0.1";
my $PUPPET_MANIFEST_PATH = "/etc/puppet/manifests/mlnhosts";

sub puppet_version {
    out("$PREFIX Plugin version $PUPPET_VERSION\n");
}

sub puppet_postBuild {
    my $hostname = $_[0];
    verbose("$PREFIX puppet plugin called for $hostname\n");
    if ( getArray("/host/$hostname/puppet")){
	out("$PREFIX plugin enabled for this host\n");
	if ( not stat($PUPPET_MANIFEST_PATH)){
	    out("$PREFIX folder $PUPPET_MANIFEST_PATH missing. Creating...\n");
	    system("mkdir -p $PUPPET_MANIFEST_PATH");	    
	}
	my @confarray = getArray("/host/$hostname/puppet/include");
	my $nodename = getScalar("/host/$hostname/puppet/nodename");
	$nodename = $hostname unless $nodename;
	open(CONFIG,">$PUPPET_MANIFEST_PATH/$PROJECT.$hostname.pp");
	print CONFIG "node '$nodename' {\n";
	foreach my $line (@confarray ){
	    out("$PREFIX adding line: include $line\n");
	    print CONFIG "include $line\n";
	}
	print CONFIG "}\n";
	close(CONFIG);
	if ( stat("/etc/puppet/manifests/sites.pp")){
	    system("touch /etc/puppet/manifests/sites.pp");
	}
	if ( stat("/etc/hydra/manifests/sites.pp") ){
	    system("touch /etc/hydra/manifests/sites.pp");
	}

    }
}

sub puppet_removeHost {
    my $hostname = $_[0];
    my $project = $_[1];
    my $root = $_[2];
    $root = $DATA_ROOT unless $root;

    verbose("$PREFIX puppet plugin called for $hostname\n");
    if ( getArray("/host/$hostname/puppet",$root)){
	out("$PREFIX removing $PUPPET_MANIFEST_PATH/$project.$hostname.pp\n");
	system("rm $PUPPET_MANIFEST_PATH/$project.$hostname.pp");
	out("$PREFIX cleaning certificates\n");
	my $arr = getArray("/host/$hostname/puppet",$root);
	my $nodename;
	foreach my $element ( @arr ){
#	    out("$PREFIX element: $element\n");
	    if ( $element =~ /nodename\s+(.*)$/ ){
		$nodename = $1;
	    }
	}
#	my $nodename = getScalar("/host/$hostname/puppet/nodename",$root);
	$nodename = "$hostname.$PROJECT" unless $nodename;
	out("$PREFIX running puppet cert clean $nodename\n");
	open(CLEAN,"puppet cert clean $nodename |");
	while ( my $line = <CLEAN> ){
	    out("$PREFIX $line");
	}
	close(CLEAN);
    }    
}


1;