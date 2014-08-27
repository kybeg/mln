# MLN Xen plugin for adding stuff to the "extra" line

my $EXTRA_VERSION = 0.1;
sub extra_version { 
    out("Xen extra plugin version $EXTRA_VERSION\n");
}

# We can edit the Xen config file at this point, because 
# it is already created by MLN.
sub extra_createStartStopScripts {
    my $hostname = $_[0];
    my $extra = getScalar("/host/$hostname/extra");
    if ( $extra ){
	out("Adding to extra: $extra\n");
	my @file = `cat $PROJECT_PATH/$PROJECT/${hostname}_xen.cfg`;
	open(XEN,">$PROJECT_PATH/$PROJECT/${hostname}_xen.cfg");
	foreach my $line (@file){
	    if ( $line =~ /extra = '(.*)'/){
		print XEN "extra = '$1 $extra'\n";		
	    } else {
		print XEN $line;
	    }
	}
    }
}

1;