#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Sudo::File;
   
use strict;
use warnings;

use Rex;
use Rex::Commands;
use Rex::Commands::Run;
use IO::File;

sub open {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = {};

   $self->{mode} = shift;
   $self->{file} = shift;
   $self->{rndfile} = "/tmp/" . get_random('a' .. 'z') . ".tmp";

   if(my $sftp = Rex::get_sftp()) {
      $self->{fh} = $sftp->open($self->{rndfile}, O_WRONLY | O_CREAT | O_TRUNC );
   }
   else {
      $self->{fh} = IO::File->new;
      $self->{fh}->open($self->{mode} . " " . $self->{rndfile});
   }

   bless($self, $proto);

   return $self;
}

sub write {
   my ($self, $content) = @_;

   if(ref($self->{fh}) eq "Net::SSH2::File") {
      $self->{fh}->write($content);
   }
   else {
      $self->{fh}->print($content);
   }
}

sub seek {
   my ($self, $offset) = @_;

   if(ref($self->{fh}) eq "Net::SSH2::File") {
      $self->{fh}->seek($offset);
   }
   else {
      $self->{fh}->seek($offset, 0);
   }
}

sub read {
   my ($self, $content, $len) = @_;
   $len ||= 64;

   my $buf;
   $self->{fh}->read($buf, $len);
}

sub close {
   my ($self) = @_;

   if(ref($self->{fh}) eq "Net::SSH2::File") {
      $self->{fh} = undef;
   }
   else {
      $self->{fh}->close;
   }

   cp($self->{rndfile}, $self->{file});
}

1;
