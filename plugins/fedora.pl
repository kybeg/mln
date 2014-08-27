# Fedora MLN plugin written by Kyrre Begnum
#

sub fedora_version {
    out("Fedora (users and groups) support plugin for MLN, version 1");
}

sub fedora_configure {
    
    # only continue if fedora
    return unless ( stat("$MOUNTDIR/etc/fedora-release") || stat("$MOUNTDIR/etc/redhat-release"));
    print "Fedora plugin enabled\n";
    
    my $hostname = $_[0];
    my @users = getArray("/host/$hostname/users");
    my %hash = getHash("/host/$hostname/groups");
    my $root = getScalar("/host/$hostname/root_passwd");
    my @commands;
    my @line;
    my $i;
    
    if ( $root ){
	$commands[$i++] = "echo root:$root | chpasswd -e"
    }

    foreach (@users){

	my @line = split /\s+/,$_;
	print "adding user: $line[0]\n";
	my $c = "/usr/sbin/useradd -m -k /etc/skel -p \'$line[1]\' ";
	if ( $line[2] ){
	    $c .= " -d $line[2] ";
	} else {
	    $c .= " -d /home/$line[0] ";
	}
	$c .= " $line[0]";
        $commands[$i++] = $c;
    }
    my $each;
    foreach $each (keys %hash) {
	out("creating group: $each\n");
        $commands[$i++] = "groupadd $each";
	
	my $tm = $hash{$each};
	
	my @users = getArray("/host/$hostname/groups/$each");
	if (@users){
	    out("Adding users to group: \n");
	    my $user;
	    foreach $user ( @users){
#		out("$user ");
		chomp($user);
		$commands[$i++] = "usermod -G $each $user";
	    }
	}
    }
    if ( @commands ){
	# add commands that make the host run the script
	open(ST,">$MOUNTDIR/etc/init.d/startup_MLN_fedora_plugin") or print "error: failed to open start script $!\n";
	print ST "#!/bin/sh\n";
	print ST "logger \"Running MLN fedora plugin startup script once\"\n";
	
	foreach (@commands){
	    print ST $_ . "\n";
	    out("$_\n");
	}
	
	print ST "rm /etc/rc2.d/S20startup_MLN_fedora_plugin\n";
	print ST "rm /etc/init.d/startup_MLN_fedora_plugin\n";
	close(ST);
	system("chmod +x $MOUNTDIR/etc/init.d/startup_MLN_fedora_plugin");
    # add the commands that remove the script
	
	system("ln -s ../init.d/startup_MLN_fedora_plugin $MOUNTDIR/etc/rc2.d/S20startup_MLN_fedora_plugin");
	system("cat $MOUNTDIR/etc/init.d/startup_MLN_fedora_plugin");
    }
}

1;
