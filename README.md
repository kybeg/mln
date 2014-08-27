MLN + OpenStack Havana + Ubuntu 12.04
===

This MLN repository is particularly aimed at using MLN as root on an Ubuntu
12.04 system, managing instances on OpenStack Havana or Amazon EC2.

MLN will run fine on other systems, however the nova packages
installed belong to the Havan release. Make sure you install the
appropirate nova command-line tools for your OpenStack version.

Installation
============

As root, first add the OpenStack Havan repositories:

   apt-get install python-software-properties
   add-apt-repository cloud-archive:havana
   apt-get update
   
Upgrade your system to the latest version:

   apt-get upgrade
   apt-get dist-upgrade
   
   reboot
   
Install the nova command-line tools

   apt-get install python-novaclient
   
Install MLN (Choose: Entire system, do not download any templates.
Keep the rest default. )

   ./mln setup




   