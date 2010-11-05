#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Config;

use strict;
use warnings;

use vars qw($user $password);

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

1;
