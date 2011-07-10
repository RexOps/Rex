#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Inventory::DMIDecode;

use strict;
use warnings;

use Rex::Inventory::DMIDecode::BaseBoard;
use Rex::Inventory::DMIDecode::Bios;
use Rex::Commands::Run;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   $self->_read_dmidecode();

   return $self;
}

sub get_tree {
   my ($self, $section) = @_;

   if($section) {
      return $self->{"__dmi"}->{$section};
   }
   
   return $self->{"__dmi"};
}

sub get_base_board {
   my ($self) = @_;

   return Rex::Inventory::DMIDecode::BaseBoard->new(dmi => $self);
}

sub get_bios {
   my ($self) = @_;

   return Rex::Inventory::DMIDecode::Bios->new(dmi => $self);
}

sub _read_dmidecode {

   my ($self) = @_;

   my @lines = run "dmidecode";
   chomp @lines;

   my %section = ();
   my $section = ""; 
   my $new_section = 0;
   my $sub_section = "";

   for my $l (@lines) {

      next if $l =~ m/^Handle/;
      next if $l =~ m/^#/;
      next if $l =~ m/^SMBIOS/;
      next if $l =~ m/^$/;
      last if $l =~ m/^End Of Table$/;



      unless(substr($l, 0, 1) eq "\t") {
         $section = $l;
         $new_section = 1;
         next;
      }

      my $line = $l;
      $line =~ s/^\t+//g;
      $line =~ s/\s+$//g;

      next if $l =~ m/^$/;

      if($l =~ m/^\t[a-zA-Z0-9]/) {
         if(exists $section{$section} && ! ref($section{$section})) {
            my $content = $section{$section};
            $section{$section} = [];
            my @arr = ();
            my ($key, $val) = split(/: /, $line, 2);
            $key =~ s/:$//; 
            $sub_section = $key;
            #push (@{$section{$section}}, $content);
            push (@{$section{$section}}, {$key => $val});
            $new_section = 0;
            next;
         }
         elsif(exists $section{$section} && ref($section{$section})) {
            if($new_section) {
               push (@{$section{$section}}, {});
               $new_section = 0;
            }
            my ($key, $val) = split(/: /, $line, 2);
            $key =~ s/:$//; 
            $sub_section = $key;
            my $href = $section{$section}->[-1];
            #push (@{$section{$section}}, {$key => $val});
            $href->{$key} = $val;
            next;
         }

         my ($key, $val) = split(/: /, $line, 2);
         if(!$val) { $key =~ s/:$//; }
         $sub_section = $key;
         $section{$section} = [{$key => $val}];
         $new_section = 0;
      }
      elsif($l =~ m/^\t\t[a-zA-Z0-9]/) {
         my $href = $section{$section}->[-1];
         if(! ref($href->{$sub_section})) {
            $href->{$sub_section} = [];
         }

         push(@{$href->{$sub_section}}, $line);
      }



   }

   $self->{"__dmi"} = \%section;

}

1;
