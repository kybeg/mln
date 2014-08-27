# AutoEnum
# An MLN plugin to automatically create a specified number
# of identical hosts, eliminating the need to otherwise enumerate 
# those hosts in a project file.
#
# Author: Matt Disney < matthew.disney at iu dot hio dot no >
#
# Q: What's the appropriate way to deal with failure?
# Q: How to autoaddress with more than one interface?
# Q: Should we require in MLN's host/network block
#    only the network and subnet, and then figure out
#    the rest from there? 
# Q: Should we allow more than one autoenum block? If so,
#    how should that be organized?
# Q: How can we more dynamically support networking. The
#    current solution for auto-addressing seems limited.
# ADD: hostprefix, autouser

my $ae_version = 0.5;

my $ae_DEBUG = 0;

sub autoenum_version {
	print ("autoenum version $ae_version\n");
}

sub autoenum_postParse {
    
    my $hostname = $_[0];
    my @autoenum_lines = getArray("/global/autoenum");
    if ( @autoenum_lines ){
	print "autoenum plugin is enabled";
	
	
	if ( @autoenum_lines ){
	    out("autoenum is enabled on this superclass:\n");
	    my $line;
	    foreach $line (@autoenum_lines){
		print("$line\n");
	    }   
	}
	
	my @ae_servicehosts = getArray("/global/autoenum/service_hosts");
	if ( @ae_servicehosts ) {
	    print "Service hosts: @ae_servicehosts\n";
	}
	
	if ( my $ae_sclass = getScalar("/global/autoenum/superclass") ) {
	    
	    if ( my $numhosts = getScalar("/global/autoenum/numhosts") ) {
		
		my $ae_net = getScalar("/global/autoenum/net");
		$ae_DEBUG && print("network is $ae_net\n");
		
		my $hostprefix = "node";
		if ( $hostprefix = getScalar("/global/autoenum/hostprefix") ) {
		    
		}
		
		for ( my $i = 1 ; $i <= $numhosts ; $i++ )
		{
		    while (length($i)<length($numhosts)) {$i="0$i";}
		    $ae_DEBUG && print ("Looping through node creation\n");
		    setScalar("/host/$hostprefix$i/superclass","$ae_sclass");
		    
		    if (@ae_servicehosts > 0) {
			$ae_DEBUG && print("Now in the ae_servicehosts block...\n");
			
			# Take the last element in @ae_servicehosts, and 
			# split it on whitespace. 
			my @svrline = split (/\ /, $ae_servicehosts[0]);
			$ae_DEBUG && print("svrline-0: $svrline[0]\n");
			$ae_DEBUG && print("svrline-1: $svrline[1]\n");
			
			if ($svrline[1] =~ /^all$/) 
			{
			    $ae_DEBUG && print("all\n");
			    setScalar("/host/$hostprefix$i/service_host", $svrline[0]);
			}
			
			# If there is only one thing in the line, then we aren't
			# doing weighted distribution
			elsif (@svrline == 1 || $svrline[1] == 1)
			{
			    $ae_DEBUG && print("only one argument\n");
			    setScalar("/host/$hostprefix$i/service_host", $svrline[0]);      
			    shift(@ae_servicehosts);
			    $ae_DEBUG && print("ae_servicehosts-0: $ae_servicehosts[0]\n");
			    $ae_DEBUG && print("ae_servicehosts: @ae_servicehosts\n");
			}
			
			else
			{
			    $ae_DEBUG && print("more than one argument\n");
			    setScalar("/host/$hostprefix$i/service_host", $svrline[0]);      
			    
			    if ($svrline[1] == 1)
			    {
				shift(@ae_servicehosts);
			    }
			    else
			    {
				$counter = $svrline[1] - 1;
				shift(@ae_servicehosts);
				unshift(@ae_servicehosts,"$svrline[0] $counter");
				$ae_DEBUG && print("ae_servicehosts-0: $ae_servicehosts[0]\n");
				$ae_DEBUG && print("ae_servicehosts: @ae_servicehosts\n");
				
			    }
			}
		    }
#		    my $address = 
		    if ( getScalar("/global/autoenum/address") eq "auto") {
			$ae_DEBUG && print ("Auto-assigning network addresses\n");
# 	     my @ae_int = getArray("/superclass/$ae_sclass/network");
# 	     $ae_DEBUG && print ("Using interface $ae_int[0]\n");
			my @net_string = split ( /\./ , $ae_net );
			my $addresses_begin = getScalar("/global/autoenum/addresses_begin");
			$net_string[3] += $i + $addresses_begin - 1;
			setScalar("/host/$hostprefix$i/network/eth0/address","$net_string[0].$net_string[1].$net_string[2].$net_string[3]");
		    }
			
		    
		    
		    
		    if ( my $passhash = getScalar("/global/autoenum/autouser") ) {
			my @userarray = getArray("/host/$hostprefix$i/users");
			push(@userarray,"$hostprefix$i $passhash");
			setArray("/host/$hostprefix$i/users",\@userarray);
		    }
		    
		}

	    }
	}
    } else {
	for ( my $i = 0; $i <= 5 ; $i++){
	    my @autoenum_lines = getArray("/global/autoenum$i");
	    
	    
	    if ( @autoenum_lines ){
		print("autoenum$i is enabled on this superclass:\n");
		my $line;
		foreach $line (@autoenum_lines){
		    print("$line\n");
		}   
	    } else {
		next;
	    } 
	    
	    my @ae_servicehosts = getArray("/global/autoenum$i/service_hosts");
	    if ( @ae_servicehosts ) {
		print "Service hosts: @ae_servicehosts\n";
	    }
	    
	    if ( my $ae_sclass = getScalar("/global/autoenum$i/superclass") ) {
		
		if ( my $numhosts = getScalar("/global/autoenum$i/numhosts") ) {
		    
		    my $ae_net = getScalar("/global/autoenum$i/net");
		    $ae_DEBUG && print("network is $ae_net\n");
		    
		    my $hostprefix = "node";
		    if ( $hostprefix = getScalar("/global/autoenum$i/hostprefix") ) {
			
		    }
		    
		    for ( my $i = 1 ; $i <= $numhosts ; $i++ )
		    {
			$ae_DEBUG && print ("Looping through node creation\n");
			setScalar("/host/$hostprefix$i/superclass","$ae_sclass");
			
			if (@ae_servicehosts > 0) {
			    $ae_DEBUG && print("Now in the ae_servicehosts block...\n");
			    
			    # Take the last element in @ae_servicehosts, and 
			    # split it on whitespace. 
			    my @svrline = split (/\ /, $ae_servicehosts[0]);
			    $ae_DEBUG && print("svrline-0: $svrline[0]\n");
			    $ae_DEBUG && print("svrline-1: $svrline[1]\n");
			    
			    if ($svrline[1] =~ /^all$/) 
			    {
				$ae_DEBUG && print("all\n");
				setScalar("/host/$hostprefix$i/service_host", $svrline[0]);
			    }
			    
			    # If there is only one thing in the line, then we aren't
			    # doing weighted distribution
			    elsif (@svrline == 1 || $svrline[1] == 1)
			    {
				$ae_DEBUG && print("only one argument\n");
				setScalar("/host/$hostprefix$i/service_host", $svrline[0]);      
				shift(@ae_servicehosts);
				$ae_DEBUG && print("ae_servicehosts-0: $ae_servicehosts[0]\n");
				$ae_DEBUG && print("ae_servicehosts: @ae_servicehosts\n");
			    }
			    
			    else
			    {
				$ae_DEBUG && print("more than one argument\n");
				setScalar("/host/$hostprefix$i/service_host", $svrline[0]);      
				
				if ($svrline[1] == 1)
				{
				    shift(@ae_servicehosts);
				}
				else
				{
				    $counter = $svrline[1] - 1;
				    shift(@ae_servicehosts);
				    unshift(@ae_servicehosts,"$svrline[0] $counter");
				    $ae_DEBUG && print("ae_servicehosts-0: $ae_servicehosts[0]\n");
				    $ae_DEBUG && print("ae_servicehosts: @ae_servicehosts\n");
				    
				}
			    }
			}
			
			if ( getScalar("/global/autoenum$i/address") eq "auto") {
			    $ae_DEBUG && print ("Auto-assigning network addresses\n");
# 	     my @ae_int = getArray("/superclass/$ae_sclass/network");
# 	     $ae_DEBUG && print ("Using interface $ae_int[0]\n");
			    my @net_string = split ( /\./ , $ae_net );
			    my $addresses_begin = getScalar("/global/autoenum$i/addresses_begin");
			    $net_string[3] += $i + $addresses_begin - 1;
			    setScalar("/host/$hostprefix$i/network/eth0/address","$net_string[0].$net_string[1].$net_string[2].$net_string[3]");
			}
			
			
			if ( my $passhash = getScalar("/global/autoenum$i/autouser") ) {
			    my @userarray = getArray("/host/$hostprefix$i/users");
			    push(@userarray,"$hostprefix$i $passhash");
			    setArray("/host/$hostprefix$i/users",\@userarray);
			}
			
		    }
		    
		}	
		
	    }
	}
	
	
    }
}
    

1;
    