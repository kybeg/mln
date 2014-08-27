# AMAZON EC2 plugin
# Written by Kyrre Begnum
#


#####################
# CONFIGURATION
####################
my $EC2_MODULES_i386 = "/opt/mln/2.6.16-xenU";
my $EC2_MODULES_x86_64 = "/opt/mln/3.2.0-36-virtual";
my $EC2_USER = "$ENV{'HOME'}/.amazon/user.txt";
my $EC2_SECRET = "$ENV{'HOME'}/.amazon/secret.txt";
my $EC2_ACCESS = "$ENV{'HOME'}/.amazon/access.txt";
my $EC2_CERT = "$ENV{'HOME'}/.amazon/cert.pem";
my $EC2_PRIVATE_KEY = "$ENV{'HOME'}/.amazon/pk.pem";
my $EC2_DEFAULT_TYPE = "t1.micro";
my $EC2_DEFAULT_AVAILABILITY_ZONE = ""; # for example eu-west-1
my $EC2_DEFAULT_KERNEL = "";
my $EC2_DEFAULT_RAMDISK = "";
my $EC2_DEFAULT_GROUP = "default";
my $EC2_DEFAULT_MOUNT1 = "/mnt";
my $EC2_DEFAULT_MOUNT2 = "/mnt2";
my $EC2_DEFAULT_REGION = "us-east-1"; 
my $EC2_DEFAULT_ARCH = "x86_64"; # Alternative: x86_64
my $EC2_DEFAULT_BUCKET = ""; # Alternative: x86_64
# change to 0 if you want to terminate tiny instances whenever you run mln stop .... 
# Same as 'no_terminate 1'
my $EC2_DEFAULT_ALWAYS_NOTERM_FOR_TINY = "1"; 
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
my $EC2_USERNAME;
my $EC2_VERSION = 1.2;

my $PREFIX = "EC2:";
# TODO: 
# - custom ami
# - automatic starting of VMs after upgrade (in main MLN)
# - Individual hostnames through user data DONE
# - mounting volumes DONE
# - persistent IPs DONE
# - custom credentials and custom credential folder per project / instance DONE
# - transient,persistent and existing volumes DONE
# - custom kernel image
# - "migrating" from one region to another
# - iscsi and getFilesystems troubles (returns hash, should return array, i think)
# - volumes and use together?

my @EC2_INSTANCE_CACHE;
my $EUCALYPTUS;
# $EC2_INSTANCE_CACHE[0] = "RESERVATION     r-ed02b684      118575708841    default\n";
# $EC2_INSTANCE_CACHE[1] = "INSTANCE        i-ab36b5c2      ami-588b6c31    ec2-174-129-182-211.compute-1.amazonaws.com     ip-10-251-106-145.ec2.internal running default 0               m1.small        2009-01-23T14:33:02+0000        us-east-1c\n";
sub ec2_version{ 
    out("AMAZON EC2 plugin version $EC2_VERSION\n");
}

sub ec2_checkCredentials {
    my $hostname = $_[0];
    my $root = $_[1];
    my $credfolder = getScalar("/host/$hostname/ec2/credential_folder",$root);
    if ( $credfolder ){
#	print "Credential folder found\n";
	$credfolder =~ s/\/$//;	
	$EC2_USER = "$credfolder/user.txt";
	$EC2_SECRET = "$credfolder/secret.txt";
        $EC2_ACCESS = "$credfolder/access.txt";
	$EC2_CERT = "$credfolder/cert.pem";
	$EC2_PRIVATE_KEY = "$credfolder/pk.pem";
#	print "credfolder: $credfolder\n";
	verbose("$PREFIX credfolder $credfolder\n");
	$S3_CERT = "$credfolder/cloud-cert.pem";
#	print "S3_CERT is now: $S3_CERT\n";
#	print "EC2_HOME is now " . $ENV{'EC2_HOME'} . "\n";
	if ( open(FILE,"$credfolder/$EC2_HOME_FILE") ){
#	    print "EC2_HOME was found";
	    $EC2_HOME = <FILE>;
	    chomp $EC2_HOME;
	    $ENV{'EC2_HOME'} = $EC2_HOME;
	    close(FILE);
#	    print "EC2_HOME is now " . $ENV{'EC2_HOME'} . "\n";
	}
#	if ( not $ENV{'PATH'} =~ /$EC2_HOME/ ){
#	    print "setting EC2_HOME to $EC2_HOME\n";
#	    if ( $ENV{'PATH'} =~ s/:\/[^:]+ec2-api-tools-[^:]+:/:$EC2_HOME\/bin:/ ){
#		print "Path is now: $ENV['PATH']\n";
#	    } else {
#		$ENV{'PATH'} .= ":$EC2_HOME\/bin:";
#	    }	    
#	}

#	if ( open(FILE,"$credfolder/$S3_HOME_FILE")){
#	    print "S3_HOME found\n";
#	    $S3_HOME = <FILE>;
#	    chomp $S3_HOME;
#	    $ENV{'EC2_AMITOOL_HOME'} = $S3_HOME;
#	    close(FILE);
#	}
#	print "S3_HOME is $S3_HOME\n";
#	if ( not $ENV{'PATH'} =~ /$S3_HOME/ ){
#	    print "setting S3_HOME to $S3_HOME\n";
#	    if ( $ENV{'PATH'} =~ s/:\/[^:]+ec2-ami-tools-[^:]+:/:$S3_HOME\/bin:/ ){
#		print "Path is now: $ENV['PATH']\n";
#	    } else {
#		$ENV{'PATH'} .= ":$S3_HOME\/bin:";
#	    }	    
#	}
	
#	system('echo PATH:$PATH');
#	if ( open(FILE,"$credfolder/$EC2_URL_FILE")){
#	    $EC2_URL = <FILE>;
#	    chomp $EC2_URL;
#	    $ENV{'EC2_URL'} = $EC2_URL;
#	    close(FILE);
#	}
#	if ( open(FILE,"$credfolder/$S3_URL_FILE")){
#	    $S3_URL = <FILE>;
#	    chomp $S3_URL;
#	    $ENV{'S3_URL'} = $S3_URL;
#	    close(FILE);
#	}
	if ( open(FILE,"$credfolder/$EUCA_HOME")){
	    my $url_base = <FILE>;
	    close(FILE);
	    chomp $url_base;
	    verbose("EUCALYPTUS: Enabled\n");
	    
	    $EUCALYPTUS = 1;
	    $PREFIX = "EUCA:";
	    $S3_URL = $url_base . ":8773/services/Walrus";
	    $EC2_URL = $url_base . ":8773/services/Eucalyptus";
	    verbose("$PREFIX S3_URL = $S3_URL\n");
	    verbose("$PREFIX EC2_URL = $EC2_URL\n");
	}
	
	if ( open(FILE,"$credfolder/$S3_CERT")){
	    $S3_CERT = <FILE>;
	      chomp $S3_CERT;
	    $ENV{'S3_CERT'} = $S3_CERT;
	    verbose("S3_CERT = $S3_CERT\n");
	    close(FILE);
	}

    }
    open(ECU,"$EC2_USER");
    $EC2_USERNAME = <ECU>;
    chomp $EC2_USERNAME;
    close(ECU);
#    <>;
}

