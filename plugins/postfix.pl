# postfix MLN plugin written by Kyrre Begnum

my $POSTFIXVERSION = 0.5;
sub postfix_version {
    print "Postfix plugin version $POSTFIXVERSION\n";
}


sub postfix_configure {
    $hostname = $_[0];
    
    if ( getScalar("/host/$hostname/postfix") ){ 
	$relayhost = getScalar("/host/$hostname/postfix/relayhost");
	open(MAIN,">$MOUNTDIR/etc/postfix/main.cf");
	print MAIN "# Debian specific:  Specifying a file name will cause the first\n";
	print MAIN "# line of that file to be used as the name.  The Debian default\n";
	print MAIN "# is /etc/mailname.\n";
	print MAIN "#myorigin = /etc/mailname\n";
	
	print MAIN "smtpd_banner =  ESMTP \$mail_name (Ubuntu)\n";

	print MAIN "biff = no\n";

	print MAIN "# appending .domain is the MUA's job.\n";
	print MAIN "append_dot_mydomain = no\n";
	
	print MAIN "# Uncomment the next line to generate delayed mail warnings\n";
	print MAIN "#delay_warning_time = 4h\n";

	print MAIN "readme_directory = no\n";

	print MAIN "# TLS parameters\n";
	print MAIN "smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem\n";
	print MAIN "smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key\n";
	print MAIN "smtpd_use_tls=yes\n";
	print MAIN "smtpd_tls_session_cache_database = btree:/smtpd_scache\n";
	print MAIN "smtp_tls_session_cache_database = btree:/smtp_scache\n";
	
	print MAIN "# See /usr/share/doc/postfix/TLS_README.gz in the postfix-doc package for\n";
	print MAIN "# information on enabling SSL in the smtp client.\n";
	
	print MAIN "myhostname = one\n";
	print MAIN "alias_maps = hash:/etc/aliases\n";
	print MAIN "alias_database = hash:/etc/aliases\n";
	print MAIN "myorigin = /etc/mailname\n";
	print MAIN "mydestination = $hostname, localhost.localdomain, localhost\n";
	print MAIN "relayhost = $relayhost\n";
	print MAIN "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128\n";
	print MAIN "mailbox_size_limit = 0\n";
	print MAIN "recipient_delimiter = +\n";
	print MAIN "inet_interfaces = loopback-only\n";
		
	close(MAIN);	
    }
    
}


1;


# # Debian specific:  Specifying a file name will cause the first
# # line of that file to be used as the name.  The Debian default
# # is /etc/mailname.
# #myorigin = /etc/mailname

# smtpd_banner = $myhostname ESMTP $mail_name (Ubuntu)
#   biff = no
  
# # appending .domain is the MUA's job.
# append_dot_mydomain = no
  
# # Uncomment the next line to generate "delayed mail" warnings
# #delay_warning_time = 4h

# readme_directory = no
  
# # TLS parameters
# smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
#   smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
#   smtpd_use_tls=yes
#   smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
#   smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
  
# # See /usr/share/doc/postfix/TLS_README.gz in the postfix-doc package for
# # information on enabling SSL in the smtp client.

# myhostname = one
#   alias_maps = hash:/etc/aliases
#   alias_database = hash:/etc/aliases
#   myorigin = /etc/mailname
#   mydestination = os31.vlab.iu.hio.no, one, localhost.localdomain, localhost
#   relayhost = shadowfax.vlab.iu.hio.no
#   mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
#   mailbox_size_limit = 0
#   recipient_delimiter = +
#   inet_interfaces = loopback-only
  
 