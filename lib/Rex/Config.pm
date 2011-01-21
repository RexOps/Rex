#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Config;

use strict;
use warnings;

use vars qw($user $password $timeout $password_auth $public_key $private_key);

sub set_user {
   my $class = shift;
   $user = shift;
}

sub set_password {
   my $class = shift;
   $password = shift;
}

sub get_user {
   my $class = shift;
   return $user;
}

sub get_password {
   my $class = shift;
   return $password;
}

sub set_timeout {
   my $class = shift;
   $timeout = shift;
}

sub get_timeout {
   my $class = shift;
   return 2 unless $timeout;
   return $timeout;
}

sub set_password_auth {
   my $class = shift;
   $password_auth = shift || 1;
}

sub get_password_auth {
   return $password_auth;
}

sub set_public_key {
   my $class = shift;
   $public_key = shift;
}

sub get_public_key {
   if($public_key) {
      return $public_key;
   }

   return $ENV{'HOME'} . '/.ssh/id_rsa.pub';
}

sub set_private_key {
   my $class = shift;
   $private_key = shift;
}

sub get_private_key {
   if($private_key) {
      return $private_key;
   }

   return $ENV{'HOME'} . '/.ssh/id_rsa';
}
1;
