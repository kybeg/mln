sub internalswap_configure {
    my $hostname = $_[0];
    my $internalswap = getScalar("/host/$hostname/internalswap");
    if ( $internalswap ){
	system("dd if=/dev/zero of=$MOUNTDIR/swapfile count=1 bs=$internalswap");
	system("mkswap $MOUNTDIR/swapfile");
	
	open(FSTAB,">>$MOUNTDIR/etc/fstab");
	print FSTAB "/swapfile none swap sw 0 0\n";
	close(FSTAB);
	
    }        
}

1;