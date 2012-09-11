#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::User::Linux;

use strict;
use warnings;

use Rex::Logger;
require Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Interface::Exec;

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

   if(exists $data->{non_uniq}) { 
      $cmd .= " -o ";
   }

   if(exists $data->{uid}) {
      $cmd .= " --uid " . $data->{uid};
   }

   if(exists $data->{home}) {
      $cmd .= " -d " . $data->{home};

      if(exists $data->{"no-create-home"} || exists $data->{"no_create_home"}) {
         $cmd .= " -M";
      }
      elsif(!is_dir($data->{home})) {
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

   my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
   my $fh = Rex::Interface::File->create;
   $fh->open(">", $rnd_file);
   $fh->write("$cmd $user\nexit \$?\n");
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
      $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
      $fh = Rex::Interface::File->create;
      $fh->open(">", $rnd_file);
      $fh->write("echo '$user:" . $data->{password} . "' | chpasswd\nexit \$?\n");
      $fh->close;

      Rex::Logger::debug("Changing password of $user.");
      run "/bin/sh $rnd_file";
      if($? != 0) {
         die("Error setting password for $user");
      }

      Rex::Interface::Fs->create()->unlink($rnd_file);
   }

   if(exists $data->{crypt_password}) {
      $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
      $fh = Rex::Interface::File->create;
      $fh->open(">", $rnd_file);
      $fh->write("usermod -p '" . $data->{crypt_password} . "' $user\nexit \$?\n");
      $fh->close;

      Rex::Logger::debug("Setting encrypted password of $user");
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

sub user_groups {
   my ($self, $user) = @_;

   Rex::Logger::debug("Getting group membership of $user");
   my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
   my $fh = Rex::Interface::File->create;
   $fh->open(">", $rnd_file);
   $fh->write(q|use Data::Dumper; print Dumper [  map {chomp; $_ =~ s/^[^:]*:\s*(.*)\s*$/$1/; split / /, $_}  qx/groups $ARGV[0]/ ];|);
   $fh->close;

   my $data_str = run "perl $rnd_file $user";
   if($? != 0) {
      die("Error getting  user list");
   }

   Rex::Interface::Fs->create()->unlink($rnd_file);

   my $data;
   {
      no strict;
      $data = eval $data_str;
      use strict;
   }

   my $wantarray = wantarray();

   if(defined $wantarray && ! $wantarray) {
      # arrayref
      return $data;
   }

   return @{ $data };
}

sub user_list {
   my $self = shift;

   Rex::Logger::debug("Getting user list");
   my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".u.tmp";
   my $fh = Rex::Interface::File->create;
   $fh->open(">", $rnd_file);
   $fh->write(q|use Data::Dumper; print Dumper [ map {chomp; $_ =~ s/^([^:]*):.*$/$1/; $_}  qx/getent passwd/ ];|);
   $fh->close;

   my $data_str = run "perl $rnd_file";
   if($? != 0) {
      die("Error getting  user list");
   }

   Rex::Interface::Fs->create()->unlink($rnd_file);

   my $data;
   {
      no strict;
      $data = eval $data_str;
      use strict;
   }

   return @$data;
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

   run "groupdel $group";
   if($? != 0) {
      die("Error deleting group $group");
   }
}


1;
