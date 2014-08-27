sub sshkey_configure {
    my $hostname = $_[0];
    my @keys = getArray("/host/$hostname/sshkey");
    if ( @keys ){
	out("SSHKEY plugin activated\n");
	my $line;
	foreach $line (@keys){
	    if ( $line =~ /^(\S+)\s+(.*)$/ ){
		my $user = $1;
		my $key = $2;
		if ( $user eq "root" ){
		    system("mkdir -p $MOUNTDIR/$user/.ssh");
		    system("echo $key >> $MOUNTDIR/$user/.ssh/authorized_keys");
		    system("chroot $MOUNTDIR chmod 600 /$user/.ssh/authorized_keys");
		    system("chroot $MOUNTDIR chmod 700 /$user/.ssh");
		    system("chroot $MOUNTDIR chown -R $user /$user/.ssh");
		    
		} elsif( stat("$MOUNTDIR/home/$user")){
		    system("mkdir -p $MOUNTDIR/home/$user/.ssh");
		    system("echo $key >> $MOUNTDIR/home/$user/.ssh/authorized_keys");
		    system("chroot $MOUNTDIR chmod 600 /home/$user/.ssh/authorized_keys");
		    system("chroot $MOUNTDIR chmod 700 /home/$user/.ssh");
		    system("chroot $MOUNTDIR chown -R $user /home/$user/.ssh");
		}
	    }
	}
	
    }
    
}

1;