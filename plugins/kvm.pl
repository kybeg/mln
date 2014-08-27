# KVM plugin
# Written by Kyrre Begnum
#


#####################
# CONFIGURATION
####################
my $EC2_MODULES_i386 = "/opt/mln/2.6.16-xenU";
my $EC2_MODULES_x86_64 = "/opt/mln/2.6.16.33-xenU";
my $EC2_USER = "/root/.amazon/user.txt";
my $EC2_SECRET = "/root/.amazon/secret.txt";
my $EC2_ACCESS = "/root/.amazon/access.txt";
my $EC2_CERT = "/root/.amazon/cert.pem";
my $EC2_PRIVATE_KEY = "/root/.amazon/pk.pem";
# Valid types: m1.small, m1.large, m1.xlarge, c1.medium, c1.xlarge
my $EC2_DEFAULT_TYPE = "m1.small"; 
my $EC2_DEFAULT_AVAILABILITY_ZONE = "us-east-1b";
my $EC2_DEFAULT_KERNEL = "";
my $EC2_DEFAULT_RAMDISK = "";
my $EC2_DEFAULT_GROUP = "default";
my $EC2_DEFAULT_MOUNT1 = "/mnt";
my $EC2_DEFAULT_MOUNT2 = "/mnt2";
my $EC2_DEFAULT_REGION = "US"; # Alternative: EU
my $EC2_DEFAULT_ARCH = "i386"; # Alternative: x86_64
my $EC2_DEFAULT_BUCKET = ""; # Alternative: x86_64
#####################

my $EUCA_HOME = "euca_home.txt";
my $EC2_URL_FILE = "ec2_url.txt";
my $S3_URL_FILE = "s3_url.txt";
my $EC2_URL = 'https://ec2.amazonaws.com';
my $S3_URL = 'https://s3.amazonaws.com';
my $EC2_HOME_FILE = "ec2_home.txt";
my $S3_HOME_FILE = "s3_home.txt";
my $EC2_AMITOOL_HOME = $ENV{'EC2_AMITOOL_HOME'};
my $EC2_HOME = $ENV{'EC2_HOME'};
# my $S3_CERT_FILE = 
my $S3_CERT = "cloud-cert.pem";
#############################################

my $KVM_VERSION = 0.1;

my $KVM_DEFAULT_PARTITION = "p1";

my $KVM_PREFIX = "KVM: ";

#############################################

sub kvm_version{ 
    out("KVM plugin version $KVM_VERSION\n");
}


sub kvm_createFilesystem {
    my $hostname = $_[0];
    my $kvm = getScalar("/host/$hostname/kvm");
    my $silent = "";
    if  ( $kvm ){
	# what is the template name?
	my $tem            = getScalar("/host/$hostname/template");
	my $filepath       = getScalar("/host/$hostname/filepath");
	my $lvm       = getScalar("/host/$hostname/lvm");
	my $lvm_snapshot = getScalar("/host/$hostname/lvm_snapshot");
	my $template = getLatestTemplate($tem);    
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
	my $t_size = $t_size / 1024 / 1024;
#	$t_size       = $DEFAULTS{FILESYSTEM_SIZE} unless $size;
	if ( $lvm ) {
	    my $vg = getScalar("/host/$hostname/lvm_vg");
	    $vg = $DEFAULTS{'MLN_VG'} if not $vg;
	    
	    if ( $lvm_snapshot ){
		if (stat("/dev/$vg/$template")){
		    out("Creating snapshot of /dev/$vg/$template, ");
		    my $lvout = `lvdisplay -c /dev/$vg/$template`;
		    my @snap_size = split /:/,$lvout;
		    lvm_execute($lvm,"/dev/$vg/$template","$shell{'LVCREATE'} -s -L " . int($snap_size[6]/2/1024). "M -n $hostname.$PROJECT /dev/$vg/$template ");
		}
	    } else {
		out($KVM_PREFIX . "Building filesystem: lvcreate, ");
		verbose($KVM_PREFIX . "$shell{'LVCREATE'} $options -n $hostname.$PROJECT --size ${t_size} $vg ");
#	    $size = int($size / 1024);
		lvm_execute($lvm,"/dev/$vg/$hostname.$PROJECT","$shell{'LVCREATE'} -n $hostname.$PROJECT --size ${t_size} $vg ");
		out("copying template,\n");
#		system("ls /dev/$vg");
#	    system("vgchange -ay /dev/$vg ");
		system("$shell{'DD'} if=$TEMPLATEDIR/$template of=/dev/$vg/$hostname.$PROJECT bs=4096 $silent");
	    }
	} else {
	    # not LVM
	    out($KVM_PREFIX . "Copying template $template\n");
	    my $destination = "$IMAGEDIR/$hostname";
	    if ( $filepath ){
		$destination = "$filepath/$hostname.$PROJECT";
	    } 
	    
	    system("cp $TEMPLATEDIR/$template $destination");	    
	}

	
	# We will not fix resizing for now, allthough it is possible
	

	# where is it going?		
	
	return 1;
    } else {
	
	return; 
    }
}


