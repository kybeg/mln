MLN + OpenStack + Ubuntu 20.04
======================================

This MLN repository is particularly aimed at using MLN as root on an Ubuntu
20.04 system, managing instances on OpenStack Havana or Amazon EC2.

MLN will run fine on other systems, however the nova packages
installed belong to the Havan release. Make sure you install the
appropirate nova command-line tools for your OpenStack version.

Installation
============


* Install the nova command-line tools::

   apt-get install python3-openstackclient

* Download MLN if you haven't already::

   git clone https://github.com/kybeg/mln.git

* Install MLN (Choose: Entire system, do not download any templates. Keep the rest default. )::

   cd mln
   ./mln setup

* Verify that MLN and the plugins are installed::

   mln write_config


   
