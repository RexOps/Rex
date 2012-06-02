#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Shared::Var::Array;
   
use strict;
use warnings;

use Fcntl qw(:DEFAULT :flock);
use DB_File;
use Data::Dumper;

use XML::Simple;

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

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   my $xml_string = $hash{$self->{varname}};
   my $ref = {data => []};
   if($xml_string) {
      $ref = XMLin($xml_string, ForceArray => 1);
   }

   $ref->{data}->[$index] = $value;

   $hash{$self->{varname}} = XMLout($ref);

   untie %hash;
   close($dblock);

   return $_[1];
}

sub FETCH {
   my $self = shift;
   my $index = shift;

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   my $xml_string = $hash{$self->{varname}};
   my $ref = { data => [] };
   if($xml_string) {
      $ref = XMLin($xml_string, ForceArray => 1);
   }

   my $ret = $ref->{data}->[$index];

   untie %hash;
   close($dblock);

   return $ret;
}

sub CLEAR {
   my $self = shift;

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   $hash{$self->{varname}} = XMLout([]);

   untie %hash;
   close($dblock);
}

sub DELETE {
   my $self = shift;
   my $index = shift;

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   my $ref = XMLin($hash{$self->{varname}}, ForceArray => 1);
   delete $ref->{data}->[$index];
   $hash{$self->{varname}} = XMLout($ref);

   untie %hash;
   close($dblock);
}

sub EXISTS {
   my $self = shift;
   my $index = shift;

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   my $ref = XMLin($hash{$self->{varname}}, ForceArray => 1);
   my $ret = exists $ref->{data}->[$index];

   untie %hash;
   close($dblock);

   return $ret;
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

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   my $ref = XMLin($hash{$self->{varname}}, ForceArray => 1);

   untie %hash;
   close($dblock);

   return scalar(@{ $ref->{data} });
}

sub DESTROY {
   my $self = shift;
}


1;
