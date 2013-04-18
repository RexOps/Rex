#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::bridge;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

use Data::Dumper;

sub execute {
   my $class = shift;

   my $result = run "VBoxManage list bridgedifs";
   if($? != 0) {
      die("Error running VBoxManage list bridgedifs");
   }

   my @ifs;
   my @blocks = split /\n\n/m, $result;
   for my $block (@blocks) {

      my $if = {};
      my @lines = split /\n/, $block;
      for my $line (@lines) {
         if ($line =~ /^Name:\s+(.+?)$/) {
            $if->{name} = $1;
         }
         elsif ($line =~ /^IPAddress:\s+(.+?)$/) {
            $if->{ip} = $1;
         }
         elsif ($line =~ /^NetworkMask:\s+(.+?)$/) {
            $if->{netmask} = $1;
         }
         elsif ($line =~ /^Status:\s+(.+?)$/) {
            $if->{status} = $1;
         }
      }

      push @ifs, $if;
   }

   return \@ifs;
}

1;
