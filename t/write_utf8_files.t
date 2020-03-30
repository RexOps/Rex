use strict;
use warnings;

use Test::More;
use File::Temp qw(tempfile);

use Rex -base;
use Rex::Interface::File;

if ( $^O =~ m/^MSWin/ ) {
  plan skip_all => 'No encoding tests on Windows';
}
else {
  plan tests => 2;
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
  my $file     = shift;
  my $encoding = run qq(file --brief --mime-encoding $file);
  return $encoding;
}
