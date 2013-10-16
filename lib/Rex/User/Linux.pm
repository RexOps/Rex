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
use Rex::Commands::MD5;
use Rex::Helper::Run;
use Rex::Commands::Fs;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Interface::Exec;
use Rex::Helper::Path;

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

   my $uid = $self->get_uid($user);

   my $run_cmd = 0;

   if(! defined $uid) {
      Rex::Logger::debug("User $user does not exists. Creating it now.");
      $cmd = "/usr/sbin/useradd ";

      if(exists $data->{system}) {
         $cmd .= " -r";
      }

      $run_cmd = 1;
   }
   else {
      # only the user should be there, no modifications. 
      # so just return
      if(! defined $data) {
         if(Rex::Config->get_do_reporting) {
            return {
               changed => 0,
               uid     => $uid,
            };
         }

         return $uid;
      }

      Rex::Logger::debug("User $user already exists. Updating...");

      if(exists $data->{uid} && $data->{uid} == $uid) {
         delete $data->{uid};
      }

      $cmd = "/usr/sbin/usermod ";
   }

   if(exists $data->{non_uniq}) { 
      $cmd .= " -o ";
      $run_cmd = 1;
   }

   if(exists $data->{uid}) {
      $cmd .= " --uid " . $data->{uid};
      $run_cmd = 1;
   }

   if(exists $data->{home}) {
      $run_cmd = 1;
      $cmd .= " -d " . $data->{home};

      if(
         (exists $data->{"no-create-home"} && $data->{"no-create-home"})
            ||
         (exists $data->{"no_create_home"} && $data->{"no_create_home"})
        ) {
         if(! $self->get_uid($user)) {
            $cmd .= " -M";
         }
      }
      elsif(!is_dir($data->{home})) {
         $cmd .= " -m";
      }
   }

   if(exists $data->{shell}) {
      $run_cmd = 1;
      $cmd .= " --shell " . $data->{shell};
   }

   if(exists $data->{comment}) {
      $run_cmd = 1;
      $cmd .= " --comment '" . $data->{comment} . "'";
   }

   if(exists $data->{expire}) {
      $run_cmd = 1;
      $cmd .= " --expiredate '" . $data->{expire} . "'";
   }

   if(exists $data->{groups}) {
      $run_cmd = 1;
      my @groups = @{$data->{groups}};
      my $pri_group = shift @groups;

      $cmd .= " --gid $pri_group";

      if(@groups) {
         $cmd .= " --groups " . join(",", @groups);
      }
   }

   my $old_pw_md5 = md5("/etc/passwd");
   my $old_sh_md5 = md5("/etc/shadow");


   # only run the cmd if needed
   if($run_cmd) {
      my $rnd_file = get_tmp_file;
      my $fh = Rex::Interface::File->create;
      $fh->open(">", $rnd_file);
      $fh->write("$cmd $user\nexit \$?\n");
      $fh->close;

      i_run "/bin/sh $rnd_file";
      if($? == 0) {
         Rex::Logger::debug("User $user created/updated.");
      }
      else {
         Rex::Logger::info("Error creating/updating user $user", "warn");
         die("Error creating/updating user $user");
      }

      Rex::Interface::Fs->create()->unlink($rnd_file);
   }

   if(exists $data->{password}) {
      my $rnd_file = get_tmp_file;
      my $fh = Rex::Interface::File->create;
      $fh->open(">", $rnd_file);
      $fh->write("/bin/echo -e '" . $data->{password} . "\\n" . $data->{password} . "' | /usr/bin/passwd $user\nexit \$?\n");
      $fh->close;

      Rex::Logger::debug("Changing password of $user.");
      i_run "/bin/sh $rnd_file";
      if($? != 0) {
         die("Error setting password for $user");
      }

      Rex::Interface::Fs->create()->unlink($rnd_file);
   }

   if(exists $data->{crypt_password} && $data->{crypt_password}) {
      my $rnd_file = get_tmp_file;
      my $fh = Rex::Interface::File->create;
      $fh->open(">", $rnd_file);
      $fh->write("usermod -p '" . $data->{crypt_password} . "' $user\nexit \$?\n");
      $fh->close;

      Rex::Logger::debug("Setting encrypted password of $user");
      i_run "/bin/sh $rnd_file";
      if($? != 0) {
         die("Error setting password for $user");
      }

      Rex::Interface::Fs->create()->unlink($rnd_file);
   }

   my $new_pw_md5 = md5("/etc/passwd");
   my $new_sh_md5 = md5("/etc/shadow");

   if(Rex::Config->get_do_reporting) {
      if($new_pw_md5 eq $old_pw_md5 && $new_sh_md5 eq $old_sh_md5) {
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
      }
   }

   return $self->get_uid($user);

}

