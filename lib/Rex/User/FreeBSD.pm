#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::User::FreeBSD;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Interface::Exec;
use Rex::User::Linux;

use base qw(Rex::User::Linux);

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
      $cmd = "pw useradd ";
   }
   else {
      Rex::Logger::debug("User $user already exists. Updating...");
      $cmd = "pw usermod ";
   }

   if($data->{"uid"}) {
      $cmd .= " -u " . $data->{"uid"}
   }

   if($data->{"home"}) {
      $cmd .= " -d " . $data->{"home"};
      
      if(
         ! (
            (exists $data->{"no-create-home"} && $data->{"no-create-home"})
               ||
            (exists $data->{"no_create_home"} && $data->{"no_create_home"})
         )
        ) {
         $cmd .= " -m ";
      }

   }

   if($data->{"comment"}) {
      $cmd .= " -c \"" . $data->{"comment"} . "\" ";
   }

   if($data->{"expire"}) {
      $cmd .= " -e " . $data->{"expire"};
   }

   if($data->{"groups"}) {
      my @groups = @{$data->{groups}};
      $cmd .= " -g " . $groups[0];
      $cmd .= " -G " . join(",", @groups);
   }

   my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
   my $fh = Rex::Interface::File->create;
   $fh->open(">", $rnd_file);
   $fh->write("$cmd -n $user\nexit \$?\n");
   $fh->close;

   run "/bin/sh $rnd_file";
   if($? == 0) {
      Rex::Logger::debug("User $user created/updated.");
   }
   else {
      Rex::Logger::info("Error creating/updating user $user", "warn");
      die("Error creating/updating user $user");
   }

   Rex::Interface::Fs->create()->unlink($rnd_file);

   if(exists $data->{password}) {
      Rex::Logger::debug("Changing password of $user.");

      $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
      $fh = Rex::Interface::File->create;
      $fh->open(">", $rnd_file);
      $fh->write("echo '".$data->{password} . "' | pw usermod $user -h 0\nexit \$?\n");
      $fh->close;

      run "/bin/sh $rnd_file";
      if($? != 0) {
         die("Error setting password for $user");
      }

      Rex::Interface::Fs->create()->unlink($rnd_file);
   }

   return $self->get_uid($user);

}

sub rm_user {
   my ($self, $user, $data) = @_;

   Rex::Logger::debug("Removing user $user");

   my $cmd = "pw userdel";

   if(exists $data->{delete_home}) {
      $cmd .= " -r ";
   }

   run $cmd . " -n " . $user;
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
   my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
   my $fh = Rex::Interface::File->create;
   $fh->open(">", $rnd_file);
   $fh->write(q|use Data::Dumper; print Dumper [ getpwnam($ARGV[0]) ];|);
   $fh->close;

   my $data_str = run "perl $rnd_file $user";
   if($? != 0) {
      die("Error getting  user information for $user");
   }

   Rex::Interface::Fs->create()->unlink($rnd_file);

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

      $cmd = "pw groupadd ";
   }
   else {
      Rex::Logger::debug("Group $group already exists. Updating...");
      $cmd = "pw groupmod ";
   }
   
   if(exists $data->{gid}) {
      $cmd .= " -g " . $data->{gid};
   }

   run $cmd . " -n " . $group;
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
   my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
   my $fh = Rex::Interface::File->create;
   $fh->open(">", $rnd_file);
   $fh->write(q|use Data::Dumper; print Dumper [ getgrnam($ARGV[0]) ];|);
   $fh->close;

   my $data_str = run "perl $rnd_file $group";
   if($? != 0) {
      die("Error getting group information");
   }

   Rex::Interface::Fs->create()->unlink($rnd_file);

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

   run "pw groupdel $group";
   if($? != 0) {
      die("Error deleting group $group");
   }
}


1;
