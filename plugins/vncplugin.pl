# VNCplugin written by Kyrre Begnum
#
# This plugin sets a VNC server password. 
# Since the vncpasswd command is interactive, this plugin will write 
# a startup script which uses exptect to communicate with the command.

# This plugin only works for filesystems where vncpasswd and expect are installed.

# The VNC password file is stored in /root/.vncpasswd


my $VNCPLUGINVERSION = "1.0";

sub vncplugin_version {
    print "vncplugin version $VNCPLUGINVERSION\n";
    
}

sub vncplugin_configure {
    if ( getScalar("/host/$_[0]/vncplugin")){
	print "vncplugin activated\n";
	open(FILE,">$MOUNTDIR/etc/init.d/vncplugin");
	print FILE "#!/bin/bash\n";
	my $vncpasswd = getScalar("/host/$_[0]/vncpasswd");
	print FILE "expect -c \"spawn vncpasswd /root/.vncpasswd; expect 'Password: '; send $vncpasswd\\r; expect 'Verify: '; send $vncpasswd\\r; interact;\"\n";
	print FILE "chmod 644 /root/.vncpasswd\n";
	print FILE "# rm /etc/init.d/vncplugin\n";
	print FILE "# rm /etc/rc2.d/S10vncplugin\n";
	close(FILE);
	system("ln -s /etc/init.d/vncplugin $MOUNTDIR/etc/rc2.d/S10vncplugin");
	system("chmod +x $MOUNTDIR/etc/init.d/vncplugin"); 
       
    }
}

1;