sub ec2_createFilesystem {
    my $hostname = $_[0];
    my $ec2 = getScalar("/host/$hostname/ec2");
    if  ( $ec2 ){
	my $use = getScalar("/host/$hostname/ec2/use");
	my $ami = getScalar("/host/$hostname/ec2/ami");
	my $quick = getScalar("/host/$hostname/ec2/quickbuild");
	if ( ( $use and $use ne "$hostname") and $quick){
	    out("$PREFIX Quick build, start/stop scripts only\n");	    
	    return 1;
	} elsif ($ami) {
	    verbose("$PERFIX using AMI $ami\n");
	    return 1;
	} else {
	    return ;
	}
	
    }
    
}


sub ec2_configureEntireFilesystem {
    my $hostname = $_[0];
    my $ec2 = getScalar("/host/$hostname/ec2");
    if  ( $ec2 ){
	my $use = getScalar("/host/$hostname/ec2/use");
	my $quick = getScalar("/host/$hostname/ec2/quickbuild");
	my $ami = getScalar("/host/$hostname/ec2/ami");
	if ( ( $use and $use ne "$hostname") and $quick){
	    out("$PREFIX Quick build, start/stop scripts only\n");
	    ec2_createStartStopScripts($hostname);
	    $RESTART_ME{$key} = 1;
	    return 1;
	} elsif ( $ami ) {
#	    out("$PREFIX This Vm will use AMI $ami\n");
	    ec2_createStartStopScripts($hostname);
	    $RESTART_ME{$key} = 1;
	    return 1;
	} else {
	    return ;
	}
	
    }
    
}

