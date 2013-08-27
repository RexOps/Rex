#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::hypervisor;

use strict;
use warnings;

use Rex::Logger;
use Rex::Helper::Run;

use XML::Simple;

use Data::Dumper;

sub execute {
   my ($class, $arg1, %opt) = @_;

   unless($arg1) {
      die("You have to define the vm name!");
   }

   my ($xml, @dominfo, $dom);
   if ($arg1 eq 'capabilities') {
      @dominfo = i_run "virsh capabilities";
      if($? != 0) {
         die("Error running virsh dominfo $dom");
      }

      my $xs = XML::Simple->new();
      $xml = $xs->XMLin(join("",@dominfo), KeepRoot => 1, KeyAttr => 1, ForceContent => 1);
   } else {
      Rex::Logger::debug("Unknown action $arg1");
      die("Unknown action $arg1");
   }
  
   my %ret = ();
   my ($k, $v);

   if(ref($xml->{'capabilities'}->{'guest'}) ne "ARRAY") {
      $xml->{'capabilities'}->{'guest'} = [ $xml->{'capabilities'}->{'guest'} ];
   }

   for my $line (@{$xml->{'capabilities'}->{'guest'}}) {

      $ret{$line->{'arch'}->{'name'}} = 'true'        
         if defined($line->{'arch'}->{'name'});

      $ret{'emulator'} = $line->{'arch'}->{'emulator'}->{'content'}
         if defined($line->{'arch'}->{'emulator'}->{'content'});

      $ret{'loader'} = $line->{'arch'}->{'loader'}->{'content'}
         if defined($line->{'arch'}->{'loader'}->{'content'});

      $ret{$line->{'os_type'}->{'content'}} = 'true'
         if defined($line->{'os_type'}->{'content'});

      if(defined($line->{'arch'}->{'domain'}) && ref($line->{'arch'}->{'domain'}) eq 'ARRAY') {
         for (@{$line->{'arch'}->{'domain'}}) {
            $ret{$_->{'type'}} = 'true';
         }
      } else {
         $ret{$line->{'arch'}->{'domain'}->{'type'}} = 'true'    
            if defined($line->{'arch'}->{'domain'}->{'type'});
      }
   }

   return \%ret;

}

1;
