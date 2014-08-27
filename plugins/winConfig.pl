# winConfig plugin, written by Kyrre Begnum and Haarek Haugerud

sub winConfig_version {
    print "winConfig plugin version EXPERIMENTAL\n";
}


sub winConfig_configure {
    $hostname = $_[0];
    my $startupfile = "$MOUNTDIR/Documents\ and\ Settings/All\ Users/Start\ Menu/XPstartup.bat";
    if ( stat("$startupfile")){
	
	print "winConfig has detected the special boot script and is enabled\n";

	if(open(FILE,">$startupfile")){

	    # NET USER $user $pw /ADD
	    my @users = getArray("/host/$hostname/winconfig/users");
	    foreach ( @users ){
		(my $user,my $pass) = split /\s+/,$_;
		print FILE "NET USER $user $pass /ADD\n";
	    }
	    # NET LOCALGROUP Administrators $user /ADD  
	    my %groups = getHash("/host/$hostname/winconfig/groups");
	    foreach my $group ( keys %groups ){
		print "Found group $group\n";
		my @userlist = getArray("/host/$hostname/winconfig/groups/$group");
		foreach (@userlist ){
		    print FILE "NET LOCALGROUP $group $_ /ADD\n";		    
		}
	    }

	    print FILE "REM Selfdestruction:\n\n";
	    print FILE "REM reboots after 5 sec in order to logon with the generated account\n\n";
	    print FILE "shutdown -r -t 15\n\n";
	    print FILE "del \"C:\\Documents and Settings\\All Users\\Start Menu\\XPstartup.bat\"\n  \n";    
	    
	    close(FILE);
	    system("sync");	    
	    system("cat '$startupfile'");
	}
	else{
	    print STDERR "Can't open $startupfile: $!\n";
	}

	sleep 3;
    }
}
  
1;