sub ec2_configure {
    my $hostname = $_[0];
    my $ec2 = getScalar("/host/$hostname/ec2");
    if  ( $ec2 ){
	out("$PREFIX plugin enabled\n");
	my $use = getScalar("/host/$hostname/ec2/use");
	if ( $use and $use ne "$hostname" ){
	    out("$PREFIX This VM will use the filesystem of $use\n");

	    return;
	}
	
	out("$PREFIX Creating script /etc/init.d/mln_ec2_set_hostname\n");
	open(SCRIPT,">$MOUNTDIR/etc/init.d/mln_ec2_set_hostname");
	print SCRIPT "#!/bin/bash\n";
	print SCRIPT "echo 'MLN EC2 - Setting hostname'\n";
	print SCRIPT "hostname=\$( wget --timeout 15 -q -O - http://169.254.169.254/1.0/user-data |  sed 's/h=\\([a-z0-9_-]*\\);.*/\\1/g' )\n";
	print SCRIPT "if [ -n \"\$hostname\" ]; then\n";
	print SCRIPT "echo Setting hostname to \$hostname\n";
	print SCRIPT "hostname \$hostname\n";
	print SCRIPT "echo \$hostname > /etc/hostname\n";
	print SCRIPT "fi\n";
	close(SCRIPT);
	system("chmod +x $MOUNTDIR/etc/init.d/mln_ec2_set_hostname");
	system("ln -s /etc/init.d/mln_ec2_set_hostname $MOUNTDIR/etc/rcS.d/S41mln_ec2_set_hostname");
	
	my $type = getScalar("/host/$hostname/ec2/type");
	$type = $EC2_DEFAULT_TYPE unless $type;
	my $mount1 = getScalar("/host/$hostname/ec2/mount1");
	my $mount2 = getScalar("/host/$hostname/ec2/mount2");
	$mount1 = $EC2_DEFAULT_MOUNT1 unless $mount1;
	my @volumes = getArray("/host/$hostname/ec2/volumes");
	if ( not stat("$MOUNTDIR/$mount1")){
	    system("mkdir -p $MOUNTDIR/$mount1");
	}
	if ( $type eq "c1.xlarge" or $type eq "m1.large" or $type eq "m1.xlarge") {
	    $mount2 = $EC2_DEFAULT_MOUNT2 unless $mount2;
	    if ( not stat("$MOUNTDIR/$mount2")){
		system("mkdir -p $MOUNTDIR/$mount2");
	    }	    
	}

	open(FSTAB,">$MOUNTDIR/etc/fstab");
	print FSTAB "/dev/sda1 /     ext3  defaults             1 1\n";
	print FSTAB "none            /dev/pts      devpts    defaults        0   0\n";
	if ( $type eq "c1.xlarge" or $type eq "m1.large" or $type eq "m1.xlarge") {
	    print FSTAB "/dev/sdb $mount1  ext3  defaults,user_xattr  0 0\n";
	    print FSTAB "/dev/sdc $mount2  ext3  defaults,user_xattr  0 0\n";
	} else {
	    print FSTAB "/dev/sda2 $mount1  ext3  defaults,user_xattr  0 0\n";
	    print FSTAB "/dev/sda3 swap  swap  defaults             0 0\n";	    
	}
	if ( @volumes ){
	    open(SCRIPT,">$MOUNTDIR/etc/init.d/mln_ec2_mount_volumes") or out("Failed to open file: $!\n");
	    print SCRIPT "#!/bin/bash\n";
	    print SCRIPT "echo Starting wait loop to mount volumes\n";
	}
	foreach my $volume ( @volumes ) {
	    if ( $volume =~ /^vol-.*|^(\d+)|^persistent_(\d+)/ ){
		my ( $vol, $disk, $mpoint, $fs, $opts ) = split /\s+/, $volume;
		print "disk: $disk, mpoint: $mpoint\n";
		if ( not $disk =~ /\/dev\// ){
		    $disk = "/dev/$disk";
		}
		$fs = "ext3" unless $fs;
		if ( not stat("$MOUNTDIR/$mpoint") ){
		    system("mkdir -p $MOUNTDIR/$mpoint");

		}
		print FSTAB "# volume $volume\n";
		$opts = ",$opts" if $opts;
		print FSTAB "$disk $mpoint $fs defaults,user_xattr$opts  0 0\n";
		print SCRIPT "echo 'Volume $vol on $disk...'\n";
		if ( $vol =~ /vol-.*/ ){
		    print SCRIPT "while ! mount -o $opts $disk $mpoint; do sleep 3; done\n";
		} else {
		    print SCRIPT "while ! mount -o $opts -t $fs $disk $mpoint ; do if mount -t $fs $disk $mpoint 2>&1 | grep \"wrong fs type\" ; then mkfs.$fs $disk; fi ; sleep 3; done ";
		}
	    } 
	}
	close(SCRIPT);
	if ( @volumes ){
	    system("chmod +x $MOUNTDIR/etc/init.d/mln_ec2_mount_volumes");
	    system("ln -s /etc/init.d/mln_ec2_mount_volumes $MOUNTDIR/etc/rcS.d/S37mln_ec2_mount_volumes");
	}
	print FSTAB "none      /proc proc  defaults             0 0\n";
	print FSTAB "none      /sys  sysfs defaults             0 0\n";
	close(FSTAB);
	    
	if ( not stat("$PROJECT_PATH/$PROJECT/ec2")){
	    system("mkdir -p $PROJECT_PATH/$PROJECT/ec2");
	}
	my $arch = getScalar("/host/$hostname/ec2/arch");
	$arch = $EC2_DEFAULT_ARCH unless $arch;
	# if ( ( $type eq "c1.medium" or $type eq "m1.small") and $arch eq "x86_64" ){
	#     out("$PREFIX WARNING: VM type will be 32bit but x86_64 is chosen\n");
	# } elsif ( ( $type eq "c1.xlarge" or $type eq "m1.large" or $type eq "m1.xlarge") and $arch eq "i386" ){
	#     out("$PREFIX Setting arch to x86_64 because 64bit VM type $type was chosen\n");
	#     $arch = "x86_64";
	# }


	if ( $arch eq "i386" ){
	    	out("$PREFIX copying modules from $EC2_MODULES_i386\n");
	    system("cp -r $EC2_MODULES_i386 $MOUNTDIR/lib/modules");
	} elsif ( $arch eq "x86_64" ){
	    out("$PREFIX copying modules from $EC2_MODULES_x86_64\n");
	    system("cp -r $EC2_MODULES_x86_64 $MOUNTDIR/lib/modules");
	} else {
	    out("$PREFIX WARNING: Did not understand $arch. Allowed: [ i386, x86_64 ]\n");
	}
    }    
}

sub ec2_checkIfUp {
    my $hostname = $_[0];
    my $project = $_[1];
    my $root = $_[2];
    if ( getScalar("/host/$hostname/ec2",$root)){
	if ( not stat("$PROJECT_PATH/$project/ec2/${hostname}.instance") ){
	    return "-1";
	}
	ec2_checkCredentials($hostname,$root);
	my $access = `cat $EC2_ACCESS`;
	chomp $access;
	my $secret = `cat $EC2_SECRET`;
	chomp $secret;
	
	my @regions = `ls $PROJECT_PATH/$project/ec2/*.region`;
	my $statuscommand = "";
	foreach my $reg ( @regions ){
	    chomp $reg;
	    open(FILE,"$reg");
	    my $r = <FILE>;
	    close(FILE);
	    $statuscommand .= "ec2-describe-instances -K $EC2_PRIVATE_KEY -C $EC2_CERT --region $r ; ";
	}
	  
	
	
	open(FILE,"$PROJECT_PATH/$project/ec2/${hostname}.region");
	
	
	if ( not @EC2_INSTANCE_CACHE ){
	    verbose("$PREFIX updating instance information cache\n");
	    if ( not $EC2_URL =~ /amazonaws\.com/ ){
		@EC2_INSTANCE_CACHE = `euca-describe-instances -a $access -s $secret --url $EC2_URL`;
	    } else {
		@EC2_INSTANCE_CACHE = `$statuscommand`;
	    }
	} else {
	    verbose("$PREFIX using instance information cache\n");
	}
	my $id;
	open(FILE,"$PROJECT_PATH/$project/ec2/${hostname}.instance");
	$id = <FILE>;
	chomp($id);
#	print "id: '$id'\n";
	close(FILE);
	foreach my $line (@EC2_INSTANCE_CACHE ){
	    chomp($line);
#	    print "line: '$line'\n";
	    my @array = split /\s+/,$line; 
#	    if ( $line =~ /INSTANCE\s+$id\s+(ami-*.)\s+(.*)\s+(\S+)/ ){
#	    if ( $line =~ /INSTANCE\s+$id/ ){
	    if ( $array[0] eq "INSTANCE" and $array[1] eq $id ){
#		print "instance found: '$array[5]'\n";
		if ( $array[5] =~ /running/ or $array[5] =~ /pending/ or $array[5] =~ /shutting-down/  ){		    
#		    print "match\n";
		    return "1 $array[1] $array[3]";		    
		} else {
		    return "0";
		}
	    } 
	}
	
    }
}

