use strict;
use warnings;
use Rex -base;
use Rex::Task;
use Rex::Config;
use Test::More;
use Test::Warn;
use Test::Exception;

my %have_mods = (
  'Net::OpenSSH' => 1,
);

for my $m ( keys %have_mods ) {
  my $have_mod = 1;
  eval "use $m;";
  if ($@) {
    $have_mods{$m} = 0;
  }
}

unless ( $have_mods{'Net::OpenSSH'} ) {
  plan skip_all =>
    'Net::OpenSSH not installed.';
}
else {
  plan tests => 1;
}

my %hash = (initialize_options => {'external_master' => 1, 'ctl_path' => '/home/me/.ssh/socket_name'});
Rex::Config->set_openssh_opt(%hash);
#ok (Rex::Config->set_openssh_opt(%hash), 'can set external_master');
my $t1 = Rex::Task->new( name => "foo" );
$t1->set_server("192.168.1.1");
throws_ok ( sub { $t1->run('192.168.1.1') }, qr/authenticate against/, 'authenticate against');
#warnings_like { $t1->run('192.168.1.1') } qr/WARN.*does not point to a socket/, 'throws socket warning';
