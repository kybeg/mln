##
# ISCSI BACKEND PLUGIN FOR MLN
# written by Kyrre Begnum
##

my $ISCSI_PLUGIN_VERSION = 1.2;

my $ISCSI_QUIET = "1>/dev/null";

sub iscsi_version {
    out("iSCSI backend plugin version $ISCSI_PLUGIN_VERSION\n");
    
}

sub iscsi_getDiskResource {
    my $host = $_[0];
    my $project = $_[1];
    my $temp_root = $_[2];
#    print "ISCSI: getDiskResource called for $host.$project\n";
    my $iscsi = getScalar("/host/$host/iscsi",$temp_root);
#    out("iscsi: $iscsi\n");
    if ( $iscsi ){
#	print "This is an iscsi device\n";
	my $name = iscsi_getFilesystemPath_nocheck($host,$project);
#	return "ISCSI:$name";
    }    
}

# a VM is about to be migrated
sub iscsi_incomingLiveVM {
    my $host = $_[0];
    my $project = $_[1];
    my $path = $_[2];
    out("incoming live VM: $host, $project. Path = $path\n");
    my $iscsi = getScalar("/host/$host/iscsi");
    out("iscsi: $iscsi\n");
    if ( $iscsi ){
	my $name = $path;
	$name =~ s/^.*:3260-iscsi-(.*)-lun-0/$1/;
	if ( not stat("$filesystem")){
	    system("iscsiadm -m node -T $name -p $iscsi -o new $ISCSI_QUIET");
	    system("iscsiadm -m node -T $name -p $iscsi -l $ISCSI_QUIET");
	    sleep 1;
	}
	
	if ( not stat("$path")){
	    out("Waiting and retrying\n");

	    sleep 2;
	    if ( not stat("$path")){
		system("iscsiadm -m  node -T $name -p $iscsi -l $ISCSI_QUIET");
		sleep 2;
	    }
	}	
	iscsi_storePath($host,$path);
    }            

}

# the VM has just left
sub iscsi_releaseVMfilesystem {
    my $host = $_[0];
    my $project = $_[1];
    my $iscsi = getScalar("/host/$host/iscsi");
    out("iscsi_release $host.$project from $iscsi\n");
    if ( $iscsi ){
	my $filesystem = iscsi_getFilesystemPath($host,$project);
#	print "filesystem: $filesystem\n";
	my $name = $filesystem;
	$name =~ s/^.*:3260-iscsi-(.*)-lun-0/$1/;
    
	system("iscsiadm -m node -T $name -p $iscsi -u $ISCSI_QUIET");
	system("iscsiadm -m node -T $name -p $iscsi -o delete $ISCSI_QUIET");
	
    }
}


sub iscsi_getImportExportFiles {
    my $host = $_[0];
    my $project = $_[1];
    my %return_target;
    my $iscsi = getScalar("/host/$host/iscsi");
    if ( $iscsi ){
#	print "iscsi plugin called\n";
	my $filesystem = iscsi_getFilesystemPath($host,$project);
#	print "filesystem: $filesystem\n";
	my $name = $filesystem;
	$name =~ s/^.*:3260-iscsi-(.*)-lun-0/$1/;
	if ( not stat("$filesystem")){
	    system("iscsiadm -m node -T $name -p $iscsi -o new $ISCSI_QUIET");
	    system("iscsiadm -m node -T $name -p $iscsi -l $ISCSI_QUIET");
	    sleep 1;
	}
	
	if ( not stat("$filesystem")){
	    out("Waiting for block device to appear\n");
	    sleep 2;
	    if ( not stat("$filesystem")){
		system("iscsiadm -m node -T $name -p $iscsi -l $ISCSI_QUIET");
		sleep 2;
	    }
	}
	if ( not stat("$filesystem")){
	    warn "Error, filesystem not connected\n";
	} else {

	    $return_target{$host} = $filesystem;
#	    print "$host -> $return_target{$host}\n";	    
	}

	return %return_target;
    } 
    verbose("ISCSI: returning nothing\n");
}

