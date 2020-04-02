use strict;
use warnings;

use Test::More;
use File::Temp qw(tempfile);
use Carp;

use Rex -base;
use Rex::Interface::File;

my $command = 'file --brief --mime-encoding';

my $file_libmagic_is_available = eval 'use File::LibMagic; 1';
my $file_command_is_compatible = eval "run qq($command $0), auto_die => 1; 1";

if ( $file_libmagic_is_available || $file_command_is_compatible ) {
  plan tests => 2;
}
else {
  plan skip_all =>
    'Could not load File::LibMagic module or find a compatible file command';
}

my $magic;

if ($file_libmagic_is_available) {
  $magic = File::LibMagic->new();
}

subtest 'no_write_utf8_files' => sub {
  Rex::Config->set_write_utf8_files(0);

  subtest 'no utf8 pragma' => sub {
    no utf8;
    my $file = write_file('möp');
    is( get_encoding($file), 'utf-8',
      'encoding no_write_utf8_files flag, no utf8 pragma' );
  };

  subtest 'utf8 pragma' => sub {
    use utf8;
    my $file = write_file('möp');
    is( get_encoding($file), 'iso-8859-1',
      'encoding no_write_utf8_files flag, utf8 pragma' );
  };
};

subtest 'write_utf8_files' => sub {
  Rex::Config->set_write_utf8_files(1);

  subtest 'no utf8 pragma' => sub {
    no utf8;
    my $file = write_file('möp');
    is( get_encoding($file), 'utf-8',
      'encoding write_utf8_files flag, no utf8 pragma' );
  };

  subtest 'utf8 pragma' => sub {
    use utf8;
    my $file = write_file('möp');
    is( get_encoding($file), 'utf-8',
      'encoding write_utf8_files flag, utf8 pragma' );
  };
};

sub write_file {
  my $content = shift;
  my ( undef, $filename ) = tempfile( UNLINK => 1 );

  my $fh = Rex::Interface::File->create();
  $fh->open( '>', $filename );
  $fh->write($content);
  $fh->close;

  return $filename;
}

sub get_encoding {
  my $file = shift;
  my $encoding;

  if ($magic) {
    my $info = $magic->info_from_filename($file);
    $encoding = $info->{encoding};
  }
  elsif ($file_command_is_compatible) {
    $encoding = run qq($command $file);
  }
  else {
    croak 'no magic, no command - better bail out';
  }

  return $encoding;
}
