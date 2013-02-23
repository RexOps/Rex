#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::start;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Commands::File;
use Rex::Commands;
use Cwd 'getcwd';

sub execute {
   my ($class, $arg1, %opt) = @_;

   unless($arg1) {
      die("You have to define the vm name!");
   }

   my $dom = $arg1;
   Rex::Logger::debug("starting domain: $dom");

   unless($dom) {
      die("VM $dom not found.");
   }

   my $virt_settings = Rex::Config->get("virtualization");
   my $headless = 0;
   if(ref($virt_settings)) {
      if(exists $virt_settings->{headless} && $virt_settings->{headless}) {
         $headless = 1;
      }
   }

   if($headless) {
      my $filename;

      if(! Rex::is_ssh() && $^O =~ m/^MSWin/) {
         # not connected via ssh, running on windows, use other path
         $filename = get_random(8, 'a' .. 'z') . ".tmp";
      }
      else {
         $filename = "/tmp/" . get_random(8, 'a' .. 'z') . ".tmp";
      }

      file("$filename",
         content => <<EOF);
sub daemonize {
   chdir '/';

   defined(my \$pid = fork) or die "Can't fork: $!";

   exit if \$pid;
   setsid                  or die "Can't start a new session: $!";
   open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";
}

daemonize();

unlink "$filename";
system("VBoxHeadless --startvm \\\"$dom\\\"");


EOF

      run "perl $filename";
   }
   else {
      run "VBoxManage startvm \"$dom\"";
   }

   if($? != 0) {
      die("Error starting vm $dom");
   }

}

1;
