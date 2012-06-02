#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Shared::Var::Hash;
   
use strict;
use warnings;

use Data::Dumper;

use Fcntl qw(:DEFAULT :flock);
use DB_File;
use Data::Dumper;

use XML::Simple;

sub TIEHASH {
   my $self = {
      varname => $_[1],
   };

   bless $self, $_[0];
}

sub STORE {
   my $self = shift;
   my $key = shift;
   my $value = shift;

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   my $xml_string = $hash{$self->{varname}};
   my $ref = {};
   if($xml_string) {
      $ref = XMLin($xml_string);
   }

   $ref->{$key} = $value;

   $hash{$self->{varname}} = XMLout($ref);

   untie %hash;
   close($dblock);

   return $_[1];

}

sub FETCH {
   my $self = shift;
   my $key = shift;

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   my $xml_string = $hash{$self->{varname}};
   my $ref = {};
   if($xml_string) {
      $ref = XMLin($xml_string);
   }

   my $ret = $ref->{$key};

   untie %hash;
   close($dblock);

   return $ret;
}

sub DELETE {
   my $self = shift;
   my $key = shift;

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   my $xml_string = $hash{$self->{varname}};
   my $ref = {};
   if($xml_string) {
      $ref = XMLin($xml_string);
   }

   delete $ref->{$key};

   $hash{$self->{varname}} = XMLout($ref);

   untie %hash;
   close($dblock);

}

sub CLEAR {
   my $self = shift;

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   $hash{$self->{varname}} = XMLout({});

   untie %hash;
   close($dblock);
}

sub EXISTS {
   my $self = shift;
   my $key = shift;

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   my $ref = XMLin($hash{$self->{varname}});
   my $ret = exists $ref->{$key};

   untie %hash;
   close($dblock);

   return $ret;
}

sub FIRSTKEY {
   my $self = shift;

   sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
   flock($dblock, LOCK_SH) or die($!);

   my %hash;
   tie(%hash, "DB_File", "vars.db", O_RDWR | O_CREAT) or die("Can't tie: $!");

   my $ref = XMLin($hash{$self->{varname}});
   $self->{__iter__} = $ref;

   untie %hash;
   close($dblock);

   my $temp = keys %{ $self->{__iter__} };
   return scalar each %{ $self->{__iter__} };

}

sub NEXTKEY {
   my $self = shift;
   my $prevkey = shift;

   return scalar each %{ $self->{__iter__} };
}

sub DESTROY {
   my $self = shift;
}




1;
