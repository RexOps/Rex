#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Group;

use strict;
use warnings;


use vars qw(%groups);

sub create_group {
   my $class = shift;
   my $group_name = shift;
   my @server = @_;

   @{$groups{$group_name}} = @server;
}

sub get_group {
   my $class = shift;
   my $group_name = shift;

   return @{$groups{$group_name}};
}

sub is_group {
   my $class = shift;
   my $group_name = shift;

   if(defined $groups{$group_name}) { return 1; }
   return 0;
}
1;
