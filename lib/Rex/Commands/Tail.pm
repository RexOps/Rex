#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Tail - Tail a file

Version <= 1.0: All these functions will not be reported.

All these functions are not idempotent.

=head1 DESCRIPTION

With this module you can tail a file

=head1 SYNOPSIS

 tail "/var/log/syslog";


=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Tail;

use strict;
use warnings;

require Rex::Exporter;
use Data::Dumper;
use Rex::Commands::Fs;
use Rex::Commands::File;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(tail);

=item tail($file)

This function will tail the given file.

 task "syslog", "server01", sub {
   tail "/var/log/syslog";
 };

Or, if you want to format the output by yourself, you can define a callback function.

 task "syslog", "server01", sub {
   tail "/var/log/syslog", sub {
    my ($data) = @_;

    my $server = Rex->get_current_connection()->{'server'};

    print "$server>> $data\n";
   };
 };



=cut

sub tail {
  my $file = shift;
  my $callback = shift;

  if(Rex::is_sudo()) {
    die("Can't use tail within sudo environment.");
  }

  Rex::Logger::debug("Tailing: $file");

  if(my $ssh = Rex::is_ssh()) {
    my %stat = stat $file;
    my $orig_size = $stat{'size'};
    my $new_pos = $stat{'size'} - 1024;
    if($new_pos < 0) { $new_pos = 0; }

    my %new_stat;
    my $old_pos;
    while(1) {
      if(!%new_stat || $new_stat{'size'} > $stat{'size'}) {
        my $fh = file_read $file;
        unless($fh) {
          die("Error opening $file for reading");
        }
        my $data;

        if(!%new_stat) {
          $fh->seek($stat{'size'} - 1024);
          $data = $fh->read(1024);
        }
        else {
          $fh->seek($old_pos);
          $data = $fh->read($new_stat{'size'} - $old_pos);
        }


        my @lines = split(/\n/, $data);
        shift @lines unless $old_pos;

        if($callback) {
          for my $line (@lines) {
            &$callback($line);
          }
        }
        else {
          print join("\n", @lines) . "\n";
        }

        $fh->close;
        $old_pos = $new_stat{'size'};
      }

      select undef, undef, undef, 0.3;
      %stat = %new_stat if %new_stat;
      %new_stat = stat $file;
    }

  } else {
    system("tail -f $file");
  }

}

=back

=cut

1;
