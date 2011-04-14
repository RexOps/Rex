#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Rsync;

use strict;
use warnings;

use Expect;

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(sync);


sub sync {
   my ($source, $dest, $opt) = @_;

   my $current_connection = Rex::get_current_connection();
   my $cmd;

   if($opt && exists $opt->{'download'} && $opt->{'download'} == 1) {
      Rex::Logger::debug("Downloading $source -> $dest");
      $cmd = "rsync -a -e '\%s' --verbose --stats " . Rex::Config->get_user . "\@" . $current_connection->{"server"} . ":"
                     . $source . " " . $dest;
   }
   else {
      Rex::Logger::debug("Uploading $source -> $dest");
      $cmd = "rsync -a -e '\%s' --verbose --stats $source " . Rex::Config->get_user . "\@" . $current_connection->{"server"} . ":"
                     . $dest;
   }

   my $pass = Rex::Config->get_password;
   my @expect_options = ();

   if(Rex::Config->get_password_auth) {
      $cmd = sprintf($cmd, 'ssh');
      push(@expect_options, [
                              qr{password: $},
                              sub {
                                 Rex::Logger::debug("Want Password");
                                 my $fh = shift;
                                 $fh->send($pass . "\n");
                                 exp_continue;
                              }
                           ]
      
      );
   }
   else {
      $cmd = sprintf($cmd, 'ssh -i ' . Rex::Config->get_private_key);
      push(@expect_options, [
                              qr{Enter passphrase for key.*: $},
                              sub {
                                 Rex::Logger::debug("Want Passphrase");
                                 my $fh = shift;
                                 $fh->send($pass . "\n");
                                 exp_continue;
                              }
                           ]
      );
   }

   Rex::Logger::debug("cmd: $cmd");

   eval {
      my $exp = Expect->spawn($cmd) or die($!);

      my $login_task = shift @expect_options;

      eval {
         $exp->expect(Rex::Config->get_timeout, $login_task, [
                                 qr{total size is \d+\s+speedup is },
                                 sub {
                                    Rex::Logger::debug("Finished transfer very fast");
                                    exp_continue;
                                    die;
                                 }
                             
                              ]);

         $exp->expect(undef, [
                           qr{total size is \d+\s+speedup is },
                           sub {
                              Rex::Logger::debug("Finished transfer");
                              exp_continue;
                           }
                        ]);

      };

      $exp->soft_close;
   };

   if($@) {
      Rex::Logger::info($@);
   }

}


1;
