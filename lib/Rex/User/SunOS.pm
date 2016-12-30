#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::User::SunOS;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::User::OpenBSD;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Interface::Exec;
use Rex::Helper::Path;

use base qw(Rex::User::OpenBSD);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub create_user {
  my ( $self, $user, $data ) = @_;

  my $cmd;

  my $uid = $self->get_uid($user);
  my $should_create_home;

  if ( $data->{'create_home'} || $data->{'create-home'} ) {
    $should_create_home = 1;
  }
  elsif ( $data->{'no_create_home'} || $data->{'no-create-home'} ) {
    $should_create_home = 0;
  }
  elsif ( ( exists $data->{'no_create_home'} && $data->{'no_create_home'} == 0 )
    || ( exists $data->{'no-create-home'} && $data->{'no-create-home'} == 0 ) )
  {
    $should_create_home = 1;
  }

  if ( !defined $uid ) {
    Rex::Logger::debug("User $user does not exists. Creating it now.");
    $cmd = "useradd ";

    if ( exists $data->{system} ) {
      $cmd .= " -r";
    }
  }
  else {
    Rex::Logger::debug("User $user already exists. Updating...");

    $cmd = "usermod ";
  }

  if ( exists $data->{uid} ) {
    $cmd .= " -u " . $data->{uid};
  }

  if ( exists $data->{home} ) {
    $cmd .= " -d " . $data->{home};
  }

  if ( $should_create_home && !defined $uid ) { #useradd mode
    $cmd .= " -m ";
  }

  if ( exists $data->{shell} ) {
    $cmd .= " -s " . $data->{shell};
  }

  if ( exists $data->{comment} ) {
    $cmd .= " -c '" . $data->{comment} . "'";
  }

  if ( exists $data->{expire} ) {
    $cmd .= " -e '" . $data->{expire} . "'";
  }

  if ( exists $data->{groups} ) {
    my @groups    = @{ $data->{groups} };
    my $pri_group = shift @groups;

    $cmd .= " -g $pri_group";

    if (@groups) {
      $cmd .= " -G " . join( ",", @groups );
    }
  }

  my $rnd_file = get_tmp_file;
  my $fh       = Rex::Interface::File->create;
  $fh->open( ">", $rnd_file );
  $fh->write("$cmd $user\nexit \$?\n");
  $fh->close;

  i_run "/bin/sh $rnd_file", fail_ok => 1;
  if ( $? == 0 ) {
    Rex::Logger::debug("User $user created/updated.");
  }
  else {
    Rex::Logger::info( "Error creating/updating user $user", "warn" );
    die("Error creating/updating user $user");
  }

  Rex::Interface::Fs->create()->unlink($rnd_file);

  if ( exists $data->{password} ) {
    my $expect_path;

    if ( can_run("/usr/local/bin/expect") ) {
      $expect_path = "/usr/local/bin/expect";
    }
    elsif ( can_run("/usr/bin/expect") ) {
      $expect_path = "/usr/bin/expect";
    }

    if ($expect_path) {
      my $chpasswd_file = get_tmp_file;
      my $fh            = file_write $chpasswd_file;
      $fh->write(
        qq~#!$expect_path --
# Input: username password
set USER [lindex \$argv 0]
set PASS [lindex \$argv 1]

if { \$USER == "" || \$PASS == "" }  {
  puts "Usage:  /tmp/chpasswd username password\n"
  exit 1
 }

spawn passwd \$USER
expect "assword:"
send "\$PASS\r"
expect "assword:"
send "\$PASS\r"
expect eof
~
      );
      $fh->close;

      $rnd_file = get_tmp_file;
      $fh       = Rex::Interface::File->create;
      $fh->open( ">", $rnd_file );
      $fh->write(
        "$chpasswd_file $user '" . $data->{"password"} . "'\nexit \$?\n" );
      $fh->close;

      chmod 700, $chpasswd_file;
      i_run "/bin/sh $rnd_file", fail_ok => 1;
      if ( $? != 0 ) { die("Error changing user's password."); }

      rm $chpasswd_file;
      rm $rnd_file;
    }
    else {
      die(
        "No expect found in /usr/local/bin or /usr/bin. Can't set user password."
      );
    }
  }

  return {
    changed => 0,
    ret     => $self->get_uid($user),
  };

}

1;
