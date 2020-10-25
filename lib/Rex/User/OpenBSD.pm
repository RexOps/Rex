#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::User::OpenBSD;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Commands::MD5;
use Rex::Helper::Run;
use Rex::Helper::Encode;
use Rex::Commands::Fs;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Interface::Exec;
use Rex::User::Linux;
use Rex::Helper::Path;
use JSON::MaybeXS;

use base qw(Rex::User::Linux);

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

  my $old_pw_md5 = md5("/etc/passwd");

  my $uid       = $self->get_uid($user);
  my %user_info = $self->get_user($user);
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

  if ( defined $user_info{uid} ) {
    if ( exists $data->{uid} ) {

      # On OpenBSD, "usermod -u n login" fails when the user login
      # has already n as userid. So skip it from the command arg
      # when the uid is already correct.
      $cmd .= " -u " . $data->{uid} unless $data->{uid} == $user_info{uid};
    }
  }
  else {
    # the user does not exist yet.
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

  if ( exists $data->{login_class} ) {
    $cmd .= " -L '" . $data->{login_class} . "'";
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
    Rex::Logger::debug("Changing password of $user.");
    $rnd_file = get_tmp_file;
    $fh       = Rex::Interface::File->create;
    $fh->open( ">", $rnd_file );
    $fh->write( "usermod -p \$(encrypt -b 6 '"
        . $data->{password}
        . "') $user\nexit \$?\n" );
    $fh->close;

    i_run "/bin/sh $rnd_file", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error setting password for $user");
    }

    Rex::Interface::Fs->create()->unlink($rnd_file);
  }

  if ( exists $data->{crypt_password} ) {
    Rex::Logger::debug("Setting encrypted password of $user");
    $rnd_file = get_tmp_file;
    $fh       = Rex::Interface::File->create;
    $fh->open( ">", $rnd_file );
    $fh->write(
      "usermod -p '" . $data->{crypt_password} . "' $user\nexit \$?\n" );
    $fh->close;

    i_run "/bin/sh $rnd_file", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error setting password for $user");
    }

    Rex::Interface::Fs->create()->unlink($rnd_file);
  }

  my $new_pw_md5 = md5("/etc/passwd");

  if ( $new_pw_md5 eq $old_pw_md5 ) {
    return {
      changed => 0,
      ret     => $self->get_uid($user),
    };
  }
  else {
    return {
      changed => 1,
      ret     => $self->get_uid($user),
      },
      ;
  }

}

sub get_user {
  my ( $self, $user ) = @_;

  Rex::Logger::debug("Getting information for $user");
  my $rnd_file = get_tmp_file;
  my $fh       = Rex::Interface::File->create;
  my $script   = q|
    unlink $0;
    print to_json([ getpwnam($ARGV[0]) ]);
  |;
  $fh->open( ">", $rnd_file );
  $fh->write($script);
  $fh->write( func_to_json() );
  $fh->close;

  my $data_str = i_run "perl $rnd_file $user", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error getting user information for $user");
  }

  my $data = decode_json($data_str);

  return (
    name     => $data->[0],
    password => $data->[1],
    uid      => $data->[2],
    gid      => $data->[3],
    pwchange => $data->[4],
    class    => $data->[5],
    comment  => $data->[6],
    home     => $data->[7],
    shell    => $data->[8],
    expire   => $data->[9],
  );
}

sub lock_password {
  my ( $self, $user ) = @_;

  # Is the password already locked?
  my $result = i_run "getent passwd $user", fail_ok => 1;

  if ( $result !~ /^$user.*$/ ) {
    die "Unexpected result from getent: $result";
  }
  elsif ( $result =~ /^$user.*-$/ ) {

    # Already locked
    return { changed => 0 };
  }
  else {
    my $ret = i_run "usermod -Z $user", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error locking account $user: $ret");
    }
    return {
      changed => 1,
      ret     => $ret,
    };
  }
}

sub unlock_password {
  my ( $self, $user ) = @_;

  # Is the password already unlocked?
  my $result = i_run "getent passwd $user", fail_ok => 1;

  if ( $result !~ /^$user.*$/ ) {
    die "Unexpected result from getent: $result";
  }
  elsif ( $result !~ /^$user.*-$/ ) {

    # Already unlocked
    return { changed => 0 };
  }
  else {
    my $ret = i_run "usermod -U $user", sub { @_ }, fail_ok => 1;
    if ( $? != 0 ) {
      die("Error unlocking account $user: $ret");
    }
    return {
      changed => 1,
      ret     => $ret,
    };
  }
}

sub rm_user {
  my ( $self, $user, $data ) = @_;

  Rex::Logger::debug("Removing user $user");

  my %user_info = $self->get_user($user);

  my $cmd = "userdel";

  if ( exists $data->{delete_home} ) {
    $cmd .= " -r";
  }

  my $output = i_run $cmd . " " . $user, fail_ok => 1;
  if ( $? == 67 ) {
    Rex::Logger::info( "Cannot delete user $user (no such user)", "warn" );
  }
  elsif ( $? != 0 ) {
    die("Error deleting user $user ($output)");
  }

  if ( exists $data->{delete_home} && is_dir( $user_info{home} ) ) {
    Rex::Logger::debug(
      "userdel doesn't delete home directory. removing it now by hand...");
    rmdir $user_info{home};
  }

  if ( $? != 0 ) {
    die( "Error removing " . $user_info{home} );
  }

}

1;
