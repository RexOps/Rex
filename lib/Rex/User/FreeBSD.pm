#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::User::FreeBSD;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Commands::MD5;
use Rex::Helper::Run;
use Rex::Helper::Encode;
use Rex::Commands::Fs;
use Rex::Commands::File;
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

  my $uid = $self->get_uid($user);
  my $should_create_home;

  my $old_pw_md5 = md5("/etc/passwd");

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
    $cmd = "pw useradd ";
  }
  else {
    Rex::Logger::debug("User $user already exists. Updating...");
    $cmd = "pw usermod ";
  }

  if ( $data->{"uid"} ) {
    $cmd .= " -u " . $data->{"uid"};
  }

  if ( $data->{"home"} ) {
    $cmd .= " -d " . $data->{"home"};
  }

  if ( $should_create_home && !defined $uid ) { #useradd mode
    $cmd .= " -m ";
  }

  if ( exists $data->{shell} ) {
    $cmd .= " -s " . $data->{shell};
  }

  if ( $data->{"comment"} ) {
    $cmd .= " -c \"" . $data->{"comment"} . "\" ";
  }

  if ( $data->{"expire"} ) {
    $cmd .= " -e " . $data->{"expire"};
  }

  if ( $data->{"groups"} ) {
    my @groups = @{ $data->{groups} };
    $cmd .= " -g " . $groups[0];
    $cmd .= " -G " . join( ",", @groups );
  }

  my $rnd_file = get_tmp_file;
  my $fh       = Rex::Interface::File->create;
  $fh->open( ">", $rnd_file );
  $fh->write("$cmd -n $user\nexit \$?\n");
  $fh->close;

  i_run "/bin/sh $rnd_file", fail_ok => 1;
  my $retval = $?;
  Rex::Interface::Fs->create()->unlink($rnd_file);

  if ( $retval == 0 ) {
    Rex::Logger::debug("User $user created/updated.");
  }
  else {
    Rex::Logger::info( "Error creating/updating user $user", "warn" );
    die("Error creating/updating user $user");
  }

  if ( exists $data->{password} ) {
    Rex::Logger::debug("Changing password of $user.");

    $rnd_file = get_tmp_file;
    $fh       = Rex::Interface::File->create;
    $fh->open( ">", $rnd_file );
    $fh->write(
      "echo '" . $data->{password} . "' | pw usermod $user -h 0\nexit \$?\n" );
    $fh->close;

    i_run "/bin/sh $rnd_file", fail_ok => 1;
    my $pw_retval = $?;
    Rex::Interface::Fs->create()->unlink($rnd_file);

    if ( $pw_retval != 0 ) {
      die("Error setting password for $user");
    }

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

sub rm_user {
  my ( $self, $user, $data ) = @_;

  Rex::Logger::debug("Removing user $user");

  my $cmd = "pw userdel";

  if ( exists $data->{delete_home} ) {
    $cmd .= " -r ";
  }

  my $output = i_run $cmd . " -n " . $user, fail_ok => 1;
  if ( $? == 67 ) {
    Rex::Logger::info( "Cannot delete user $user (no such user)", "warn" );
  }
  elsif ( $? != 0 ) {
    die("Error deleting user $user ($output)");
  }

}

sub get_uid {
  my ( $self, $user ) = @_;

  my %data = $self->get_user($user);
  return $data{uid};
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
    die("Error getting  user information for $user");
  }

  Rex::Interface::Fs->create()->unlink($rnd_file);

  my $data = decode_json($data_str);

  return (
    name     => $data->[0],
    password => $data->[1],
    uid      => $data->[2],
    gid      => $data->[3],
    comment  => $data->[5],
    home     => $data->[7],
    shell    => $data->[8],
    expire   => exists $data->[9] ? $data->[9] : 0,
  );
}

sub create_group {
  my ( $self, $group, $data ) = @_;

  my $cmd;

  if ( !defined $self->get_gid($group) ) {
    Rex::Logger::debug("Creating new group $group");

    $cmd = "pw groupadd ";

    if ( exists $data->{gid} ) {
      $cmd .= " -g " . $data->{gid};
    }

    i_run $cmd . " -n " . $group, fail_ok => 1;
    if ( $? != 0 ) {
      die("Error creating/modifying group $group");
    }
  }
  else {
    Rex::Logger::debug("Group $group already exists. Updating...");

    # updating with pw groupmod doesn't work good in freebsd 10
    # so we directly edit the /etc/group file
    #$cmd = "pw groupmod ";

    if ( exists $data->{gid} ) {
      eval {
        my @content = split( /\n/, cat("/etc/group") );
        my $gid     = $data->{gid};
        for (@content) {
          s/^$group:([^:]+):(\d+):/$group:$1:$gid:/;
        }
        my $fh = file_write("/etc/group");
        $fh->write( join( "\n", @content ) );
        $fh->close;
        1;
      } or do {
        die("Error creating/modifying group $group");
      };
    }
  }

  return $self->get_gid($group);

}

sub get_gid {
  my ( $self, $group ) = @_;

  my %data = $self->get_group($group);
  return $data{gid};
}

sub get_group {
  my ( $self, $group ) = @_;

  Rex::Logger::debug("Getting information for $group");
  my $rnd_file = get_tmp_file;
  my $fh       = Rex::Interface::File->create;
  my $script   = q|
    unlink $0;
    print to_json([ getgrnam($ARGV[0]) ]);
  |;
  $fh->open( ">", $rnd_file );
  $fh->write($script);
  $fh->write( func_to_json() );
  $fh->close;

  my $data_str = i_run "perl $rnd_file $group", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error getting group information");
  }

  Rex::Interface::Fs->create()->unlink($rnd_file);

  my $data = decode_json($data_str);

  return (
    name     => $data->[0],
    password => $data->[1],
    gid      => $data->[2],
    members  => $data->[3],
  );

}

sub rm_group {
  my ( $self, $group ) = @_;

  i_run "pw groupdel $group", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error deleting group $group");
  }
}

1;
