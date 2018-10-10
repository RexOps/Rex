use strict;
use warnings;

use Test::More;
use Test::Exception;
use Rex::Test::Base;

sub rex_fails_ok {
  my ($t, $code, $test, $desc) = @_;
  my $testno = $t->builder->current_test;
  my ($output, $failure);
  $t->builder->output(\$output);
  $t->builder->failure_output(\$failure);
  $code->();
  $t->builder->reset_outputs;
  $t->builder->current_test($testno);
  $t->builder->is_passing(1);
  like $failure, qr{Failed\stest\s}, 'test failed';
  return like $failure, $test, $desc;
}

test {
  my $t = shift;

  $t->name('Rex::Test::Base testing');

  note $t->has_dir('./t'), ' check this directory';
  rex_fails_ok $t, sub { $t->has_dir('/saved-by-the-bell') },
    qr{Found /saved-by-the-bell directory}, 'when dir is not there';

  note $t->has_file('./t/file-tests.t'), ' check this file';

  note $t->has_content('./t/cmdb/default.yml', qr{defaultname}), ' content check';

  note $t->has_checksum('./t/cmdb/foo.yml', '63411aefa9fe64da5e33c762c01e6de4', 'md5'),
    ' md5 checksum';
  note $t->has_checksum(
    './t/cmdb/foo.yml', 'e9ff883b4b3e6d515de774b7a7cff600aaab3d6c', 'SHA1'
    ), ' sha1 checksum';
  note $t->has_checksum(
    './t/cmdb/foo.yml', '57a831cda8328d650d98260a376106976a6ba4a5b21b8b2fadb2796e88debcf1', 'Sha256'),
    ' sha256 checksum';

  rex_fails_ok $t, sub {
    $t->has_checksum('./t/cmdb/foo.yml', '57a831cda8328d650d98260a376106976a6ba4a5b21b8b2fadb2796e88debcf1', 'shal256');
  }, qr/unsupported hash algorithm shal256/, 'bad algorithm';

  rex_fails_ok $t, sub {
    $t->has_checksum('./t/cmdb/foo.yml', '57a831cda8328d650d98260', 'sha256');
  }, qr{Checksum of \./t/cmdb/foo.yml is 57a831cda8328d650d98260}, 'incorrect checksum';
};


done_testing;