sub kvm_mountFilesystem {
    my $hostname = $_[0];
    my $kvm = getScalar("/host/$hostname/kvm");
    my $silent = "";
    if  ( $kvm ){
 
	# ...
	my $filepath       = getScalar("/host/$hostname/filepath");
	my $lvm       = getScalar("/host/$hostname/lvm");
	my $vg = getScalar("/host/$hostname/lvm_vg");
	$vg = $DEFAULTS{'MLN_VG'} if not $vg;
	my $partition = getScalar("/host/$hostname/kvm/mount_partition");
	$partition = $KVM_DEFAULT_PARTITION unless $partition;
	
	# get a vacant loop device
	
	my $loopdev = `losetup -f`;
	chomp $loopdev;

	# use losetup to get it
	my $destination = "$IMAGEDIR/$hostname";
	if ( $lvm ){
	    $destination = "/dev/$vg/$hostname.$PROJECT";	    
	} elsif ( $filepath ){
	    $destination = "$filepath/$hostname.$PROJECT";
	}
	verbose($KVM_PREFIX . "attaching $destination to $loopdev\n");

	system("losetup $loopdev $destination");
	
	# use kpartx something
	system("kpartx -av $loopdev >/dev/null");	
	
	# mount the partition
	my $loopnum = $loopdev;
	$loopnum =~ s/^[^0-9]*(\d+)$/$1/;
	$command = "mount /dev/mapper/loop${loopnum}$partition $MOUNTDIR";
	verbose($KVM_PREFIX . "$command\n");
	system("$command");
#	system("cat $MOUNTDIR/etc/fstab");
	return 1;
    } else {
	return;
    }
    
}

sub kvm_unmountFilesystem {
    my $hostname = $_[0];
    my $kvm = getScalar("/host/$hostname/kvm");
    my $silent = "";
    if  ( $kvm ){
	my $filepath       = getScalar("/host/$hostname/filepath");
	my $lvm       = getScalar("/host/$hostname/lvm");
	my $vg = getScalar("/host/$hostname/lvm_vg");
	$vg = $DEFAULTS{'MLN_VG'} if not $vg;
 
	# ...
	# get the destination
	my $destination = "$IMAGEDIR/$hostname";
	if ( $lvm ){
	    $destination = "/dev/mapper/${vg}-$hostname.$PROJECT";	    
	} elsif ( $filepath ){
	    $destination = "$filepath/$hostname.$PROJECT";
	}
#	system("cat $MOUNTDIR/etc/fstab");
	# unmount $MOUNTDIR
	system("umount $MOUNTDIR");
	
	# find the correct mapping
	open(LO,"losetup -a |") or die "Fatal when opening losetup: $!\n";
	my $loopdev;
	while( my $line = <LO> ){
	    if ( $line =~ /^(.*): .* \($destination\)/ ){
		verbose($KVM_PREFIX . "Found loopdev $1 was connected to $destination\n");
		$loopdev = $1;
		last;
	    }
	}
	system("kpartx -dv $loopdev >/dev/null");
	system("losetup -d $loopdev");
	
	return 1;
    } else {
	return;
    }
    
}

