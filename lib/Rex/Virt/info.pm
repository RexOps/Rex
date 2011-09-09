#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virt::info;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

use XML::Simple;

use Data::Dumper;

sub execute {
   my ($class, $arg1, %opt) = @_;

   unless($arg1) {
      die("You have to define the vm name!");
   }

   my $dom = $arg1;

   Rex::Logger::debug("Getting info of domain: $dom");

   my @dominfo = ();
   my $xml;

   if ($opt{'action'} eq 'dominfo') {
      @dominfo = run "virsh dominfo $dom";
   } elsif ($opt{'action'} eq 'nodeinfo') {
      @dominfo = run "virsh nodeinfo";
   } elsif ($opt{'action'} eq 'capabilities') {
      @dominfo = run "virsh capabilities";
      my $xs = XML::Simple->new();
      $xml = $xs->XMLin(join("",@dominfo), KeepRoot => 1, KeyAttr => 1, ForceContent => 1);
   } else {
      return;
   }
  
   if($? != 0) {
      die("Error running virsh dominfo $dom");
   }

   my %ret = ();
   my ($k, $v);

   unless ($xml) {
      for my $line (@dominfo) {
         ($k, $v) = split(/:\s+/, $line);
         $ret{$k} = $v;
      } 
  } else {
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
   }

   return \%ret;

}

1;
