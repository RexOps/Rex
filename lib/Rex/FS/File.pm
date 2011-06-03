#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::FS::File - File Class

=head1 DESCRIPTION

This is the File Class used by I<write_file> and I<read_file>.

=head1 SYNOPSIS

 my $file = Rex::FS::File->new(fh => $fh);
 $file->read($len);
 $file->read_all;
 $file->write($buf);
 $file->close;

=head1 CLASS METHODS

=over 4

=cut

package Rex::FS::File;

use strict;
use warnings;

use constant DEFAULT_READ_LEN => 64;

=item new

This is the constructor. You need to set the filehandle which the object should work on.

 my $file = Rex::FS::File->new(fh => $fh);

=cut

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

=item write($buf)

Write $buf into the filehandle.

 $file->write("Hello World");

=cut

sub write {
   my ($self, @buf) = @_;
   my $fh = $self->{'fh'};
   if(ref($fh) eq 'Net::SSH2::File') {
      if(scalar(@buf) > 1) {
         for my $line (@buf) {
            $fh->write($line);
            $fh->write($/);
         }
      }
      else {
         $fh->write($buf[0]);
      }
   } else {
      if(scalar(@buf) > 1) {
         for my $line (@buf) {
            print $fh $line;
            print $fh $/;
         }
      }
      else {
         print $fh $buf[0];
      }
   }
}

=item read($len)

Read $len bytes out of the filehandle.

 my $content = $file->read(1024);

=cut

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

=item read_all

Read everything out of the filehandle.

 my $content = $file->read_all;

=cut

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

=item close

Close the file.

 $file->close;

=cut

sub close {
   my ($self) = @_;
   my $fh = $self->{'fh'};
   if(ref($fh) eq 'Net::SSH2::File') {
      $fh = undef;
   } else {
      close($fh);
   }
}

=back

=cut


1;
