#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Exec::Sudo;
   
use strict;
use warnings;

use Rex::Config;
use Rex::Interface::Exec::Local;
use Rex::Interface::Exec::SSH;
use Rex::Helper::Encode;
use Rex::Interface::File::Local;
use Rex::Interface::File::SSH;

use Rex::Commands;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub exec {
   my ($self, $cmd, $path, $option) = @_;

   if(exists $option->{cwd}) {
      $cmd = "cd " . $option->{cwd} . " && $cmd";
   }

   if($path) { $path = "PATH=$path" }
   $path ||= "";

   my ($exec, $file);
   if(Rex::is_ssh()) {
      $exec = Rex::Interface::Exec->create("SSH");
      $file = Rex::Interface::File->create("SSH");
   }
   else {
      $exec = Rex::Interface::Exec->create("Local");
      $file = Rex::Interface::File->create("Local");
   }

   my $sudo_password = task->get_sudo_password;
   my $enc_pw;
   my $random_file = "";

   if($sudo_password) {
      my $random_string = get_random(length($sudo_password), 'a' .. 'z');
      my $crypt = $sudo_password ^ $random_string;

      $random_file = "/tmp/" . get_random(16, 'a' .. 'z') . ".sudo.tmp";

      $file->open('>', $random_file);
      $file->write(<<EOF);
#!/usr/bin/perl
unlink \$0;

for (0..255) {
  \$escapes{chr(\$_)} = sprintf("%%%02X", \$_);
}

my \$txt = \$ARGV[0];

\$txt=~ s/%([0-9A-Fa-f]{2})/chr(hex(\$1))/eg;

my \$rnd = '$random_string';
print \$txt ^ \$rnd;
print "\\n"

EOF


      $file->close;


      $enc_pw = Rex::Helper::Encode::url_encode($crypt);
   }
   else {
      $enc_pw = "";
   }

   my $locales = "LC_ALL=C";

   my $sudo_options = Rex::get_current_connection()->{sudo_options};
   my $sudo_options_str = "";
   if(exists $sudo_options->{user}) {
      $sudo_options_str .= " -u " . $sudo_options->{user};
   }

   if(Rex::Config->get_sudo_without_locales()) {
      Rex::Logger::debug("Using sudo without locales. If the locale is NOT C or en_US it will break many things!");
      $locales = "";
   }
   
   if(Rex::Config->get_sudo_without_sh()) {
      Rex::Logger::debug("Using sudo without sh will break things like file editing.");
      if($enc_pw) {
         return $exec->exec("perl $random_file '$enc_pw' | sudo $sudo_options_str -p '' -S $locales $cmd");
      }
      else {
         return $exec->exec("sudo $sudo_options_str $locales $cmd");
      }
   }
   else {
      my $new_cmd = "$locales $path $cmd";

      # escape some special shell things
      $new_cmd =~ s/\\/\\\\/gms;
      $new_cmd =~ s/"/\\"/gms;
      $new_cmd =~ s/\$/\\\$/gms;

      if(Rex::Config->get_source_global_profile) {
         $new_cmd = ". /etc/profile; $new_cmd";
      }

      if($enc_pw) {
         return $exec->exec("perl $random_file '$enc_pw' | sudo $sudo_options_str -p '' -S sh -c \"$new_cmd\"");
      }
      else {
         return $exec->exec("sudo $sudo_options_str -p '' -S sh -c \"$new_cmd\"");
      }

   }
}

1;


