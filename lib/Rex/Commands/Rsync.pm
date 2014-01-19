#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Rsync - Simple Rsync Frontend

=head1 DESCRIPTION

With this module you can sync 2 directories via the I<rsync> command.

=head1 DEPENDENCIES

=over 4

=item Expect

=back

=head1 SYNOPSIS

 use Rex::Commands::Rsync;
 
 sync "dir1", "dir2";

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Rsync;

use strict;
use warnings;

use Expect;
$Expect::Log_Stdout = 0;

require Rex::Exporter;

use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(sync);


=item sync($source, $dest, $opts)

This function executes rsync to sync $source and $dest.

=over 4

=item UPLOAD - Will upload all from the local directory I<html> to the remote directory I</var/www/html>.

 task "sync", "server01", sub {
    sync "html/*", "/var/www/html", {
      exclude => "*.sw*",
      parameters => '--backup --delete',
    };
 };

 task "sync", "server01", sub {
    sync "html/*", "/var/www/html", {
      exclude => ["*.sw*", "*.tmp"],
      parameters => '--backup --delete',
    };
 };

=item DOWNLOAD - Will download all from the remote directory I</var/www/html> to the local directory I<html>.

 task "sync", "server01", sub {
    sync "/var/www/html/*", "html/", {
      download => 1,
      parameters => '--backup',
    };
 };

=back

=cut

sub sync {
   my ($source, $dest, $opt) = @_;

   my $current_connection = Rex::get_current_connection();
   my $server = $current_connection->{server};
   my $cmd;

   my $auth = $current_connection->{conn}->get_auth;


   if(! exists $opt->{download} && $source !~ m/^\//) {
      # relative path, calculate from module root
      $source = Rex::Helper::Path::get_file_path($source, caller());
   }

   Rex::Logger::debug("Syning $source -> $dest with rsync.");
   if($Rex::Logger::debug) {
      $Expect::Log_Stdout = 1;
   }

   my $params = "";
   if($opt && exists $opt->{'exclude'}) {
      my $excludes = $opt->{'exclude'};
      $excludes = [$excludes] unless ref($excludes) eq "ARRAY";
      for my $exclude (@$excludes) {
         $params .= " --exclude=" . $exclude;
      }
   }

   if($opt && exists $opt->{parameters}) {
      $params .= " " . $opt->{parameters};
   }

   if($opt && exists $opt->{'download'} && $opt->{'download'} == 1) {
      Rex::Logger::debug("Downloading $source -> $dest");
      $cmd = "rsync -a -e '\%s' --verbose --stats $params " . $auth->{user} . "\@" . $server . ":"
                     . $source . " " . $dest;
   }
   else {
      Rex::Logger::debug("Uploading $source -> $dest");
      $cmd = "rsync -a -e '\%s' --verbose --stats $params $source " . $auth->{user} . "\@" . $server . ":"
                     . $dest;
   }

   my $pass = $auth->{password};
   my @expect_options = ();

   if($auth->{auth_type} eq "pass") {
      $cmd = sprintf($cmd, 'ssh -o StrictHostKeyChecking=no ');
      push(@expect_options, [
                              qr{Are you sure you want to continue connecting},
                              sub {
                                 Rex::Logger::debug("Accepting key..");
                                 my $fh = shift;
                                 $fh->send("yes\n");
                                 exp_continue;
                              }
                            ],
                            [
                              qr{password: ?$}i,
                              sub {
                                 Rex::Logger::debug("Want Password");
                                 my $fh = shift;
                                 $fh->send($pass . "\n");
                                 exp_continue;
                              }
                           ],
                           [
                                 qr{rsync error: error in rsync protocol},
                                 sub {
                                    Rex::Logger::debug("Error in rsync");
                                    die;
                                 }
                           ],

      
      );
   }
   else {
      $cmd = sprintf($cmd, 'ssh -i ' . $server->get_private_key . " -o StrictHostKeyChecking=no ");
      push(@expect_options, [
                              qr{Are you sure you want to continue connecting},
                              sub {
                                 Rex::Logger::debug("Accepting key..");
                                 my $fh = shift;
                                 $fh->send("yes\n");
                                 exp_continue;
                              }
                            ],
                            [
                              qr{password: ?$}i,
                              sub {
                                 Rex::Logger::debug("Want Password");
                                 my $fh = shift;
                                 $fh->send($pass . "\n");
                                 exp_continue;
                              }
                           ],
                           [
                              qr{Enter passphrase for key.*: $},
                              sub {
                                 Rex::Logger::debug("Want Passphrase");
                                 my $fh = shift;
                                 $fh->send($pass . "\n");
                                 exp_continue;
                              }
                           ],
                           [
                                 qr{rsync error: error in rsync protocol},
                                 sub {
                                    Rex::Logger::debug("Error in rsync");
                                    die;
                                 }
                           ],

      );
   }

   Rex::Logger::debug("cmd: $cmd");

   eval {
      my $exp = Expect->spawn($cmd) or die($!);

      eval {
         $exp->expect(Rex::Config->get_timeout, @expect_options, [
                                 qr{total size is \d+\s+speedup is },
                                 sub {
                                    Rex::Logger::debug("Finished transfer very fast");
                                    die;
                                 }
                             
                              ]);

         $exp->expect(undef, [
                           qr{total size is \d+\s+speedup is },
                           sub {
                              Rex::Logger::debug("Finished transfer");
                              exp_continue;
                           }
                        ],
                        [
                              qr{rsync error: error in rsync protocol},
                              sub {
                                 Rex::Logger::debug("Error in rsync");
                                 die;
                              }
                        ],
                        );

      };

      $exp->soft_close;
      $? = $exp->exitstatus;
   };


   if($@) {
      Rex::Logger::info($@);
   }

}

=back

=cut

1;
