#!/usr/bin/env perl
use v5.14.4;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 8;
use Test::Warnings;

use Rex -feature => '1.4';
use Rex::Commands::Run;
use Rex::Interface::Connection::Base;

my $doas          = 'Doas';
my $doas_enabled  = 'doas enabled';
my $doas_disabled = 'doas disabled';
my $root          = 'root';
my $daemon        = 'daemon';

subtest 'doas global enable and disable' => sub {
  Rex::global_doas(0);
  ok( !Rex::is_doas(), $doas_disabled );

  doas 'on';
  ok( Rex::is_doas(), 'on enables global doas' );

  doas '0';
  ok( !Rex::is_doas(), '0 disables global doas' );
};

subtest 'doas does not change sudo' => sub {
  my $conn = Rex::Interface::Connection::Base->new();

  local *Rex::get_current_connection_object = sub { $conn };

  $conn->push_use_sudo(1);

  doas sub {
    is( $conn->get_current_use_sudo(), 1, 'sudo state retained' );
    is( $conn->get_current_use_doas(), 1, 'doas enabled' );
  };

  is( $conn->get_current_use_sudo(), 1, 'sudo still enabled afterward' );
  ok( !$conn->get_current_use_doas(), 'doas disabled afterward' );

  $conn->pop_use_sudo();
};

subtest 'connection doas and options are stacks' => sub {
  my $conn = Rex::Interface::Connection::Base->new();

  ok( !$conn->get_current_use_doas(),             $doas_disabled );
  ok( !defined $conn->get_current_doas_options(), 'no initial options' );

  $conn->push_use_doas(1);
  $conn->push_doas_options( user => $root );
  is( $conn->get_current_use_doas(), 1, $doas_enabled );
  is_deeply(
    $conn->get_current_doas_options(),
    { user => $root },
    'root options'
  );

  $conn->push_use_doas(1);
  $conn->push_doas_options( { user => $daemon } );
  is_deeply(
    $conn->get_current_doas_options(),
    { user => $daemon },
    'nested options'
  );

  $conn->pop_doas_options();
  $conn->pop_use_doas();
  is_deeply(
    $conn->get_current_doas_options(),
    { user => $root },
    'outer options restored'
  );

  $conn->pop_doas_options();
  $conn->pop_use_doas();
  ok( !$conn->get_current_use_doas(),             'doas disabled after pop' );
  ok( !defined $conn->get_current_doas_options(), 'options cleared after pop' );
};

subtest 'OpenSSH selects doas' => sub {
  require Rex::Interface::Connection::OpenSSH;

  my $conn = Rex::Interface::Connection::OpenSSH->new();

  local *Rex::is_doas = sub { 1 };
  local *Rex::is_sudo = sub { 0 };

  is( $conn->get_connection_type(), $doas,
    'OpenSSH selects doas when enabled' );
};

subtest 'doas selects execution backend' => sub {
  require Rex::Interface::Connection::OpenSSH;
  require Rex::Interface::Exec;

  my $conn = Rex::Interface::Connection::OpenSSH->new();

  local *Rex::get_current_connection = sub {
    return { conn => $conn };
  };
  local *Rex::is_doas = sub { 1 };
  local *Rex::is_sudo = sub { 0 };

  is( $conn->get_connection_type(), 'Doas', 'connection selects doas' );

  my $exec = Rex::Interface::Exec->create();

  isa_ok( $exec, 'Rex::Interface::Exec::Doas', 'execution backend' );
};

subtest 'doas selects filesystem backend' => sub {
  require Rex::Interface::Connection::OpenSSH;
  require Rex::Interface::Fs;

  my $conn = Rex::Interface::Connection::OpenSSH->new();

  local *Rex::get_current_connection = sub {
    return { conn => $conn };
  };
  local *Rex::is_doas = sub { 1 };
  local *Rex::is_sudo = sub { 0 };

  is( $conn->get_connection_type(), 'Doas', 'connection selects doas' );

  my $fs = Rex::Interface::Fs->create();

  isa_ok( $fs, 'Rex::Interface::Fs::Doas', 'filesystem backend' );
};

subtest 'Doas file interface uses Doas FS' => sub {
  require Rex::Interface::File::Doas;
  require Rex::Interface::Fs;

  my $file = Rex::Interface::File::Doas->new();
  my $selected_type;

  local *Rex::Interface::Fs::create = sub {
    my ( $class, $type ) = @_;
    $selected_type = $type;
    return bless {}, 'TestDoasFs';
  };

  my $fs = $file->_fs();

  is( $selected_type, $doas, 'file interface selects Doas filesystem' );

  isa_ok( $fs, 'TestDoasFs', 'filesystem returned' );
};

Rex::global_doas(0);
done_testing
