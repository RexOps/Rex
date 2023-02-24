#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 13;

use Rex::Helper::Path;
use Rex::Commands::File;

my @lines = ( "first line", "second line", "test" );

my $filename = Rex::Helper::Path::get_tmp_file();
file( $filename, content => join "\n", @lines );

ok -e $filename, 'file was created';

{
  # standard Rex::FS::File usage - read file
  my $fh = Rex::Interface::File->create('Local');
  $fh->open( '<', $filename );
  my $file_object = Rex::FS::File->new( fh => $fh );

  isa_ok $file_object, 'Rex::FS::File', 'new with fh was successful';

  my @read_lines = $file_object->read_all;
  is_deeply \@read_lines, \@lines, 'read lines from fh';
}

{
  # standard Rex::FS::File usage - write file
  my $fh = Rex::Interface::File->create('Local');
  $fh->open( '>', $filename );
  my $file_object = Rex::FS::File->new( fh => $fh );

  isa_ok $file_object, 'Rex::FS::File',
    'new with fh (write mode) was successful';

  $file_object->write(qw/this is a test/);
  $file_object->close;

  my $read_fh = Rex::Interface::File->create('Local');
  $read_fh->open( '<', $filename );
  my $read_object = Rex::FS::File->new( fh => $read_fh );
  my @read_lines  = $read_object->read_all;
  is_deeply \@read_lines, [qw/this is a test/], 'read lines from fh';
}

{
  # new Rex::FS::File usage - read file
  file( $filename, content => join "\n", @lines );
  my $file_object = Rex::FS::File->new( filename => $filename );

  isa_ok $file_object, 'Rex::FS::File', 'new with filename was successful';

  my @read_lines = $file_object->read_all;
  is_deeply \@read_lines, \@lines, 'read lines from filename';
}

{
  # new Rex::FS::File usage - write file
  my $file_object = Rex::FS::File->new( filename => $filename, mode => '>' );

  isa_ok $file_object, 'Rex::FS::File',
    'new with filename with mode ">" was successful';

  $file_object->write(qw/this is a test/);
  $file_object->close;

  my $read_fh = Rex::Interface::File->create('Local');
  $read_fh->open( '<', $filename );
  my $read_object = Rex::FS::File->new( fh => $read_fh );
  my @read_lines  = $read_object->read_all;
  is_deeply \@read_lines, [qw/this is a test/], 'read lines from fh';
}

{
  # new Rex::FS::File usage - read file - explicit read mode
  file( $filename, content => join "\n", @lines );
  my $file_object = Rex::FS::File->new( filename => $filename, mode => '<' );

  isa_ok $file_object, 'Rex::FS::File',
    'new with filename and explicit read mode was successful';

  my @read_lines = $file_object->read_all;
  is_deeply \@read_lines, \@lines,
    'read lines from filename (explicit read mode)';
}

{
  # new Rex::FS::File usage - write file - mode "w"
  my $file_object = Rex::FS::File->new( filename => $filename, mode => 'w' );

  isa_ok $file_object, 'Rex::FS::File',
    'new with filename with mode "w" was successful';

  $file_object->write(qw/this is a test/);
  $file_object->close;

  my $read_object = Rex::FS::File->new( filename => $filename, mode => 'r' );
  my @read_lines  = $read_object->read_all;
  is_deeply \@read_lines, [qw/this is a test/], 'read lines from fh';
}
