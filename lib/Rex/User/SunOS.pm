#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::User::SunOS;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::User::OpenBSD;

use base qw(Rex::User::OpenBSD);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $that->SUPER::new(@_);

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
      $cmd .= " -u " . $data->{uid};
   }

   if(exists $data->{home}) {
      $cmd .= " -d " . $data->{home};

      if(!is_dir($data->{home})) {
         $cmd .= " -m";
      }
   }

   if(exists $data->{comment}) {
      $cmd .= " -c '" . $data->{comment} . "'";
   }

   if(exists $data->{expire}) {
      $cmd .= " -e '" . $data->{expiredate} . "'";
   }

   if(exists $data->{groups}) {
      my @groups = @{$data->{groups}};
      my $pri_group = shift @groups;

      $cmd .= " -g $pri_group";

      if(@groups) {
         $cmd .= " -G " . join(",", @groups);
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
      if(Rex::get_cache()->can_run("/usr/local/bin/expect")) {
         my $fh = file_write "/tmp/chpasswd";
         $fh->write(qq~#!/usr/local/bin/expect --
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
~);
         $fh->close;

         chmod 700, "/tmp/chpasswd";
         run "/tmp/chpasswd $user '" . $data->{"password"} . "'";

         rm "/tmp/chpasswd";
      }
      else {
         die("No expect found in /usr/local/bin. Can't set user password.");
      }
   }

   return $self->get_uid($user);

}

1;
