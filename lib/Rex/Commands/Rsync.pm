#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Rsync - Simple Rsync Frontend

=head1 DESCRIPTION

With this module you can sync 2 directories via the I<rsync> command.

Version <= 1.0: All these functions will not be reported.

All these functions are not idempotent.

=head1 DEPENDENCIES

=over 4

=item Expect

The I<Expect> Perl module is required to be installed on the machine
executing the rsync task.

=item rsync

The I<rsync> command has to be installed on both machines involved in
the execution of the rsync task.

=back

=head1 SYNOPSIS

 use Rex::Commands::Rsync;

 sync "dir1", "dir2";

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Rsync;

use strict;
use warnings;

# VERSION

BEGIN {
  use Rex::Require;
  Expect->use;
  $Expect::Log_Stdout = 0;
}

require Rex::Exporter;

use base qw(Rex::Exporter);
use vars qw(@EXPORT);

use Net::OpenSSH::ShellQuoter;
use Rex::Commands qw(FALSE TRUE);
use Rex::Helper::IP;
use Rex::Helper::Path;
use Rex::Helper::Run;
use Rex::Interface::Shell;

@EXPORT = qw(sync);

=head2 sync($source, $dest, $opts)

This function executes rsync to sync $source and $dest. The C<rsync> command is
invoked with the C<--recursive --links --verbose --stats> options set.

If you want to use sudo, you need to disable I<requiretty> option for this user. You can do this with the following snippet in your sudoers configuration.

 Defaults:username !requiretty

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
  my ( $source, $dest, $opt ) = @_;

  my $current_connection = Rex::get_current_connection();
  my $server             = $current_connection->{server};
  my $cmd;

  my ( $port, $servername );

  if ( defined $server->to_s ) {
    ( $servername, $port ) =
      Rex::Helper::IP::get_server_and_port( $server->to_s, 22 );
  }

  my $local_connection = TRUE;

  if ( defined $servername && $servername ne '<local>' ) {
    $local_connection = FALSE;
  }

  my $auth = $current_connection->{conn}->get_auth;

  if ( !exists $opt->{download} && $source !~ m/^\// ) {

    # relative path, calculate from module root
    $source = Rex::Helper::Path::get_file_path( $source, caller() );
  }

  Rex::Logger::debug("Syncing $source -> $dest with rsync.");
  if ($Rex::Logger::debug) {
    $Expect::Log_Stdout = 1;
  }

  my $params = "";
  if ( $opt && exists $opt->{'exclude'} ) {
    my $excludes = $opt->{'exclude'};
    $excludes = [$excludes] unless ref($excludes) eq "ARRAY";
    for my $exclude (@$excludes) {
      $params .= " --exclude=" . $exclude;
    }
  }

  if ( $opt && exists $opt->{parameters} ) {
    $params .= " " . $opt->{parameters};
  }

  my @rsync_cmd = ();

  my $exec   = Rex::Interface::Exec->create;
  my $quoter = Net::OpenSSH::ShellQuoter->quoter( $exec->shell->name );

  if ( $opt && exists $opt->{'download'} && $opt->{'download'} == 1 ) {
    $dest = resolv_path($dest);
    Rex::Logger::debug("Downloading $source -> $dest");
    push @rsync_cmd, "rsync -rl --verbose --stats $params ";

    if ( !$local_connection ) {
      push @rsync_cmd, "-e '\%s'";
      $source = $auth->{user} . "\@$servername:$source";
    }
  }
  else {
    $source = resolv_path($source);
    Rex::Logger::debug("Uploading $source -> $dest");

    push @rsync_cmd, "rsync -rl --verbose --stats $params";

    if ( !$local_connection ) {
      push @rsync_cmd, "-e '\%s'";
      $dest = $auth->{user} . "\@$servername:$dest";
    }
  }

  $source = $quoter->quote_glob($source);
  $dest   = $quoter->quote_glob($dest);

  push @rsync_cmd, $source;
  push @rsync_cmd, $dest;

  if (Rex::is_sudo) {
    push @rsync_cmd, "--rsync-path='sudo rsync'";
  }

  $cmd = join( " ", @rsync_cmd );

  if ( !$local_connection ) {
    my $pass           = $auth->{password};
    my @expect_options = ();

    my $auth_type = $auth->{auth_type};
    if ( $auth_type eq "try" ) {
      if ( $server->get_private_key && -f $server->get_private_key ) {
        $auth_type = "key";
      }
      else {
        $auth_type = "pass";
      }
    }

    if ( $auth_type eq "pass" ) {
      $cmd = sprintf( $cmd,
        "ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p $port",
      );
      push(
        @expect_options,
        [
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
            $fh->send( $pass . "\n" );
            exp_continue;
          }
        ],
        [
          qr{password for.*:$}i,
          sub {
            Rex::Logger::debug("Want Password");
            my $fh = shift;
            $fh->send( $pass . "\n" );
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
        [
          qr{rsync error: remote command not found},
          sub {
            Rex::Logger::info("Remote rsync command not found");
            Rex::Logger::info(
              "Please install rsync, or use Rex::Commands::Sync sync_up/sync_down"
            );
            die;
          }
        ],

      );
    }
    else {
      if ( $auth_type eq "key" ) {
        $cmd = sprintf( $cmd,
              'ssh -i '
            . $server->get_private_key
            . " -o StrictHostKeyChecking=no -p $port" );
      }
      else {
        $cmd = sprintf( $cmd, 'ssh -o StrictHostKeyChecking=no -p ' . "$port" );
      }
      push(
        @expect_options,
        [
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
            $fh->send( $pass . "\n" );
            exp_continue;
          }
        ],
        [
          qr{Enter passphrase for key.*: $},
          sub {
            Rex::Logger::debug("Want Passphrase");
            my $fh = shift;
            $fh->send( $pass . "\n" );
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
        [
          qr{rsync error: remote command not found},
          sub {
            Rex::Logger::info("Remote rsync command not found");
            Rex::Logger::info(
              "Please install rsync, or use Rex::Commands::Sync sync_up/sync_down"
            );
            die;
          }
        ],

      );
    }

    Rex::Logger::debug("cmd: $cmd");

    eval {
      my $exp = Expect->spawn($cmd) or die($!);

      eval {
        $exp->expect(
          Rex::Config->get_timeout,
          @expect_options,
          [
            qr{total size is [\d,]+\s+speedup is },
            sub {
              Rex::Logger::debug("Finished transfer very fast");
              die;
            }

          ]
        );

        $exp->expect(
          undef,
          [
            qr{total size is [\d,]+\s+speedup is },
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
  }
  else {
    Rex::Logger::debug("Executing command: $cmd");

    i_run $cmd, fail_ok => 1;

    if ( $? != 0 ) {
      die 'Error during local rsync operation';
    }
  }

  if ($@) {
    Rex::Logger::info($@);
  }

}

1;
