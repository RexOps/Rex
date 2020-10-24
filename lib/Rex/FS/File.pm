#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::FS::File - File Class

=head1 DESCRIPTION

This is the File Class used by I<file_write> and I<file_read>.

=head1 SYNOPSIS

 use Rex::Interface::File;
 my $fh = Rex::Interface::File->create('Local');
 $fh->open( '<', 'filename' );

 my $file = Rex::FS::File->new(fh => $fh);
 $file->read($len);
 $file->read_all;
 $file->write($buf);
 $file->close;

=head1 CLASS METHODS

=cut

package Rex::FS::File;

use 5.010001;
use strict;
use warnings;
use Rex::Interface::File;

our $VERSION = '9999.99.99_99'; # VERSION

use constant DEFAULT_READ_LEN => 64;

=head2 new

This is the constructor. You need to set the filehandle which the object should work on
or pass a filename. If you pass a filehandle, it has to be a C<Rex::Interface::File::*>
object

 my $fh = Rex::Interface::File->create('Local');
 $fh->open( '<', 'filename' );
 
 my $file = Rex::FS::File->new(fh => $fh);

Create a C<Rex::FS::File> object with a filename

 # open a local file in read mode
 my $file = Rex::FS::File->new(
   filename => 'filename',
   mode     => 'r', # or '<'
   type     => 'Local',
 );
 
 # or shorter
 my $file = Rex::FS::File->new( filename => 'filename' );
 
 # open a local file in write mode
 my $file = Rex::FS::File->new(
   filename => 'filename',
   mode     => 'w', # or '>'
 );

Allowed modes:

 <  read
 r  read
 >  write
 w  write
 >> append
 a  append

For allowed C<types> see documentation of L<Rex::Interface::File>.

=cut

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  my %modes = (
    'w'  => '>',
    'r'  => '<',
    'a'  => '>>',
    '<'  => '<',
    '>'  => '>',
    '>>' => '>>',
  );

  if ( $self->{filename} ) {
    $self->{mode} ||= '<';

    my $mode = $modes{ $self->{mode} } || '<';
    $self->{fh} = Rex::Interface::File->create( $self->{type} || 'Local' );
    $self->{fh}->open( $mode, $self->{filename} );
  }

  bless( $self, $proto );

  if ( ref $self->{fh} !~ m{Rex::Interface::File} ) {
    die "Need an Rex::Interface::File object";
  }

  return $self;
}

sub DESTROY {
  my ($self) = @_;
  if ( ref $self->{'fh'} =~ m/^Rex::Interface::File/ ) {
    $self->close if ( $self->{'fh'}->{'fh'} );
  }
  else {
    $self->close if ( $self->{'fh'} );
  }
}

=head2 write($buf)

Write $buf into the filehandle.

 $file->write("Hello World");

=cut

sub write {

  my ( $self, @buf ) = @_;
  my $fh = $self->{fh};

  if ( scalar(@buf) > 1 ) {
    for my $line (@buf) {
      $fh->write($line);
      $fh->write($/);
    }
  }
  else {
    $fh->write( $buf[0] );
  }
}

=head2 seek($offset)

Seek to the file position $offset.

Set the file pointer to the 5th byte.

 $file->seek(5);

=cut

sub seek {
  my ( $self, $offset ) = @_;

  my $fh = $self->{'fh'};
  $fh->seek($offset);
}

=head2 read($len)

Read $len bytes out of the filehandle.

 my $content = $file->read(1024);

=cut

sub read {
  my ( $self, $len ) = @_;
  $len = DEFAULT_READ_LEN if ( !$len );

  my $fh = $self->{'fh'};
  return $fh->read($len);
}

=head2 read_all

Read everything out of the filehandle.

 my $content = $file->read_all;

=cut

sub read_all {
  my ($self) = @_;

  my $all = '';
  while ( my $in = $self->read() ) {
    $all .= $in;
  }
  if (wantarray) {
    return split( /\n/, $all );
  }
  return $all;
}

=head2 close

Close the file.

 $file->close;

=cut

sub close {
  my ($self) = @_;
  my $fh = $self->{'fh'};
  $fh->close;
}

1;
