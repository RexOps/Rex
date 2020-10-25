#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::File::Parser::Ini;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Data::Dumper;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub get {
  my ( $self, $section, $key ) = @_;

  unless ( exists $self->{"__data"}->{$section} ) {
    die("$section not found");
  }

  unless ( exists $self->{"__data"}->{$section}->{$key} ) {
    die("$key not found in $section");
  }

  return $self->{"__data"}->{$section}->{$key};
}

sub get_sections {
  my ($self) = @_;
  return keys %{ $self->{"__data"} };
}

sub read {
  my ($self) = @_;
  $self->{"__data"} = $self->_read_file;
}

sub _read_file {
  my ($self) = @_;

  my $data = {};

  my $section;
  open( my $fh, "<", $self->{"file"} );
  while ( my $line = <$fh> ) {
    chomp $line;
    next if ( $line =~ m/^\s*?;/ );
    next if ( $line =~ m/^\s*?$/ );

    if ( $line =~ m/^\[(.+)\]$/ ) {
      $section = $1;
      $data->{$section} = {};
      next;
    }

    if ($section) {
      my ( $key, $val ) = split( /=/, $line, 2 );
      $val =~ s/^\s+|\s+$//g;
      $key =~ s/^\s+|\s+$//g;

      $data->{$section}->{$key} = $val;
    }
  }
  close($fh);

  return $data;
}

1;
