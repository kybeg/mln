# hostsFile plugin for MLN written by Kyrre Begnum
#
# This plugin attempts to create a better /etc/hosts file 
# by putting the correct address of other machines IP if they have multiple
# network interfaces. 
# Example: A node should get the gateways internal (LAN) IP in the hosts file, not its external.

sub hostsFile_version {
    print "hostsFile version 1\n";
}


sub hostsFile_configure {
    
    my $hostname = $_[0];
    my $hostlist;
    my %network = getHash("/host/$hostname/network");
    my $if;
    foreach $if (keys %network){
	my $switch = $network{$if}{"switch"};
	if ( $switch ) {
	    $hostlist = hostsFile_traverseSwitches($switch,"$hostname:");
	}
	else {
	    $hostlist = '';
	    for my $this_host (getHosts()) {
	       my $curaddr = getScalar("/host/$this_host/network/eth0/address");
	       $hostlist .= join(':', ($curaddr,$this_host));
	       $hostlist .= ':';
            }
	}
    }
#    print "hostsFile returned $hostlist for $hostname\n";
    my @array = split /:/,$hostlist;
    my @hostsFile;
    if ( @array ){
	my $i;
	for ( $i = 0; $i <= $#array; $i++ ){
	    push(@hostsFile,"$array[$i] " . $array[$i + 1]);
	    #push(@hostsFile,"$array[$i] " . $array[$i + 1] . "\n");
	    $i++;
	}
#	print (@hostsFile);
	addToFile($hostname,"/etc/hosts",\@hostsFile);
    }
}

sub hostsFile_traverseSwitches {
    
    my $switch = $_[0];
    my $hostnames = $_[1];
    my $result; 
    my %hosts = getHash("/switch/$switch/hosts");
    my $host;
    foreach $host (%hosts){
#	print "checking $host\n"; 
	if ( not $hostnames =~ /(^|:)$host(:|$)/ ){
	    my $address = getScalar("/host/$host/network/$hosts{$host}/address");
	    if ( $address ){
#		print "adress found. adding: $address:$host\n"; 
		$result .= "$address:$host:";
#                print "result = $result\n";
		#$hostnames .= ":$host";
		$hostnames .= "$host:";
#                print "hostnames = $hostnames\n";
	    }
	}
    }
    # we do two rounds because this is a width-first search
    foreach $host (%hosts){
	if ( not $hostnames =~ /(^|:)$host(:|$)/ ){
	    my $address = getScalar("/host/$host/network/$hosts{$host}/address");
	    if ( $address ){
		@interfaces = getBlockKeys("/host/$host/network");
		if ( $#interfaces > 0 ) {
		    my $i;
		    foreach $i (@interfaces){
			my $s = getScalar("/host/$host/network/$i/switch");
			if ( $s ){
			    $result .= hostsFile_traverseSwitches($s,$hostnames);
			}
		    }
		}
	    }
	}
    }
#    print "returning $result\n";
    return $result;
}

1;
