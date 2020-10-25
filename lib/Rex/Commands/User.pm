#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::User - Manipulate users and groups

=head1 DESCRIPTION

With this module you can manage user and groups.

=head1 SYNOPSIS

 use Rex::Commands::User;
 
 task "create-user", "remoteserver", sub {
   create_user "root",
     uid         => 0,
     home        => '/root',
     comment     => 'Root Account',
     expire      => '2011-05-30',
     groups      => [ 'root', '...' ],
     password    => 'blahblah',
     system      => 1,
     create_home => TRUE,
     shell       => '/bin/bash',
     ssh_key     => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQChUw...";
 };

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::User;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Rex::Exporter;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Logger;
use Rex::User;
use Rex::Hook;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(create_user delete_user get_uid get_user user_list
  user_groups create_group delete_group get_group get_gid
  account lock_password unlock_password
);

=head2 account($name, %option)

Manage user account.

 account "krimdomu",
   ensure         => "present",  # default
   uid            => 509,
   home           => '/root',
   comment        => 'User Account',
   expire         => '2011-05-30',
   groups         => [ 'root', '...' ],
   login_class    => 'staff',   # on OpenBSD
   password       => 'blahblah',
   crypt_password => '*', # on Linux, OpenBSD and NetBSD
   system         => 1,
   create_home    => TRUE,
   shell          => '/bin/bash',
   ssh_key        => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQChUw...";

There is also a no_create_home option similar to create_home but doing the
opposite. If both used, create_home takes precedence as it the preferred option
to specify home directory creation policy.

If none of them are specified, Rex follows the remote system's home creation
policy.

The crypt_password option specifies the encrypted value as found in
/etc/shadow; on Linux special values are '*' and '!' which mean
'disabled password' and 'disabled login' respectively.

=cut

sub account {
  my ( $name, %option ) = @_;

  if ( !ref $name ) {
    $name = [$name];
  }

  $option{ensure} ||= "present";

  for my $n ( @{$name} ) {
    Rex::get_current_connection()->{reporter}
      ->report_resource_start( type => "account", name => $n );

    my $real_name = $n;
    if ( exists $option{name} ) {
      $real_name = $option{name};
    }

    if ( exists $option{ensure} && $option{ensure} eq "present" ) {
      delete $option{ensure};
      my $data = &create_user( $real_name, %option, __ret_changed => 1 );
      Rex::get_current_connection()->{reporter}
        ->report( changed => $data->{changed}, );
    }
    elsif ( exists $option{ensure} && $option{ensure} eq "absent" ) {
      &delete_user($real_name);
      Rex::get_current_connection()->{reporter}->report( changed => 1, );
    }

    Rex::get_current_connection()->{reporter}
      ->report_resource_end( type => "account", name => $n );
  }
}

=head2 create_user($user => {})

Create or update a user.

This function supports the following L<hooks|Rex::Hook>:

=over 4

=item before

This gets executed before the user is created. All original parameters are passed to it.

=item after

This gets executed after the user is created. All original parameters, and the user's C<UID> are passed to it.

=back

=cut

sub create_user {
  my ( $user, @_data ) = @_;

  #### check and run before hook
  eval {
    my @new_args = Rex::Hook::run_hook( create_user => "before", @_ );
    if (@new_args) {
      ( $user, @_data ) = @new_args;
    }
    1;
  } or do {
    die("Before-Hook failed. Canceling create_user() action: $@");
  };
  ##############################

  my $data = {};

  if ( !ref( $_data[0] ) ) {
    $data = {@_data};
  }
  else {
    $data = $_data[0];
  }

  my $uid = Rex::User->get()->create_user( $user, $data );

  if ( defined $data->{"ssh_key"} && !defined $data->{"home"} ) {
    Rex::Logger::debug(
      "If ssh_key option is used you have to specify home, too.");
    die("If ssh_key option is used you have to specify home, too.");
  }

  if ( defined $data->{"ssh_key"} ) {

    if ( !is_dir( $data->{"home"} . "/.ssh" ) ) {

      eval {
        mkdir $data->{"home"} . "/.ssh",
          owner         => $user,
          mode          => 700,
          not_recursive => 1;
      } or do {

        # error creating .ssh directory
        Rex::Logger::debug(
          "Not creating .ssh directory because parent doesn't exists.");
      };
    }

    if ( is_dir( $data->{"home"} . "/.ssh" ) ) {

      file $data->{"home"} . "/.ssh/authorized_keys",
        content => $data->{"ssh_key"},
        owner   => $user,
        mode    => 600;

    }

  }

  #### check and run before hook
  Rex::Hook::run_hook( create_user => "after", @_, $uid );
  ##############################

  if ( $data->{__ret_changed} ) {
    return $uid;
  }

  return $uid->{ret};
}