sub iscsi_createFilesystem {
 
    my $hostname = $_[0];
    my $iscsi = getScalar("/host/$hostname/iscsi");
    if ( $iscsi ){
	my $iscsi_target = getScalar("/host/$hostname/iscsi_target");
	
	out("ISCSI plugin enabled\n");
	my $tem            = getScalar("/host/$hostname/template");
	my $filesystem     = getScalar("/host/$hostname/filesystem");
	my $swap           = getScalar("/host/$hostname/swap");
	my $size           = getScalar("/host/$hostname/size");
	my $free_space     = getScalar("/host/$hostname/free_space");
	my $hvm           = getScalar("/host/$hostname/hvm");

	$size       = $DEFAULTS{FILESYSTEM_SIZE} unless $size;
	$tem        = $DEFAULTS{TEMPLATE}        unless $tem;

	my $template = getLatestTemplate($tem);    
	out("Template $template\n");
	my $multiplier  = 1;
	my %BLOCK_UNITS = (
	    'b'  => 512,
	    'kB' => 1000,
	    'KB' => 1000,
	    'K', => 1024,
	    'MB' => 1000 * 1000,
	    'M'  => 1024 * 1024,
	    'GB' => 1000 * 1000 * 1000,
	    'G'  => 1024 * 1024 * 1024,
	);

	my $t_size      = getTemplateSize($template);
	
	$size =~ /^(\d+)([A-Za-z]*)/;
	$multiplier = $BLOCK_UNITS{$2} if $2;
	if ( not $multiplier ) {
	    out("ERROR: bad units or template size: $size");
	return;
	}
	my $temp_size = $1 * $multiplier;
	
	if ($free_space) {
	    $free_space =~ /^(\d+)([A-Za-z]*)/;
	    $multiplier = $BLOCK_UNITS{$2} if $2;
	    $temp_size = int( ( $t_size + ( $1 * $multiplier ) ) );	
	}
	
	if ( $t_size > $temp_size ) {
	    out("Template size:\t$t_size\nNew size:\t$temp_size\n");
	    out(
		"WARNING: Template is larger then new filesystem!\nAdjusting size to fit template.\n",
		"red"
	    );
	    $temp_size = $t_size + 1024;
	    
	}
	if ( not $iscsi_target ){
	out("Contacting $iscsi for ISCSI partition\n");
	my $sock = connect_to_server($iscsi,34002);
	if ( $sock) {
	    print $sock "request:$hostname.$PROJECT:$temp_size:$template\n";
	    my $line;
	    my $path;
	    $line = <$sock>;
	    close($sock);
	    if ( $line =~ /OK:NOTEMPLATE:(.*)\n/ ){
		# i need to insert my own template
		out("got $1, but need to copy template manually\n");

		$path = $1;
		# log on to the ISCSI device
		system("iscsiadm -m node -T $path -p $iscsi -o new $ISCSI_QUIET"); 
#		print("iscsiadm -m node -T $path -p $iscsi -l"); 
		system("iscsiadm -m node -T $path -p $iscsi -l $ISCSI_QUIET"); 
		my $old_path = $path;
		

		$path = "/dev/disk/by-path/ip-" . $iscsi . ":3260-iscsi-" . ${path} . "-lun-0";
		if ( not stat("$path")){
#		    print "waiting\n";
		    out("Waiting for block device to appear\n");
		    sleep 2;
		    if ( not stat("$path")){
#		    print("iscsiadm -m node -T $old_path -p $iscsi -l $ISCSI_QUIET"); 
			system("iscsiadm -m node -T $old_path -p $iscsi -l $ISCSI_QUIET"); 
			sleep 1;
		    }
		}
#		system("ls /dev/disk/by-path");
		if ( not stat("$path")){
		    die "Cannot find block device $path\n";
		}

		iscsi_storePath($hostname,$path);
#		print "$shell{'DD'} if=$TEMPLATEDIR/$template of=$path\n";
		out("Copying image with dd to iSCSI device, please wait.\n");
		system("$shell{'DD'} if=$TEMPLATEDIR/$template of=$path");

		if ( $template =~ /\.ext\d$/ ){
		    out("Running fsck on filesystem\n");
		    system("$shell{'FSCK'} -y -f $path $ISCSI_QUIET");
		    out("Resizing filesystem\n");
		    system("$shell{'RESIZE2FS'} $path $ISCSI_QUIET");
		} elsif ( $template =~ /\.fat32$/ ){    
		    system("/sbin/parted $path resize 1 32kB 100%");
		}
		
		system("iscsiadm -m node -T $old_path -p $iscsi -u $ISCSI_QUIET");
		return 1;
		last;
	    } elsif ( $line =~ /OK:WITHTEMPLATE:(.*)\n/ ){
		    # the filesystem is ready for us, 
		out("got $1, with template installed!\n");
		$path = $1;
		$path = "/dev/disk/by-path/ip-" . $iscsi . ":3260-iscsi-" . ${path} . "-lun-0";
		iscsi_storePath($hostname,$path);
		return 1;
		last;
	    } elsif ( $line =~ /NO:(.*)\n/ ){
		out("FAILURE: $1\n");
		close($sock);
		die("dying...\n");
	    }
	    

	} else {
	    die "connection failed: $!\n";
	}
	} elsif( $iscsi_target ){
	    $path = $iscsi_target;
	    out("Connecting to pre-allocated target $iscsi_target\n");
	    system("iscsiadm -m node -T $path -p $iscsi -o new $ISCSI_QUIET"); 
	    verbose("iscsiadm -m node -T $path -p $iscsi -l"); 
	    system("iscsiadm -m node -T $path -p $iscsi -l $ISCSI_QUIET"); 
	    my $old_path = $path;
		

	    $path = "/dev/disk/by-path/ip-" . $iscsi . ":3260-iscsi-" . ${path} . "-lun-0";
	    if ( not stat("$path")){
		out("Waiting for block device to appear\n");
		sleep 2;
		if ( not stat("$path")){
	
		    verbose("iscsiadm -m node -T $old_path -p $iscsi -l"); 
		    system("iscsiadm -m node -T $old_path -p $iscsi -l $ISCSI_QUIET"); 
		    sleep 2;
		}
	    }
	    # system("ls /dev/disk/by-path");
	    if ( not stat("$path")){
		die "Cannot log in to target\n";
	    }

	    iscsi_storePath($hostname,$path);
	    out("Transfering image to iSCSI target\n");
	    verbose("$shell{'DD'} if=$TEMPLATEDIR/$template of=$path\n");
	    system("$shell{'DD'} if=$TEMPLATEDIR/$template of=$path $ISCSI_QUIET");
	    out("Fsck and resize\n");
	    if ( $template =~ /\.ext\d$/ ){
		system("$shell{'FSCK'} -y -f $path $ISCSI_QUIET");
		system("$shell{'RESIZE2FS'} $path $ISCSI_QUIET");
	    } elsif ( $template =~ /\.fat32$/ ){    
		system("/sbin/parted $path resize 1 32kB 100%");
	    }
	    out("Disconnecting target\n");
	    system("iscsiadm -m node -T $old_path -p $iscsi -u $ISCSI_QUIET");
	    return 1;
	    
	}
	return 1;
    }
}

