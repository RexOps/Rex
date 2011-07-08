#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Inventory::DMIDecode;

use strict;
use warnings;

use Rex::Inventory::DMIDecode::BaseBoard;
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

sub _read_dmidecode {

   my ($self) = @_;

   my @lines = run "dmidecode";
   chomp @lines;

   my %section = ();
   my $section = ""; 

   for my $l (@lines) {

      next if $l =~ m/^Handle/;
      next if $l =~ m/^#/;
      next if $l =~ m/^SMBIOS/;
      next if $l =~ m/^$/;
      last if $l =~ m/^End Of Table$/;


      unless(substr($l, 0, 1) eq "\t") {
         $section = $l;
         next;
      }

      my $line = $l;
      $line =~ s/^\t+//g;

      if($l =~ m/^\t[a-zA-Z0-9]/) {
         if(exists $section{$section} && ! ref($section{$section})) {
            my $content = $section{$section};
            $section{$section} = [];
            my ($key, $val) = split(/: /, $line, 2);
            $key =~ s/:$//; 
            push (@{$section{$section}}, $content);
            push (@{$section{$section}}, {$key => $val});
            next;
         }
         elsif(exists $section{$section} && ref($section{$section})) {
            my ($key, $val) = split(/: /, $line, 2);
            $key =~ s/:$//; 
            push (@{$section{$section}}, {$key => $val});
            next;
         }

         my ($key, $val) = split(/: /, $line, 2);
         if(!$val) { $key =~ s/:$//; }
         $section{$section} = [{$key => $val}];
      }
      elsif($l =~ m/^\t\t[a-zA-Z0-9]/) {
         my $i = pop @{$section{$section}};
         my ($key) = [keys %{$i}]->[0];
         my ($val) = [values %{$i}]->[0];

         if(ref($i->{$key})) {
            push(@{$i->{$key}}, $line);
            push(@{$section{$section}}, $i);
         }
         else {

            push(@{$section{$section}}, {  $key => [$line] });
         }
      }



   }

   $self->{"__dmi"} = \%section;

}

1;