sub ec2_runEC2 {
    my $command = $_[0];
    verbose("$PREFIX Running command: $command\n");
    open(COM,"$command 2>&1 |");
    while( my $line = <COM> ){
	chomp $line;
	out("$PREFIX $line\n");
    }
    close(COM);
}

sub ec2_removeHost {
    
    my $hostname = $_[0];
    my $project = $_[1];
    my $root = $_[2];
    $root = $DATA_ROOT unless $root;
    if ( getScalar("/host/$hostname/ec2",$root) ){
	ec2_checkCredentials($hostname);
	my $use = getScalar("/host/$hostname/ec2/use",$root);
	my $ami = getScalar("/host/$hostname/ec2/ami",$root);
	my $noterm = getScalar("/host/$hostname/ec2/no_terminate");
	my $type = getScalar("/host/$hostname/ec2/type");
	my $region = getScalar("/host/$hostname/ec2/region");
	$region = $EC2_DEFAULT_REGION unless $region;
	$type = $EC2_DEFAULT_TYPE unless $type;
	$noterm = 1 if $EC2_DEFAULT_ALWAYS_NOTERM_FOR_TINY and $type eq "t1.micro";

	if ( $noterm ){
	    out("$PREFIX We need to terminate the host completely first\n");
	    open(FILE,"$PROJECT_PATH/$project/ec2/${hostname}.instance");
	    my $instance = <FILE>;
	    chomp $instance;
	    close(FILE);
	    if ( $instance ){
		ec2_runEC2("ec2-terminate-instances -C $EC2_CERT -K $EC2_PRIVATE_KEY --region $region $instance");
	    } else {
		out("$PREFIX No instance information found\n");
	    }
	}
	
	my $imageID;
	if ( ( $use and $use ne "$hostname" ) or $ami ){
	    if ( $use ){
		out("$PREFIX This VM uses the filesystem of $use\n");
	    } else {
#		out("$PREFIX No need to delete, an AMI is used\n");
	    }
	    my @volumes = getArray("/host/$hostname/ec2/volumes",$root);
	    foreach my $volume ( @volumes ){
		my ( $vol, $disk, $mpoint, $fs) = split /\s+/, $volume;
		if ( $vol =~ /^(\d+)/ ){
		    my $volid = `cat $PROJECT_PATH/$project/ec2/$hostname.$disk`;
		    
		    chomp $volid;		    
		    out("$PREFIX deleting volume: $volid\n");
		    my $result = ec2_runEC2("ec2-delete-volume $volid");
		    print "result: $result";
		    my $instanceID;
		    if ( $result =~ /in-use/ ){
			$instanceID = `ec2-describe-volumes $volidn | grep "ATTACHMENT.*$volid"`;
			$instanceID =~ s/^.*(i-([a-z0-9]+))\s.*$/$1/g;
			chomp $instanceID;
			verbose("$volid is attached to '$instanceID'\n");
		    
			while ( $result =~ /in-use/  ){
			
			# attempt to dedatch first: 
			
			    ec2_runEC2("ec2-detach-volume $volid -i $instanceID -d $disk");
			    sleep 2;
			    $result = `ec2-delete-volume $volid 2>&1`;
			    verbose($result);
			}
		    }
		}
	    }
#
	} else {
	    my $region = getScalar("/host/$hostname/ec2/region",$root);
	    $region = $EC2_DEFAULT_REGION unless $region;

	    open(FILE,"$PROJECT_PATH/$project/ec2/${hostname}.image");
	    my $ami = <FILE>;
	    close(FILE);
	    my $access = `cat $EC2_ACCESS`;
	    chomp $access;
	    my $secret = `cat $EC2_SECRET`;
	    chomp $secret;
	    open(FILE,"$PROJECT_PATH/$project/ec2/${hostname}.region");
	    my $reg = <FILE>;
	    close(FILE);
	    my $bucket = getScalar("/host/$hostname/ec2/bucket");
	    $bucket = $EC2_DEFAULT_BUCKET unless $bucket;
	    $bucket = "mln".lc($region).$EC2_USERNAME unless $bucket;

	    if ( $ami ){
		if ( not $EC2_URL =~ /amazonaws\.com/ ){
		    ec2_runEC2("euca-deregister -a $access -s $secret --url ${EC2_URL} $ami");
		} else {
		    ec2_runEC2("ec2-deregister -C $EC2_CERT -K $EC2_PRIVATE_KEY --region $reg $ami");
		}
	    }
	    
	    my $command = "ec2-delete-bundle  --bucket $bucket --manifest $PROJECT_PATH/$project/ec2/${hostname}_$project.manifest.xml -y --access-key $access --secret-key $secret --url ${S3_URL}";
	    if ( not $EC2_URL =~ /amazonaws\.com/ ){
		$command = "euca-delete-bundle --clear  --bucket $hostname$project --manifest $PROJECT_PATH/$project/ec2/${hostname}.manifest.xml --access-key $access --secret-key $secret --url ${S3_URL}";
	    }
#	    verbose("$command \n");
	    ec2_runEC2("$command");
	    
	    my @volumes = getArray("/host/$hostname/ec2/volumes",$root);
	    foreach my $volume ( @volumes ){
		my ( $vol, $disk, $mpoint, $fs) = split /\s+/, $volume;
		if ( $vol =~ /^(\d+)/ ){
		    my $volid = `cat $PROJECT_PATH/$project/ec2/$hostname.$disk`;
		    chomp $volid;		    
		    out("$PREFIX deleting volume: $volid\n");
		    my $command = "ec2-delete-volume $volid";
		    if ( not $EC2_URL =~ /amazonaws\.com/ ){
			$command =  "euca-delete-volume -a $access -s $secret --url ${EC2_URL} $volid";
		    }
		    ec2_runEC2("$command");
		}
	    }
#	    system("ec2-delete-bundle -y mln/${hostname}_$project.manifest.xml");
	}
    }
}

