#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Shared::Var::Scalar;
   
use strict;
use warnings;

use Fcntl qw(:DEFAULT :flock);
use DB_File;
use Data::Dumper;

sub TIESCALAR {
   my $self = {
      varname => $_[1],
   };
   bless $self, $_[0];
}

sub STORE {
   my $self = shift;

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   $hash{$self->{varname}} = $_[0];

   untie %hash;
   close($dblock);

   return $_[1];
}

sub FETCH {
   my $self = shift;
   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   my $ret = $hash{$self->{varname}};

   untie %hash;
   close($dblock);

   return $ret;
}

1;
