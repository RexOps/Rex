#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::User::Linux;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Commands::Fs;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub create_user {
   my ($self, $user, $data) = @_;

   my $cmd;


   if(! defined $self->get_uid($user)) {
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
      die("Error creating/updating user $user");
   }

   if(exists $data->{password}) {
      Rex::Logger::debug("Changing password of $user.");
      run "echo '$user:" . $data->{password} . "' | chpasswd";
      if($? != 0) {
         die("Error setting password for $user");
      }
   }

   if(exists $data->{crypt_password}) {
      Rex::Logger::debug("Setting encrypted password of $user");
      run "usermod -p '" . $data->{crypt_password} . "' $user";
      if($? != 0) {
         die("Error setting password for $user");
      }
   }

   return $self->get_uid($user);

}

sub rm_user {
   my ($self, $user, $data) = @_;

   Rex::Logger::debug("Removing user $user");

   my $cmd = "userdel";

   if(exists $data->{delete_home}) {
      $cmd .= " --remove";
   }

   if(exists $data->{force}) {
      $cmd .= " --force";
   }

   run $cmd . " " . $user;
   if($? != 0) {
      die("Error deleting user $user");
   }

}

sub get_uid {
   my ($self, $user) = @_;

   my %data = $self->get_user($user);
   return $data{uid};
}

sub get_user {
   my ($self, $user) = @_;

   Rex::Logger::debug("Getting information for $user");
   my $data_str = run "perl -MData::Dumper -le'print Dumper [ getpwnam(\"$user\") ]'";
   if($? != 0) {
      die("Error getting  user information for $user");
   }

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

sub create_group {
   my ($self, $group, $data) = @_;

   my $cmd;

   if(! defined $self->get_gid($group)) {
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
   if($? != 0) {
      die("Error creating/modifying group $group");
   }

   return $self->get_gid($group);

}

sub get_gid {
   my ($self, $group) = @_;

   my %data = $self->get_group($group);
   return $data{gid};
}

sub get_group {
   my ($self, $group) = @_;

   Rex::Logger::debug("Getting information for $group");
   my $data_str = run "perl -MData::Dumper -le'print Dumper [ getgrnam(\"$group\") ]'";
   if($? != 0) {
      die("Error getting group information");
   }

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

sub rm_group {
   my ($self, $group) = @_;

   run "groupdel $group";
   if($? != 0) {
      die("Error deleting group $group");
   }
}


1;
