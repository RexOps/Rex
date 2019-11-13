use strict;
use warnings;

use Test::More;
use File::Spec;
use File::Temp qw(tempdir);

use Rex -base;
use Rex::Helper::Path;

if ( $^O =~ m/^MSWin/ ) {
  plan skip_all => 'No symlink support on Windows';
}

$::QUIET = 1;

my $tmp_dir        = tempdir( CLEANUP => 1 );
my $file           = File::Spec->catfile( $tmp_dir, 'file' );
my $symlink        = File::Spec->catfile( $tmp_dir, 'symlink' );
my $nested_symlink = File::Spec->catfile( $tmp_dir, 'nested_symlink' );

sub setup {
  file $file, ensure => 'present';

  symlink $file,    $symlink;
  symlink $symlink, $nested_symlink;

  is( is_file($file),              TRUE, 'temp file is a file' );
  is( is_symlink($symlink),        TRUE, 'temp symlink is a symlink' );
  is( is_symlink($nested_symlink), TRUE, 'temp nested symlink is a symlink' );
}

sub check_still_symlink {
  is( is_symlink($symlink),      TRUE,  'temp symlink is still a symlink' );
  is( resolve_symlink($symlink), $file, 'symlink is still resolved to file' );
}

subtest 'resolve symlinks' => sub {
  setup();

  is( resolve_symlink($symlink), $file, 'symlink is resolved to file' );
  is( resolve_symlink($nested_symlink),
    $file, 'nested symlink is resolved to file' );
  is( resolve_symlink('not a symlink'),
    undef, 'non-existing symlink is unresolved' );
};

subtest 'file command with symlinks' => sub {
  setup();

  file $symlink, content => '1';

  is( cat($file), "1\n", 'file content written' );
  check_still_symlink();

  file $symlink, ensure => 'absent';

  is( is_file($file), TRUE, 'file is still present' );
  ok( !-e $symlink, 'symlink is gone' );
};

subtest 'delete_lines_matching with symlinks' => sub {
  setup();

  delete_lines_matching $symlink, '1';

  is( cat($file), "", 'line deleted' );
  check_still_symlink();
};

subtest 'append_or_amend_line with symlinks' => sub {
  setup();

  append_or_amend_line $symlink,
    line   => '2',
    regexp => qr{1};

  is( cat($file), "2\n", 'line updated' );
  check_still_symlink();
};

subtest 'sed with symlinks' => sub {
  setup();

  sed qr{1}, '2', $symlink;

  is( cat($file), "2\n", 'line updated' );
  check_still_symlink();
};

subtest 'file_write with symlinks' => sub {
  setup();

  my $fh = file_write $symlink;
  $fh->write('');
  $fh->close;

  is( cat($file), '', 'file is empty' );
  check_still_symlink();
};

subtest 'file_append with symlinks' => sub {
  setup();

  my $fh = file_append $symlink;
  $fh->write("1\n");
  $fh->close;

  is( cat($file), "1\n", 'file has been appended' );
  check_still_symlink();
};

done_testing();
