#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Shared::Var::Array;
   
use strict;
use warnings;

use Fcntl qw(:DEFAULT :flock);
use Data::Dumper;

use Storable;

sub __lock(&);
sub __retr;
sub __store;

sub TIEARRAY {
   my $self = {
      varname => $_[1],
   };

   bless $self, $_[0];
}

sub STORE {
   my $self = shift;
   my $index = shift;
   my $value = shift;


   return __lock {
      my $ref = __retr;
      my $ret = $ref->{$self->{varname}}->{data}->[$index] = $value;
      __store $ref;

      return $ret;
   };

}

sub FETCH {
   my $self = shift;
   my $index = shift;

   return __lock {
      my $ref = __retr;
      my $ret = $ref->{$self->{varname}}->{data}->[$index];

      return $ret;
   };
}

sub CLEAR {
   my $self = shift;

   __lock {
      my $ref = __retr;
      $ref->{$self->{varname}} = { data => [] };
      __store $ref;
   };

}

sub DELETE {
   my $self = shift;
   my $index = shift;


   __lock {
      my $ref = __retr;
      delete $ref->{$self->{varname}}->{data}->[$index];
      __store $ref;
   };

}

sub EXISTS {
   my $self = shift;
   my $index = shift;

   return __lock {
      my $ref = __retr;
      return exists $ref->{$self->{varname}}->{data}->[$index];
   };

}

sub PUSH {
   my $self = shift;
   my @data = @_;

   __lock {
      my $ref = __retr;

      if(! ref($ref->{$self->{varname}}->{data}) eq "ARRAY") {
         $ref->{$self->{varname}}->{data} = [];
      }

      push(@{ $ref->{$self->{varname}}->{data} }, @data);

      __store $ref;
   };

}

sub EXTEND {
   my $self = shift;
   my $count = shift;
}

sub STORESIZE {
   my $self = shift;
   my $newsize = shift;
}

sub FETCHSIZE {
   my $self = shift;

   return __lock {
      my $ref = __retr;
      if(ref($ref) ne "ARRAY") {
         return 0;
      }
      return scalar(@{ $ref->{$self->{varname}}->{data} });
   };

}

sub DESTROY {
   my $self = shift;
}

sub __lock(&) {

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my $ret = &{ $_[0] }();

   close($dblock);
   
   return $ret;
}

sub __store {
   my $ref = shift;
   store($ref, "vars.db");
}

sub __retr {

   if(! -f "vars.db") {
      return {};
   }

   return retrieve("vars.db");

}

1;
