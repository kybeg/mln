# Apache plugin for apache2, written by Kyrre Begnum
# This plugin will change the default document root
# for a virtual machine with apache2 installed.
# example: 
# host webserver {
#      apache {
#           DocumentRoot /etc/HTML
#      }
# }
#

my $APACHEVERSION = 0.8;

sub apache_version {
    print "Apache plugin version $APACHEVERSION\n";
}

sub apache_configure {
    # The name of this particular VM
    my $vm = $_[0];
    
    # First we check if this VM has a apache block in its configuration
    if ( getScalar("/host/$vm/apache")){
	out("Apache plugin enabled for this host");
	# get the document root
	my $docroot = getScalar("/host/$vm/DocumentRoot");

	# Open the apache.conf file on the VM and edit it
	# The filesystem is already mounted on $MOUNTDIR

	my @conf = `cat $MOUNTDIR/etc/apache2/sites-enabled/000-default`;
	# Write the new version of the file to disk:
	open(CONF,">$MOUNTDIR/etc/apache2/sites-enabled/000-default");
	my $line;
	foreach $line (@conf ){
	    if ( $line =~ /DocumentRoot/ ){
		$line = "DocumentRoot $docroot\n"; 
	    } 		
	    print CONF $line;
	}	
	close(CONF);	
    }
}

1;