sub iscsi_mountFilesystem {
    my $hostname = $_[0];
    my $iscsi = getScalar("/host/$hostname/iscsi");
    if ( $iscsi ){
#	my $hvm = getScalar("/host/$hostname/hvm");
	my $iscsi_target = getScalar("/host/$hostname/iscsi_target");
	out("ISCSI plugin enabled for mountFilesystem action\n");
	my $filesystem = iscsi_getFilesystemPath($hostname);
	
	my $name = $filesystem;
	$name =~ s/^.*:3260-iscsi-(.*)-lun-0/$1/;
	system("iscsiadm -m node -T $name -p $iscsi -o new $ISCSI_QUIET");
	system("iscsiadm -m node -T $name -p $iscsi -l $ISCSI_QUIET");
	if ( not stat("$filesystem")){
	    out("Waiting for block device to appear\n");
	    sleep 2;
	    if ( not stat("$filesystem")){
		system("iscsiadm -m node -T $name -p $iscsi -l $ISCSI_QUIET");
		out("Still waiting for block device to appear\n");
		sleep 2;
	    }
	}
	if ( not stat("$filesystem")){
	    out("Error, filesystem not connected\n");
	}
	my $return = `$shell{'MOUNT'} $options $filesystem $MOUNTDIR 2>&1`;
	
#	print "mount return: $return\n";
	if ( not $return ){
	    out("Filesystem mounted successfully\n");
	} else {
	    out("Mounting HVM disc: ");
	    $SIG{"CHLD"} = $OLDSIG;
	    my $ret = system(
		"$shell{'MOUNT'} -o offset=32256  -t ntfs-3g $filesystem  $MOUNTDIR"
	    );
#	    out("ret = $ret\n");
	    my $mount = `df -h | grep $MOUNTDIR`;
	    system("$shell{'MOUNT'} -v");
	    if ( $ret == 0 or $mount ){
		out("success\n");
	    } else {
		
		out("Mounting HVM disk with NTFS-3g disc: ");
		my $ret = system(
		    "$shell{'MOUNT'} -o offset=32256 -t ntfs-3g  $filesystem  $MOUNTDIR"
		);
		if ( $ret == 0 ){
		    out("success\n");
		} else {
		    out("FALIURE\n");
		}
		
	    }
	}
	return 1;
    }
}