=head2 get_uid($user)

Returns the uid of $user.

=cut

sub get_uid {
  Rex::User->get()->get_uid(@_);
}

=head2 get_user($user)

Returns all information about $user.

=cut

sub get_user {
  Rex::User->get()->get_user(@_);
}

=head2 user_groups($user)

Returns group membership about $user.

=cut

sub user_groups {
  Rex::User->get()->user_groups(@_);
}

=head2 user_list()

Returns user list via getent passwd.

 task "list_user", "server01", sub {
   for my $user (user_list) {
     print "name: $user / uid: " . get_uid($user) . "\n";
   }
 };

=cut

sub user_list {
  Rex::User->get()->user_list(@_);
}

=head2 delete_user($user)

Delete a user from the system.

 delete_user "trak", {
   delete_home => 1,
   force     => 1,
 };

=cut

sub delete_user {
  my ( $user, @_data ) = @_;

  my $data = {};

  if ( !ref( $_data[0] ) ) {
    $data = {@_data};
  }
  else {
    $data = $_data[0];
  }

  Rex::User->get()->rm_user( $user, $data );
}

=head2 lock_password($user)

Lock the password of a user account. Currently this is only
available on Linux (see passwd --lock) and OpenBSD.

=cut

sub lock_password {
  Rex::User->get()->lock_password(@_);
}

=head2 unlock_password($user)

Unlock the password of a user account. Currently this is only
available on Linux (see passwd --unlock) and OpenBSD.

=cut

sub unlock_password {
  Rex::User->get()->unlock_password(@_);
}

# internal wrapper for resource style calling
# will be called from Rex::Commands::group() function
sub group_resource {
  my @params = @_;

  my $name   = shift @params;
  my %option = @params;

  if ( ref $name ne "ARRAY" ) {
    $name = [$name];
  }
  $option{ensure} ||= "present";

  for my $group_name ( @{$name} ) {

    Rex::get_current_connection()->{reporter}
      ->report_resource_start( type => "group", name => $group_name );

    my $gid = get_gid($group_name);

    if ( $option{ensure} eq "present" ) {
      if ( !defined $gid ) {
        Rex::Commands::User::create_group( $group_name, %option );
      }
    }
    elsif ( $option{ensure} eq "absent" ) {
      if ( defined $gid ) {
        Rex::Commands::User::delete_group($group_name);
      }
    }
    else {
      die "Unknown 'ensure' value. Valid values are 'present' and 'absent'.";
    }

    Rex::get_current_connection()->{reporter}
      ->report_resource_end( type => "group", name => $group_name );
  }
}

=head2 create_group($group, {})

Create or update a group.

 create_group $group, {
   gid => 1500,
   system => 1,
 };

=cut

sub create_group {
  my $group = shift;
  my @params;

  if ( !ref $_[0] ) {
    push @params, {@_};
  }
  else {
    push @params, @_;
  }

  Rex::User->get()->create_group( $group, @params );
}

=head2 get_gid($group)

Return the group id of $group.

=cut

sub get_gid {
  Rex::User->get()->get_gid(@_);
}

=head2 get_group($group)

Return information of $group.

 $info = get_group("wheel");

=cut

sub get_group {
  Rex::User->get()->get_group(@_);
}

=head2 delete_group($group)

Delete a group.

=cut

sub delete_group {
  Rex::User->get()->rm_group(@_);
}

1;