sub ec2_createStartStopScripts {
    my $hostname = $_[0];
    my $ec2 = getScalar("/host/$hostname/ec2");
    ec2_checkCredentials($hostname);
    if  ( $ec2 ){
	my $use = getScalar("/host/$hostname/ec2/use");
	my $imageID;
	my $type = getScalar("/host/$hostname/ec2/type");
	my $ami = getScalar("/host/$hostname/ec2/ami");
	my $key = getScalar("/host/$hostname/ec2/key");
	my $noterm = getScalar("/host/$hostname/ec2/no_terminate");
	$type = $EC2_DEFAULT_TYPE unless $type;
	$noterm = 1 if $EC2_DEFAULT_ALWAYS_NOTERM_FOR_TINY and $type eq "t1.micro";
	my $ec2_user = `cat $EC2_USER`;
	chomp $ec2_user;
	my $ec2_access = `cat $EC2_ACCESS`;
	chomp $ec2_access;
	my $ec2_secret = `cat $EC2_SECRET`;
	chomp $ec2_secret;
	if( not stat("$PROJECT_PATH/$PROJECT/ec2/")){
	    mkdir "$PROJECT_PATH/$PROJECT/ec2/";
	}
	if ( not $ami ){
	    
	    if ( $use and $use ne "$hostname" ){
		out("$PREFIX This VM will use the filesystem of $use\n");
		open(FILE,">$PROJECT_PATH/$PROJECT/ec2/$hostname.image");
		print FILE "ref:$use\n";	    
		close(FILE);
		
	    } else {
		
	    
		out("$PREFIX creating bundle from image\n");
		# ec2-bundle-image -p etch-ec2 -i /home/kyrre/etch-ec2.ext3 -u 1185-7570-8841 --cert .amazon/cert.pem --privatekey .amazon/pk.pem
		my $region = getScalar("/host/$hostname/ec2/region");
		$region = $EC2_DEFAULT_REGION unless $region;
		
		my $bucket = getScalar("/host/$hostname/ec2/bucket");
		$bucket = $EC2_DEFAULT_BUCKET unless $bucket;
		$bucket = "mln".lc($region).$EC2_USERNAME unless $bucket;
		
		
		my $arch = getScalar("/host/$hostname/ec2/arch");
		$arch = $EC2_DEFAULT_ARCH unless $arch;
		# if ( ( $type eq "c1.medium" or $type eq "m1.small") and $arch eq "x86_64" ){
		# 	out("$PREFIX WARNING: VM type will be 32bit but x86_64 is chosen");
		# } elsif ( ( $type eq "c1.xlarge" or $type eq "m1.large" or $type eq "m1.xlarge") and $arch eq "i386" ){
		# 	out("$PREFIX Setting arch to x86_64 because 64bit VM type $type was chosen\n");
		# 	$arch = "x86_64";
		# }
		my @filesystems = getFilesystems($hostname,$PROJECT);
		my $filesystem = $filesystems[0];
		my $bundlecommand = "ec2-bundle-image  --arch $arch -p ${hostname}_$PROJECT -d $PROJECT_PATH/$PROJECT/ec2 -i $filesystem --batch -u $ec2_user -B 'ami=sda1,root=/dev/sda1' --cert $EC2_CERT --privatekey $EC2_PRIVATE_KEY ";
		my $uploadcommand = "ec2-upload-bundle -m $PROJECT_PATH/$PROJECT/ec2/${hostname}_$PROJECT.manifest.xml --location $region --bucket $bucket -a $ec2_access -s $ec2_secret";
		if ( not $EC2_URL =~ /amazonaws\.com/ ){
		    verbose("Assuming Eucalyptus, and not amazon\n");
		    $bundlecommand = "euca-bundle-image --cert ${EC2_CERT} --privatekey ${EC2_PRIVATE_KEY} --user $ec2_user --ec2cert ${S3_CERT} -d $PROJECT_PATH/$PROJECT/ec2 -i $filesystem ";
		    $uploadcommand = "euca-upload-bundle -m $PROJECT_PATH/$PROJECT/ec2/${hostname}.manifest.xml --bucket ${hostname}$PROJECT  -a $ec2_access -s $ec2_secret --url ${S3_URL} --ec2cert ${S3_CERT} ";
		}
		ec2_runEC2("$bundlecommand");
		# ec2-upload-bundle -m /tmp/etch-ec2.manifest.xml --bucket mln -a 191291KEGKHBQ2A5VA02 -s Ul66zrGeU2fCx9X7HP9NkI+CrMN7gazMDsPKW5OJ 
		out("$PREFIX uploading image\n");
#	    system('echo "ami-home: $EC2_AMITOOL_HOME"');
#	    system("which ec2-upload-bundle");
#	    system("ec2-upload-bundle --version");
#	    print "ec2-upload-bundle -m $PROJECT_PATH/$PROJECT/ec2/${hostname}_$PROJECT.manifest.xml --location $region --bucket mln -a $ec2_access -s $ec2_secret \n";
		my $start = time;
		
#	    verbose("$command \n");
		ec2_runEC2("$uploadcommand");
		my $diff = time - $start;
	    # ec2-register mln/etch-ec2.manifest.xml
		my $size;
		if ( not $EC2_URL =~ /amazonaws\.com/ ){
		    $size = `du -cm $PROJECT_PATH/$PROJECT/ec2/${hostname}.part* | grep total`;
		} else {
		    $size = `du -cm $PROJECT_PATH/$PROJECT/ec2/${hostname}_$PROJECT.part* | grep total`;
		}
		chomp($size);
		$size =~ s/^(\d+)\s+total/$1/;
		my $timediff;
		if ( $diff < 60 ){
		    $timediff = int( $size / int( $diff )) . " MB/seconds";
		} else {
		    $timediff = int( $size / int( $diff / 60 )) . " MB/minute ";
		}
		out("$PREFIX Transferred: ${size}MB in $diff seconds (" . $timediff . " )\n");
		out("$PREFIX registering\n");
		my $reg = "us-east-1" if $region eq "US";
		$reg = "eu-west-1" if $region eq "EU";
		my $regcom = "ec2-register -C $EC2_CERT -K $EC2_PRIVATE_KEY --region $reg $bucket/${hostname}_$PROJECT.manifest.xml";
		if ( not $EC2_URL =~ /amazonaws\.com/ ){
		    #  --cert ${EC2_CERT} --privatekey ${EC2_PRIVATE_KEY}
		    $regcom = "euca-register  -a $ec2_access -s $ec2_secret --url $EC2_URL   ${hostname}$PROJECT/${hostname}.manifest.xml ";
		}
		verbose("$PREFIX running: $regcom\n");
		my $result = `$regcom`;
		verbose("$result");
#	print "result: $result\n";
		chomp($result);
		if ( $result =~ /((e|a)mi-.*)/g  ){
		    out("$PREFIX image ID: $1\n");
		    open(FILE,">$PROJECT_PATH/$PROJECT/ec2/$hostname.image");
		    print FILE "$1\n";	    
		    close(FILE);
		    $imageID = $1;
		    out("$PREFIX deleting bundle temporary files\n");
		    if ( not $EC2_URL =~ /amazonaws\.com/ ){
			system("rm $PROJECT_PATH/$PROJECT/ec2/${hostname}.part*");		    
		    } else {
			system("rm $PROJECT_PATH/$PROJECT/ec2/${hostname}_$PROJECT.part*");		    
		    }
		} else {
		    out("$PREFIX warning, did not get image ID!\n");
		}	    
	    }
	} else {
	    out("$PREFIX: AMI for this VM is $ami\n");
	    open(FILE,">$PROJECT_PATH/$PROJECT/ec2/$hostname.image");
	    print FILE "$ami\n";	    
	    close(FILE);	    
	}
	out("$PREFIX writing start/stop scripts\n");	
	my @volumes = getArray("/host/$hostname/ec2/volumes");
	my $bo = getScalar("/host/$hostname/boot_order");
	$bo = 99 unless $bo;
	my $region = getScalar("/host/$hostname/ec2/region");

	$region = $EC2_DEFAULT_REGION unless $region;
	verbose("$PREFIX region is $region\n");
	my $reg = "us-east-1" if $region eq "US";
	$reg = "eu-west-1" if $region eq "EU";
	my $elasticIP = getScalar("/host/$hostname/ec2/elastic_ip");
	
	open (REG,">$PROJECT_PATH/$PROJECT/ec2/$hostname.region");
	print REG "$region";
	close(REG);
	
	open(START,">$PROJECT_PATH/$PROJECT/start_${bo}_$hostname.sh");
	print START "#!/bin/bash\n";

	

	print START "instance='';\n";
	print START "if [ -f $PROJECT_PATH/$PROJECT/ec2/$hostname.instance ]; then\n";


	print START "instance=\$(cat $PROJECT_PATH/$PROJECT/ec2/$hostname.instance )\n";
	my $line = "result=\$(ec2-describe-instances -C $EC2_CERT -K $EC2_PRIVATE_KEY --region $region  \$instance)\n";
	if ( not $EC2_URL =~ /amazonaws\.com/ ){
		$line = "result=\$(euca-describe-instances -a $ec2_access -s $ec2_secret --url $EC2_URL \$instance)\n";
	}
	print START $line;
	print START "running=\$( echo \$result | grep \"running\")\n";
	print START "pending=\$( echo \$result | grep \"pending\")\n";
	print START "stopped=\$( echo \$result | grep \"stopped\")\n";
	print START "if [ -n \"\$running\" ]; then \n";
	print START "echo \"Instance already running\"\n";
	print START "exit 1\n";
	print START "elif [ -n \"\$pending\" ]; then\n";
	print START "echo \"Instance still on pending, will run soon\"\n";
	print START "exit 1\n";
	print START "elif [ -n \"\$stopped\" ]; then\n";
	print START "echo \"Instance exists and is stopped. Starting...\"\n";
	print START "ec2-start-instances -C $EC2_CERT -K $EC2_PRIVATE_KEY --region $region \$instance\n";
	print START "exit 0\n";
	print START "fi\n";	     
	print START "fi\n";
	my $userData = getScalar("/host/$hostname/ec2/user_data"); 
	my @userFileArray = getArray("/host/$hostname/ec2/user_file"); 
	my $userFile;
	if ( $use and $use ne "$hostname" ){
	    $userData = "h=$hostname;$userData";
	}
	if ( $userData ){
	    $userData = "-d '$userData'";
	}
	if ( @userFileArray ){
	    
	    open(USERF,">$PROJECT_PATH/$PROJECT/ec2/userfile.$hostname");
	    print USERF "#!/bin/bash\n";
	    foreach my $line (@userFileArray ){
		print USERF $line ."\n";
		out("$PREFIX - userfile - $line\n");
	    }
	    close(USERF);
	    $userFile = "-f '$PROJECT_PATH/$PROJECT/ec2/userfile.$hostname'";	    
	}
	
	if ( $use and $use ne "$hostname" ){
	    print START "imageID=\$( cat $PROJECT_PATH/$PROJECT/ec2/$use.image | cut -d: -f 2 )\n";
	} elsif ($ami ){
	    print START "imageID=\$( cat $PROJECT_PATH/$PROJECT/ec2/$hostname.image )\n";
	} else {
	    print START "imageID=$imageID\n";	    
	}
	my $key = "-k $key" if $key;
	my $zone = getScalar("/host/$hostname/ec2/zone");
	if ( not $zone and not $EC2_URL =~ /amazonaws\.com/ ){
	    my $eucazone = `euca-describe-availability-zones -a $ec2_access -s $ec2_secret --url $EC2_URL`;
	    verbose("$PREFIX availability zones: $eucazones\n");
	    $eucazone =~ /.*ZONE(\s+)(\S+)(\s+)UP/;
	    $eucazone = $2;
	    verbose("$PREFIX Final zone: $eucazone\n");
	    $zone = $eucazone;
	}
	foreach my $volume ( @volumes ) {
	    if ( $volume =~ /vol-.*/ and $EC2_URL =~ /amazonaws\.com/ ){
		my ( $vol, $disk, $mpoint, $fs) = split /\s+/, $volume;
		my @result = split /\s+/,`ec2-describe-volumes --region $reg $vol`;
		# VOLUME  vol-b24bafdb    30              us-east-1b      available       2009-02-15T19:23:31+0000
		print "zone: $result[3]\n";
		if ( $zone and $zone ne $result[3] ){
		    out("$PREFIX WARNING: two volumes with different availability zones! Only the last one will work!");
		}
		$zone = "-z $result[3]";
	    } 
	}
		
	my $old_zone = $zone;
	$old_zone = $EC2_DEFAULT_AVAILABILITY_ZONE unless $old_zone;
	$zone = "-z $EC2_DEFAULT_AVAILABILITY_ZONE" if ( $EC2_DEFAULT_AVAILABILITY_ZONE and not $zone );
#	$zone = "-z $zone" unless $zone =~ /-z /;
	my $kernel;
	$kernel = "--kernel $EC2_DEFAULT_KERNEL" if $EC2_DEFAULT_KERNEL;
	if ( not $EC2_URL =~ /amazonaws\.com/ ){	
	    print START "echo -n 'Starting $hostname in Eucalyptus cloud $old_zone: '\n";
	} else {
	    print START "echo -n 'Starting $hostname in EC2 cloud (region $region) '\n";
	}
	
	
	if ( not $EC2_URL =~ /amazonaws\.com/ ){
	    print START "result=\$(euca-run-instances -a $ec2_access -s $ec2_secret  $userData $userFile  -g default --url $EC2_URL  -t $type $key \$imageID);\n";
	} else {
	    print START "result=\$(ec2-run-instances --cert $EC2_CERT -K $EC2_PRIVATE_KEY $userData $userFile --region $region -g default $zone $kernel -t $type $key \$imageID);\n";
	}
	print START "instance=\$(echo \$result | grep 'INSTANCE i-' | cut -d ' ' -f 6);\n";
	print START "if test -n \"\$instance\"; then\n";
	print START "echo \"OK: \$instance\"\n";
	print START "ec2-create-tags -K $EC2_PRIVATE_KEY --cert $EC2_CERT --region $region \$instance -t Name=$PROJECT.$hostname\n";
	print START "echo \$instance > $PROJECT_PATH/$PROJECT/ec2/$hostname.instance\n";
	if ( $elasticIP ){
	    if ( not $EC2_URL =~ /amazonaws\.com/ ){
		print START "euca-associate-address -a $ec2_access -s $ec2_secret --url $EC2_URL $elasticIP -i \$instance\n";		
	    } else {
		print START "ec2-associate-address -K $EC2_PRIVATE_KEY --cert $EC2_CERT --region $region  $elasticIP -i \$instance\n";
	    }

	}
	foreach my $volume ( @volumes ) {
#	    print START "echo Sleeping 10 seconds before attaching volume\n";
#	    print START "sleep 10\n";
	    my ( $vol, $disk, $mpoint, $fs) = split /\s+/, $volume;
	    if ( $vol =~ /vol-.*/ ){
		if ( not $EC2_URL =~ /amazonaws\.com/ ){
		    print START "while true; do sleep 5; if euca-attach-volume -a $ec2_access -s $ec2_secret --url $EC2_URL $vol -i \$instance -d $disk 2>/dev/null 1>/dev/null; then exit 0; fi ; done &\n";
		} else {
		    print START "while true; do sleep 5; if ec2-attach-volume -K $EC2_PRIVATE_KEY --cert $EC2_CERT --region $region $vol -i \$instance -d $disk 2>/dev/null 1>/dev/null; then exit 0; fi ; done &\n";
		}
	    } 	elsif ( $volume =~ /^(\d+)G|^persistent_(\d+)/ ){
		my $size = $1;
		if ( not $UPGRADE ){
		    out("$PREFIX Creating volume of size ${size}G\n");
		    my $result;
		    if ( not $EC2_URL =~ /amazonaws\.com/ ){
			$command = "euca-create-volume $zone --url $EC2_URL -a $ec2_access -s $ec2_secret -S $size";
		    } else {
			$command = "ec2-create-volume --region $reg $zone -s $size";
		    }
		    my $result = `$command`;
		    verbose("$PREFIX running command: $command");
		    verbose($result);
		    # VOLUME  vol-780dec11    2               us-east-1a      creating
#		print "result: $result";
		    if ( $result =~ /VOLUME\s+(vol-\S+)\s+($size)\s+(\S+)\s+(\S+)/ ){
			my $vol = $1;
			out("$PREFIX Volume $1 created\n");
			if ( not $EC2_URL =~ /amazonaws\.com/ ){
			    print START "while true; do sleep 5; if euca-attach-volume -a $ec2_access -s $ec2_secret --url $EC2_URL $vol -i \$instance -d $disk 2>/dev/null 1>/dev/null; then exit 0; fi ; done &\n";
			} else {
			    print START "while true; do sleep 5; if ec2-attach-volume -K $EC2_PRIVATE_KEY --cert $EC2_CERT --region $reg $vol -i \$instance -d $disk 2>/dev/null 1>/dev/null; then exit 0; fi ; done &\n";
			}
			my $vfile = "$PROJECT_PATH/$PROJECT/ec2/$hostname.$disk";
			if ( $volume =~ /^persistent/ ){
			    $vfile = $vfile . ".persistent";
			} 
			print "saving to $vfile\n";
			open(VF,">$vfile") or warn "$vfile: $!\n";
			print VF "$vol\n";
			close(VF);
		    }
		} else {
		    my $vfile = "$PROJECT_PATH/$PROJECT/ec2/$hostname.$disk";
		    if ( $volume =~ /^persistent/ ){
			$vfile = $vfile . ".persistent";
		    } 

		    $volid = `cat $vfile`;
		    chomp $volid;
		    if ( not $EC2_URL =~ /amazonaws\.com/ ){
			print START "while true; do sleep 5; if euca-attach-volume -a $ec2_access -s $ec2_secret --url $EC2_URL $reg $vol -i \$instance -d $disk 2>/dev/null 1>/dev/null; then exit 0; fi ; done &\n";			
		    } else {
			print START "while true; do sleep 5; if ec2-attach-volume -K $EC2_PRIVATE_KEY --cert $EC2_CERT --region $region $vol -i \$instance -d $disk 2>/dev/null 1>/dev/null; then exit 0; fi ; done &\n";
		    }
		}
	    }
 
	} 
	if ( @volumes ){
#	    system("echo 'mount -a' >> 
	}
	print START "fi\n";	
	print START "if test -z \"\$instance\"; then\n";
	print START "echo \"fail: \$result\"\n";	
	print START "fi\n";
	close START;
	system("chmod 755 $PROJECT_PATH/$PROJECT/start_${bo}_$hostname.sh");	
	open(STOP,">$PROJECT_PATH/$PROJECT/stop_${bo}_$hostname.sh");
	print STOP "#!/bin/bash\n";
	print STOP "if [ -f $PROJECT_PATH/$PROJECT/ec2/$hostname.instance ]; then\n";	
	if ( $noterm ){
	    print STOP "instance=\$(cat $PROJECT_PATH/$PROJECT/ec2/$hostname.instance )\n";
	    my $line = "result=\$(ec2-describe-instances -C $EC2_CERT -K $EC2_PRIVATE_KEY --region $region \$instance)\n";
	    if ( not $EC2_URL =~ /amazonaws\.com/ ){
		$line = "result=\$(euca-describe-instances -a $ec2_access -s $ec2_secret --url $EC2_URL \$instance)\n";
	    }
	    print STOP $line;
	    print STOP "stopped=\$( echo \$result | grep \"stopped\")\n";
	    print STOP "if [ -n \"\$stopped\" ]; then\n";
	    print STOP "echo \"Instance exists but has stopped. No need to stop twice.\"\n";
	    print STOP "exit 1\n";
	    print STOP "fi\n";	     
	}
	if ( not $EC2_URL =~ /amazonaws\.com/ ){
	    print STOP "echo 'Terminating $hostname in Eucalyptus cloud'\n";
	    print STOP "if euca-terminate-instances -a $ec2_access -s $ec2_secret --region \$(cat $PROJECT_PATH/$PROJECT/ec2/$hostname.instance); then \n";
	    print STOP "rm $PROJECT_PATH/$PROJECT/ec2/$hostname.instance\n";
	} else {
	    if ( $noterm ){
		print STOP "echo 'Stopping $hostname in Amazon cloud'\n";
		print STOP "ec2-stop-instances -K $EC2_PRIVATE_KEY --cert $EC2_CERT --region $region \$(cat $PROJECT_PATH/$PROJECT/ec2/$hostname.instance);\n";
	    } else {
		print STOP "echo 'Terminating $hostname in Amazon cloud'\n";
		print STOP "if ec2-terminate-instances -K $EC2_PRIVATE_KEY --cert $EC2_CERT --region $region \$(cat $PROJECT_PATH/$PROJECT/ec2/$hostname.instance); then \n";
		print STOP "rm $PROJECT_PATH/$PROJECT/ec2/$hostname.instance\n";
		print STOP "\nfi\n";
	    }
	}
	
	print STOP "else\n";
	print STOP "echo \"$hostname seems to be off already\"\n";
	print STOP "fi\n";
	close(STOP);
	system("chmod 755 $PROJECT_PATH/$PROJECT/stop_${bo}_$hostname.sh");	
    } elsif ( $OLD_DATA_ROOT ){
    # if we just migrate "back" from EC2, we can delete the image fram 
    # the bucket
	print "We are in upgrade mode\n";

	my $ec2 = getScalar("/host/$hostname/ec2",$OLD_DATA_ROOT);
	if ( $ec2 ){
	    out("$PREFIX Removing old image from EC2\n");
	    my $use = getScalar("/host/$hostname/ec2/use",$OLD_DATA_ROOT);
	    my $imageID;
	    if ( $use and $use ne "$hostname" ){
		out("$PREFIX This VM uses the filesystem of $use, skipping\n");
		
	    } else {
		my $project = $PROJECT;
		open(FILE,"$PROJECT_PATH/$project/ec2/${hostname}.image");
		my $ami = <FILE>;
		close(FILE);
		my $access = `cat $EC2_ACCESS`;
		chmod $access;
		my $secret = `cat $EC2_SECRET`;
		chomp $secret;
	    if ( $ami ){
		if ( not $EC2_URL =~ /amazonaws\.com/ ){
		    ec2_runEC2("euca-deregister -a $ec2_access -s $ec2_secret --url $EC2_URL $ami");
		} else {
		    ec2_runEC2("ec2-deregister -K $EC2_PRIVATE_KEY --cert $EC2_CERT --region $ami");
		}
	    }
#		verbose(" ec2-delete-bundle --cert $EC2_CERT --bucket mln --manifest $PROJECT_PATH/$project/ec2/${hostname}_$project.manifest.xml -y --acces-key $access --secret-key $secret\n");
		if ( not $EC2_URL =~ /amazonaws\.com/ ){
		    ec2_runEC2(" ec2-delete-bundle --cert $EC2_CERT --bucket mln --manifest $PROJECT_PATH/$project/ec2/${hostname}_$project.manifest.xml -y --acces-key $access --secret-key $secret");
		} else {
		    ec2_runEC2(" euca-delete-bundle --cert $EC2_CERT --bucket mln --manifest $PROJECT_PATH/$project/ec2/${hostname}.manifest.xml --acces-key $access --secret-key $secret");
		}
#	    system("ec2-delete-bundle -y mln/${hostname}_$project.manifest.xml");
	    }

	}


    }
    
}

1;