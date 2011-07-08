#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Inventory::USB;

use strict;
use warnings;

use Rex::Commands::Run;
use Data::Dumper;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   $self->_read_lsusb;

   return $self;
}

sub _read_lsusb {

   my $self = shift;
   my @lines = run "lsusb -v";
   chomp @lines;

   my @devices = ();

   my $in;
   my $device;
   foreach my $line (@lines) {
       if ($line =~ /^Device/) {
           $in = 1;
       } elsif ($line =~ /^\s*$/) {
           $in = 0;
           push(@devices, $device);
           $device = {};
       } elsif ($in) {
           if ($line =~ /^\s*idVendor\s*0x(\w+)/i) {
               $device->{vendorId}=$1;
           }
           if ($line =~ /^\s*idProduct\s*0x(\w+)/i) {
               $device->{productId}=$1;
           }
           if ($line =~ /^\s*iSerial\s*\d+\s(\w+)/i) {
               $device->{serial}=$1;
           }
           if ($line =~ /^\s*bInterfaceClass\s*(\d+)/i) {
               $device->{class}=$1;
           }
           if ($line =~ /^\s*bInterfaceSubClass\s*(\d+)/i) {
               $device->{subClass}=$1;
           }
       }
   }
   push(@devices, $device);
   print Dumper(\@devices);
}

1;

package Rex::Inventory::USB::Device;

use strict;
use warnings;



1;


