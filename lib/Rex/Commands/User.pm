#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::User

=head1 DESCRIPTION

With this module you can manage user and groups.

=head1 SYNOPSIS

 task "create-user", "remoteserver", sub {
    create_user "root" => {
       uid => 0,
       home => '/root',
       commenct => 'Root Account',
       expire => '2011-05-30',
       groups  => 'root',
       password => 'blahblah',
       system => 1,
    };
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::User;

use strict;
use warnings;

require Exporter;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Logger;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(create_user delete_user get_uid get_user
               create_group delete_group get_group get_gid
               );

=item create_user($user => {})

Create or update a user.

=cut

sub create_user {
   my ($user, $data) = @_;

   my $cmd;


   if(! defined get_uid($user)) {
      Rex::Logger::debug("User $user does not exists. Creating it now.");
      $cmd = "useradd ";

      if(exists $data->{system}) {
         $cmd .= " -r";
      }
   }
   else {
      Rex::Logger::debug("User $user already exists. Updating...");

      $cmd = "usermod ";
   }

   if(exists $data->{uid}) {
      $cmd .= " --uid " . $data->{uid};
   }

   if(exists $data->{home}) {
      $cmd .= " -d " . $data->{home};

      if(!is_dir($data->{home})) {
         $cmd .= " -m";
      }
   }

   if(exists $data->{comment}) {
      $cmd .= " --comment '" . $data->{comment} . "'";
   }

   if(exists $data->{expire}) {
      $cmd .= " --expiredate '" . $data->{expiredate} . "'";
   }

   if(exists $data->{groups}) {
      my @groups = @{$data->{groups}};
      my $pri_group = shift @groups;

      $cmd .= " --gid $pri_group";

      if(@groups) {
         $cmd .= " --groups " . join(",", @groups);
      }
   }
 
   run "$cmd $user";
   if($? == 0) {
      Rex::Logger::debug("User $user created/updated.");
   }
   else {
      Rex::Logger::info("Error creating/updating user $user");
      return -1;
   }

   if(exists $data->{password}) {
      Rex::Logger::debug("Changing password of $user.");
      run "echo '$user:" . $data->{password} . "' | chpasswd";
   }

   return get_uid($user);
}

=item get_uid($user)

Returns the uid of $user.

=cut

sub get_uid {
   my ($user) = @_;

   my %data = get_user($user);
   return $data{uid};
}

=item get_user($user)

Returns all information about $user.

=cut

sub get_user {
   my ($user) = @_;

   Rex::Logger::debug("Getting information for $user");
   my $data_str = run "perl -MData::Dumper -le'print Dumper [ getpwnam(\"$user\") ]'";

   my $data;
   {
      no strict;
      $data = eval $data_str;
      use strict;
   }

   return ( 
      name => $data->[0],
      password => $data->[1],
      uid => $data->[2],
      gid => $data->[3],
      comment => $data->[5],
      home => $data->[7],
      shell => $data->[8],
      expire => exists $data->[9]?$data->[9]:0,
   );
}


=item delete_user($user)

Delete a user from the system.

 delete_user "trak", {
    delete_home => 1,
    force       => 1,
 };

=cut

sub delete_user {
   my ($user, $data) = @_;

   Rex::Logger::debug("Removing user $user");

   my $cmd = "userdel";

   if(exists $data->{delete_home}) {
      $cmd .= " --remove";
   }

   if(exists $data->{force}) {
      $cmd .= " --force";
   }

   run $cmd . " " . $user;
   return $?==0?1:0;
}

=item create_group($group, {})

Create or update a group.

 create_group $group, {
    gid => 1500,
    system => 1,
 };

=cut

sub create_group {
   my ($group, $data) = @_;

   my $cmd;

   if(! defined get_gid($group)) {
      Rex::Logger::debug("Creating new group $group");

      $cmd = "groupadd ";
   }
   else {
      Rex::Logger::debug("Group $group already exists. Updating...");
      $cmd = "groupmod ";
   }
   
   if(exists $data->{gid}) {
      $cmd .= " -g " . $data->{gid};
   }

   run $cmd . " " . $group;

   return get_gid($group);
}

=item get_gid($group)

Return the group id of $group.

=cut

sub get_gid {
   my ($group) = @_;

   my %data = get_group($group);
   return $data{gid};
}

=item get_group($group)

Return information of $group.

 $info = get_group("wheel");

=cut

sub get_group {
   my ($group) = @_;

   Rex::Logger::debug("Getting information for $group");
   my $data_str = run "perl -MData::Dumper -le'print Dumper [ getgrnam(\"$group\") ]'";

   my $data;
   {
      no strict;
      $data = eval $data_str;
      use strict;
   }

   return (
      name => $data->[0],
      password => $data->[1],
      gid => $data->[2],
      members => $data->[3],
   );
}

=item delete_group($group)

Delete a group.

=cut

sub delete_group {
   my ($group) = @_;

   run "groupdel $group";

   return $?==0?1:0;
}

=back
=cut

1;
