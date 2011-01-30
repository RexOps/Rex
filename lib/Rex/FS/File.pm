#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::FS::File;

use strict;
use warnings;

use constant DEFAULT_READ_LEN => 64;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub DESTROY {
   my ($self) = @_;
   $self->close if ($self->{'fh'});
}

sub write {
   my ($self, $buf) = @_;

   my $fh = $self->{'fh'};
   if(ref($fh) eq 'Net::SSH2::File') {
      $fh->write($buf);
   } else {
      print $fh $buf;
   }
}

sub read {
   my ($self, $len) = @_;
   $len = DEFAULT_READ_LEN if(!$len);

   my $fh = $self->{'fh'};
   my $buf;
   if(ref($fh) eq 'Net::SSH2::File') {
      $fh->read($buf, $len);
   } else {
      read $fh, $buf, $len;
   }

   return $buf;
}

sub read_all {
   my ($self) = @_;

   my $all = '';
   while(my $in = $self->read()) {
      $all .= $in;
   }

   if(wantarray) {
      return split(/\n/, $all);
   }
   return $all;
}

sub close {
   my ($self) = @_;
   my $fh = $self->{'fh'};
   if(ref($fh) eq 'Net::SSH2::File') {
      $fh = undef;
   } else {
      close($fh);
   }
}


1;