sub rm_user {
   my ($self, $user, $data) = @_;

   Rex::Logger::debug("Removing user $user");

   my $cmd = "/usr/sbin/userdel";

   if(exists $data->{delete_home}) {
      $cmd .= " --remove";
   }

   if(exists $data->{force}) {
      $cmd .= " --force";
   }

   i_run $cmd . " " . $user;
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
   my $rnd_file = get_tmp_file;
   my $fh = Rex::Interface::File->create;
   $fh->open(">", $rnd_file);
   $fh->write(q|use Data::Dumper; $exe = "/usr/bin/groups"; if(! -x $exe) { $exe = "/bin/groups"; } print Dumper [  map {chomp; $_ =~ s/^[^:]*:\s*(.*)\s*$/$1/; split / /, $_}  qx{$exe $ARGV[0]} ];|);
   $fh->close;

   my $data_str = i_run "perl $rnd_file $user";
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
   my $rnd_file = get_tmp_file;
   my $fh = Rex::Interface::File->create;
   $fh->open(">", $rnd_file);
   $fh->write(q|use Data::Dumper; print Dumper [ map {chomp; $_ =~ s/^([^:]*):.*$/$1/; $_}  qx{/usr/bin/getent passwd} ];|);
   $fh->close;

   my $data_str = i_run "perl $rnd_file";
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
   my $rnd_file = get_tmp_file;
   my $fh = Rex::Interface::File->create;
   $fh->open(">", $rnd_file);
   $fh->write(q|use Data::Dumper; print Dumper [ getpwnam($ARGV[0]) ];|);
   $fh->close;

   my $data_str = i_run "perl $rnd_file $user";
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

   my $gid = $self->get_gid($group);

   if(! defined $gid) {
      Rex::Logger::debug("Creating new group $group");

      $cmd = "/usr/sbin/groupadd ";
   }
   elsif(exists $data->{gid} && $data->{gid} == $gid) {
      if(Rex::Config->get_do_reporting) {
         return {
            changed => 0,
            ret     => $gid,
         };
      }
      return $gid;
   }
   else {
      if(! defined $data) {
         if(Rex::Config->get_do_reporting) {
            return {
               changed => 0,
               ret     => $gid,
            };
         }

         return $gid;
      }
      Rex::Logger::debug("Group $group already exists. Updating...");
      $cmd = "/usr/sbin/groupmod ";
   }

   if(exists $data->{gid}) {
      $cmd .= " -g " . $data->{gid};
      $gid = undef;
   }

   i_run $cmd . " " . $group;
   if($? != 0) {
      die("Error creating/modifying group $group");
   }

   if(defined $gid) {
      return $gid;
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
   my @data = split(" ", "" . i_run("perl -le 'print join(\" \", getgrnam(\$ARGV[0]));' '$group'"), 4);
   if($? != 0) {
      die("Error getting group information");
   }

   return (
      name => $data[0],
      password => $data[1],
      gid => $data[2],
      members => $data[3],
   );
}

sub rm_group {
   my ($self, $group) = @_;

   i_run "/usr/sbin/groupdel $group";
   if($? != 0) {
      die("Error deleting group $group");
   }
}


1;