sub kvm_writeXMLconfig {
    
    my $hostname = $_[0];
    my $memory         = getScalar("/host/$hostname/memory");
    my %network        = getHash("/host/$hostname/network");
    my $cpus = getScalar("/host/$hostname/cpus");
    my $vcpus = getScalar("/host/$hostname/vcpus");
    my $display = getScalar("/host/$hostname/kvm/display");
    my $port = getScalar("/host/$hostname/kvm/display_port");

    
    
    $memory     = $DEFAULTS{MEMORY}          unless $memory;
    $memory = $memory * 1024;
    $vcpus = $DEFAULTS{VCPUS} unless $vcpu;
    $cpus = $DEFAULTS{CPUS} unless $cpus;

    my $filepath       = getScalar("/host/$hostname/filepath");
    my $lvm       = getScalar("/host/$hostname/lvm");
    my $vg = getScalar("/host/$hostname/lvm_vg");
    $vg = $DEFAULTS{'MLN_VG'} if not $vg;
 
    # ...
    # get the destination
    my $destination = "$IMAGEDIR/$hostname";
    if ( $lvm ){
	$destination = "/dev/$vg/$hostname.$PROJECT";	    
    } elsif ( $filepath ){
	$destination = "$filepath/$hostname.$PROJECT";
    }    
    
    mkdir("$PROJECT_PATH/$PROJECT/libvirt");
    open(LIBVIRT,">$PROJECT_PATH/$PROJECT/libvirt/$hostname.$PROJECT.xml");
    print LIBVIRT "<domain type='kvm' >\n";
    print LIBVIRT "<name>$hostname.$PROJECT</name>\n";
    # memory
    
    print LIBVIRT "<memory>$memory</memory>\n";
    # cpus ( vcpus )
    print LIBVIRT "<vcpu>$vcpus</vcpu>\n";

    print LIBVIRT "<os>\n";
    print LIBVIRT "<type arch='x86_64' >hvm</type>\n";
    print LIBVIRT "<boot dev='hd'/>\n";
    print LIBVIRT "</os>\n";
    
    print LIBVIRT "<features>\n";
    print LIBVIRT "<acpi/>\n";
    print LIBVIRT "<apic/>\n";
    print LIBVIRT "<pae/>\n";
    print LIBVIRT "</features>\n";
    
    print LIBVIRT "<clock offset='utc'/>\n";
    print LIBVIRT "<on_poweroff>destroy</on_poweroff>\n";
    print LIBVIRT "<on_reboot>restart</on_reboot>\n";
    print LIBVIRT "<on_crash>restart</on_crash>\n";
    print LIBVIRT "<devices>\n";
    print LIBVIRT "<emulator>/usr/bin/kvm</emulator>\n";
    
    # disk
    print LIBVIRT "<disk type='file' device='disk'>\n";
    print LIBVIRT "<driver name='qemu' type='raw'/>\n";
    print LIBVIRT "<source file='$destination'/>\n";
    print LIBVIRT "<target dev='hda' bus='ide'/>\n";
    print LIBVIRT "<alias name='ide0-0-0'/>\n";
    print LIBVIRT "<address type='drive' controller='0' bus='0' unit='0'/>\n";
    print LIBVIRT "</disk>\n";
    
    print LIBVIRT "<disk type='block' device='cdrom'>\n";
    print LIBVIRT "<driver name='qemu' type='raw'/>\n";
    print LIBVIRT "<target dev='hdc' bus='ide'/>\n";
    print LIBVIRT "<readonly/>\n";
    print LIBVIRT "<alias name='ide0-1-0'/>\n";
    print LIBVIRT "<address type='drive' controller='0' bus='1' unit='0'/>\n";
    print LIBVIRT "</disk>\n";
    
    print LIBVIRT "<controller type='ide' index='0'>\n";
    print LIBVIRT "<alias name='ide0'/>\n";
    print LIBVIRT "<address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x1'/>\n";
    print LIBVIRT "</controller>\n";

    # nettverk
    my $if;
    
    if ( %network) {
	my @interfaces = keys %network;
	my $i;
	for ($i = 0; $i <= $#interfaces; $i++ ) {
	    $if = "eth" .$i;
	    if ( $network{$if} ){
		if ( $network{$if}{"bridge"} ) {
		    print LIBVIRT "<interface type='bridge'>\n";
		    print LIBVIRT "<source bridge='$network{$if}{'bridge'}'/>\n";
		    if ( $network{$if}{"mac"}) {
			print LIBVIRT "<mac address='$network{$if}{'mac'}'/>\n";
		    } else {
			# i need to generate a MAC address.
			
		    }
		} else {
		    # We will attempt to detect the default bridge
		    print LIBVIRT "<interface type='network'>\n";
		    print LIBVIRT "<source network='default'/>\n";
		    print LIBVIRT "<target dev='vnet0'/>\n";
		    print LIBVIRT "<alias name='net0'/>\n";
		    print LIBVIRT "<address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>\n";		    my $bridge = detectXenBridge();
		}
	    }
	    print LIBVIRT "</interface>\n";
	}
    }


#    
#    print LIBVIRT "</interface>\n";

    print LIBVIRT "<serial type='pty'>\n";
    print LIBVIRT "<source path='/dev/pts/8'/>\n";
    print LIBVIRT "<target port='0'/>\n";
    print LIBVIRT "<alias name='serial0'/>\n";
    print LIBVIRT "</serial>\n";
    print LIBVIRT "<console type='pty' tty='/dev/pts/8'>\n";
    print LIBVIRT "<source path='/dev/pts/8'/>\n";
    print LIBVIRT "<target type='serial' port='0'/>\n";
    print LIBVIRT "<alias name='serial0'/>\n";
    print LIBVIRT "</console>\n";
    print LIBVIRT "<input type='mouse' bus='ps2'/>\n";
    
    print LIBVIRT "<sound model='ich6'>\n";
    print LIBVIRT "<alias name='sound0'/>\n";
    print LIBVIRT "<address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>\n";
    print LIBVIRT "</sound>\n";

    if ( $port ){
	my $port_t = "port='$port'"
    } else {
	my $port_t = "autoport='yes'"
    }
    print LIBVIRT "<graphics type='$display' $port listen='0.0.0.0' />\n";
    print LIBVIRT "<video>\n";
    if ( $display eq "spice" ){
	print LIBVIRT "<model type='qxl' heads='1'/>\n";
    } else {
	print LIBVIRT "<model type='cirrus' vram='9216' heads='1'/>\n";
    }
    print LIBVIRT "<alias name='video0'/>\n";
    print LIBVIRT "<address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>\n";
    print LIBVIRT "</video>\n";
    
    print LIBVIRT "<memballoon model='virtio'>\n";
    print LIBVIRT "<alias name='balloon0'/>\n";
    print LIBVIRT "<address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>\n";
    print LIBVIRT "</memballoon>\n";
    print LIBVIRT "</devices>\n";
    print LIBVIRT "<seclabel type='dynamic' model='selinux' relabel='yes'>\n";
    print LIBVIRT "<label>system_u:system_r:svirt_t:s0:c141,c961</label>\n";
    print LIBVIRT "<imagelabel>system_u:object_r:svirt_image_t:s0:c141,c961</imagelabel>\n";
    print LIBVIRT "</seclabel>\n";
    print LIBVIRT "</domain>\n";

    close(LIBVIRT);

}