sub iscsi_createStartStopScripts {
    my $hostname = $_[0];
    my $iscsi = getScalar("/host/$hostname/iscsi");

    if ( $iscsi ){
	my $bo = getScalar("/host/$hostname/boot_order");
	$bo = 99 unless $bo;
	my $filesystem = iscsi_getFilesystemPath($hostname);
	my $name = $filesystem;
	$name =~ s/^.*:3260-iscsi-(.*)-lun-0/$1/;

	my @start = `cat $PROJECT_PATH/$PROJECT/start_${bo}_$hostname.sh`;
	open(START,">$PROJECT_PATH/$PROJECT/start_${bo}_$hostname.sh");
	my $tag;
	foreach (@start){
	    print START $_;
	    if ( not $tag and $_ eq "fi\n" ){
		$tag = 1;
		print START "echo Connecting to iSCSI target $name\n";
		print START "iscsiadm -m node -T $name -p $iscsi -o new $ISCSI_QUIET\n";
		print START "iscsiadm -m node -T $name -p $iscsi -l $ISCSI_QUIET\n";
	    }
	}
	close(START);
#	my @stop = `cat $PROJECT_PATH/$PROJECT/stop_${bo}_$hostname.sh`;
	open(STOP,">>$PROJECT_PATH/$PROJECT/stop_${bo}_$hostname.sh");
	if ( getScalar("/host/$hostname/xen") ){
	    print STOP "echo Initiating background wait loop before disconnecting iSCSI device\n";
	    print STOP "while sleep 3; do if ! xm list $hostname.$PROJECT 1>>/dev/null 2>>/dev/null ; then iscsiadm -m node -T $name -p $iscsi -u $ISCSI_QUIET ; iscsiadm -m node -T $name -p $iscsi -o delete $ISCSI_QUIET; exit; fi;  done &\n";

	}
	close(START);

	return 1;
    }    
}

sub iscsi_unmountFilesystem {
    my $hostname = $_[0];
    my $iscsi = getScalar("/host/$hostname/iscsi");
    if ( $iscsi ){
#	my $hvm = getScalar("/host/$hostname/hvm");
	out("ISCSI plugin enabled for umountFilesystem action\n");
	my $filesystem = iscsi_getFilesystemPath($hostname);
	
	system("umount $MOUNTDIR");
	$SIG{"CHLD"} = "IGNORE";
	my $name = $filesystem;
	$name =~ s/^.*:3260-iscsi-(.*)-lun-0/$1/;
	system("sync");
	sleep 1;
	system("iscsiadm -m node -T $name -p $iscsi -u $ISCSI_QUIET");
	system("iscsiadm -m node -T $name -p $iscsi -o delete $ISCSI_QUIET");

	return 1;
    }
}

# This is a helper method to store the name of the 
# ISCSI path for a particular VM.
# The location it is stored in is $PROJECT_PATH/iscsi/$hostname

sub iscsi_storePath {
    my $hostname = $_[0];
    my $path = $_[1];
    my $project = $PROJECT;
    if ( not $PROJECT ){
	$project = getScalar("/global/project");
    }
    if ( not stat("$PROJECT_PATH/$project/iscsi")){
#	out("Creating directory $PROJECT_PATH/$PROJECT/iscsi\n");
	system("mkdir -p $PROJECT_PATH/$project/iscsi");
    }
    open(VM,">$PROJECT_PATH/$project/iscsi/$hostname") or die "error, could not open $PROJECT_PATH/$project/iscsi/$hostname $!\n";
    print VM "$path\n";
    close(VM);
    
}

# helper method for returning the Device path

sub iscsi_getFilesystemPath {
    my $hostname = $_[0];
    my $project = $PROJECT; 
    $project = $_[1] if $_[1]; 
    my $iscsi = getScalar("/host/$hostname/iscsi");
    if ( $iscsi ){
	open(VM,"$PROJECT_PATH/$project/iscsi/$hostname");
	my $line = <VM>;
	chomp $line;
	return $line;
    }
}
sub iscsi_getFilesystemPath_nocheck {
    my $hostname = $_[0];
    my $project = $PROJECT; 
    $project = $_[1] if $_[1]; 
    open(VM,"$PROJECT_PATH/$project/iscsi/$hostname") or print "Error: $PROJECT_PATH/$project/iscsi/$hostname: $!\n";
    my $line = <VM>;
    chomp $line;
    return $line;
    
}


sub iscsi_removeHost {
    my $hostname = $_[0];
    my $project = $_[1];
    
    my $iscsi = getScalar("/host/$hostname/iscsi");
    if ( $iscsi ){
	out("ISCSI plugin enabled for filesystem removal\n");
	my $filesystem = iscsi_getFilesystemPath($hostname,$project);	
	my $name = $filesystem;
#	print "name: $name\n";
	$name =~ s/^.*:3260-iscsi-(.*)-lun-0/$1/;
	out("ISCSI: removing $name from $iscsi\n");
	system("iscsiadm -m node -T $name -p $iscsi -u  $ISCSI_QUIET");
	system("iscsiadm -m node -T $name -p $iscsi -o delete  $ISCSI_QUIET");
	
	my $sock = connect_to_server($iscsi,34002);
	if ( $sock ){
	    print $sock "remove:$hostname.$project\n";
	}
	
	return 1;
    }
}


1;