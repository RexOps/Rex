#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Cache::Base;

use strict;
use warnings;

use Moo;

use Rex::Logger;
use Rex;

sub gen_key {
   my ($self, $key_name) = @_;
   return $key_name if $key_name;

   my ($package, $filename, $line, $subroutine) = caller(1);

   $package =~ s/::/_/g;

   my $gen_key_name = "\L${package}_\L${subroutine}";

   return $gen_key_name;
}

sub set {
   my ($self, $key, $val, $timeout) = @_;
   $self->{__data__}->{$key} = $val;
}

sub valid {
   my ($self, $key) = @_;
   return exists $self->{__data__}->{$key};
}

sub get {
   my ($self, $key) = @_;
   return $self->{__data__}->{$key};
}

sub reset {
   my ($self) = @_;
   $self->{__data__} = {};
}

# have to be overwritten by subclass
sub save {
   my ($self) = @_;
}

# have to be overwritten by subclass
sub load {
   my ($self) = @_;
}

1;
