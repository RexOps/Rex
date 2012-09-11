#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::User - Manipulate users and groups

=head1 DESCRIPTION

With this module you can manage user and groups.

=head1 SYNOPSIS

 task "create-user", "remoteserver", sub {
    create_user "root",
       uid => 0,
       home => '/root',
       comment => 'Root Account',
       expire => '2011-05-30',
       groups  => ['root', '...'],
       password => 'blahblah',
       system => 1,
       no_create_home => TRUE,
       ssh_key => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQChUw...";
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::User;

use strict;
use warnings;

require Rex::Exporter;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Logger;
use Rex::User;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(create_user delete_user get_uid get_user user_list
               user_groups create_group delete_group get_group get_gid
               );

=item create_user($user => {})

Create or update a user.

=cut

sub create_user {
   my ($user, @_data) = @_;

   my $data = {};

   if(! ref($_data[0])) {
      $data = { @_data };
   }
   else {
      $data = $_data[0];
   }

   my $uid = Rex::User->get()->create_user($user, $data);

   if(defined $data->{"ssh_key"} && ! defined $data->{"home"}) {
      Rex::Logger::debug("If ssh_key option is used you have to specify home, too.");
      die("If ssh_key option is used you have to specify home, too.");
   }

   if(defined $data->{"ssh_key"}) {

      if(
            ! ( exists $data->{"no-create-home"} && $data->{"no-create-home"} )

            && 

            ! ( exists $data->{"no_create_home"} && $data->{"no_create_home"} )

            &&
      
            ! is_dir($data->{"home"} . "/.ssh")
        ) {

         eval {
            mkdir $data->{"home"} . "/.ssh",
               owner => $user,
               mode  => 700,
               not_recursive => 1;
         } or do {
            # error creating .ssh directory
            Rex::Logger::debug("Not creating .ssh directory because parent doesn't exists.");
         };
      }

      if(is_dir($data->{"home"} . "/.ssh")) {

         file $data->{"home"} . "/.ssh/authorized_keys",
            content => $data->{"ssh_key"},
            owner   => $user,
            mode    => 600;

      }

   }

   return $uid;
}

=item get_uid($user)

Returns the uid of $user.

=cut

sub get_uid {
   Rex::User->get()->get_uid(@_);
}

=item get_user($user)

Returns all information about $user.

=cut

sub get_user {
   Rex::User->get()->get_user(@_);
}

=item user_group($user)

Returns group membership about $user.

=cut

sub user_groups {
   Rex::User->get()->user_groups(@_);
}

=item list_user()

Returns user list via getent passwd

=cut

sub user_list {
   Rex::User->get()->user_list(@_);
}


=item delete_user($user)

Delete a user from the system.

 delete_user "trak", {
    delete_home => 1,
    force       => 1,
 };

=cut

sub delete_user {
   my ($user, @_data) = @_;

   my $data = {};

   if(! ref($_data[0])) {
      $data = { @_data };
   }
   else {
      $data = $_data[0];
   }

   Rex::User->get()->rm_user($user, $data);
}

=item create_group($group, {})

Create or update a group.

 create_group $group, {
    gid => 1500,
    system => 1,
 };

=cut

sub create_group {
   Rex::User->get()->create_group(@_);
}

=item get_gid($group)

Return the group id of $group.

=cut

sub get_gid {
   Rex::User->get()->get_gid(@_);
}

=item get_group($group)

Return information of $group.

 $info = get_group("wheel");

=cut

sub get_group {
   Rex::User->get()->get_group(@_);
}

=item delete_group($group)

Delete a group.

=cut

sub delete_group {
   Rex::User->get()->rm_group(@_);
}

=back

=cut

1;