sub kvm_configure {
    my $hostname = $_[0];

    my $kvm = getScalar("/host/$hostname/kvm");
    if ( $kvm ){
	
	# create the XML file
	kvm_writeXMLconfig($hostname);

	
	# define the XML file - no
	
    }
}

sub kvm_checkIfUp {
    my $hostname = $_[0];
    my $project = $_[1];
    my $root = $_[2];
    if ( getScalar("/host/$hostname/kvm",$root)){
	
	open(LIBV,"virsh list |");
	while ( my $line = <LIBV> ){
	    if ( $line =~ /^\s+(\d+)\s+($hostname\.$project)\s+(\w+)$/ ){
		return "1 $1 $3"				
	    }	    
	}
	return "-1";
    } 
    return 0;
}

sub kvm_removeHost {
    
    my $hostname = $_[0];
    my $project = $_[1];
    my $root = $_[2];
    $root = $DATA_ROOT unless $root;
    if ( getScalar("/host/$hostname/kvm",$root) ){

    
    }
}

sub kvm_createStartStopScripts {
    my $hostname = $_[0];
    my $kvm = getScalar("/host/$hostname/kvm");
    
    if  ( $kvm ){
	out($KVM_PREFIX . "writing start/stop scripts\n");	

	my $bo = getScalar("/host/$hostname/boot_order");
      
	$bo = 99 unless $bo;
	       
	########################
	
	open(START,">$PROJECT_PATH/$PROJECT/start_${bo}_$hostname.sh");
	print START "#!/bin/bash\n";
	if ( getScalar("/host/$hostname/locking") ){
	    print START enableLock($hostname,"virsh create libvirt/$hostname.$PROJECT.xml\n");
	} else {
	    print START "virsh create libvirt/$hostname.$PROJECT.xml\n";	
	}
	close START;
	system("chmod 755 $PROJECT_PATH/$PROJECT/start_${bo}_$hostname.sh");	

	
	#######################
	
	open(STOP,">$PROJECT_PATH/$PROJECT/stop_${bo}_$hostname.sh");

	print STOP "#!/bin/bash\n";
	print STOP "command=\"shutdown\"\n";
	print STOP 'if [ "$1" == "halt" ]; then' . "\n";
	print STOP "command=\"destroy\"\n";
	print STOP "fi\n";
	
	if ( getScalar("/host/$hostname/locking")){
	    print STOP removeLock($hostname,"virsh \$command $hostname.$PROJECT");
	} else {
	    print STOP "virsh \$command $hostname.$PROJECT\n";
	}

	
	close(STOP);
	system("chmod 755 $PROJECT_PATH/$PROJECT/stop_${bo}_$hostname.sh");	

	
	
    }     
}

1;
