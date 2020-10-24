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

With this module you can tail a file.

=head1 SYNOPSIS

 tail "/var/log/syslog";


=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Tail;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Rex::Exporter;
use Data::Dumper;
use Rex::Commands::Fs;
use Rex::Commands::File;

#use Rex::Helper::Run;
use Rex::Commands::Run;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(tail);

=head2 tail($file)

This function will tail the given file.

 task "syslog", "server01", sub {
   tail "/var/log/syslog";
 };

If you want to control the output format, you can define a callback function:

 task "syslog", "server01", sub {
   tail "/var/log/syslog", sub {
    my ($data) = @_;
 
    my $server = Rex->get_current_connection()->{'server'};
 
    print "$server>> $data\n";
   };
 };



=cut

sub tail {
  my $file     = shift;
  my $callback = shift;

  $callback ||= sub {
    print $_[0];
  };

  Rex::Logger::debug("Tailing: $file");

  run "tail -f $file", continuous_read => sub {
    $callback->(@_);
    },
    ;

}

1;
