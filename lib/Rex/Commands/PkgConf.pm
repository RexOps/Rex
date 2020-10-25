#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::PkgConf - Configure packages

=head1 DESCRIPTION

With this module you can configure packages. Currently it only supports Debian
(using debconf), but it is designed to be extendable.

=head1 SYNOPSIS

 my %options = get_pkgconf('postfix');
 say $options{'postfix/relayhost'}->{value};

 # Only obtain one value
 my %options = get_pkgconf('postfix', 'postfix/relayhost');
 say $options{'postfix/relayhost'}->{value};

 # Set options
 set_pkgconf("postfix", [
    {question => 'chattr', type => 'boolean', value => 'false'},
    {question => 'relayhost', type => 'string', value => 'relay.example.com'},
 ]);

 # Don't update if it's already set
 set_pkgconf("mysql-server-5.5", [
    {question => 'mysql-server/root_password', type => 'string', value => 'mysecret'},
    {question => 'mysql-server/root_password_again', type => 'string', value => 'mysecret'},
 ], no_update => 1);

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::PkgConf;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::PkgConf;
use Rex::Logger;

require Rex::Exporter;

use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(get_pkgconf set_pkgconf);

=head2 get_pkgconf($package, [$question])

Use this to query existing package configurations.

Without a question specified, it will return all options for
the specified package as a hash.

With a question specified, it will return only that option

Each question is returned with the question as the key, and 
the value as a hashref. The hashref contains the keys: question,
value and already_set. already_set is true if the question has
already been answered.

 # Only obtain one value
 my %options = get_pkgconf('postfix', 'postfix/relayhost');
 say $options{'postfix/relayhost'}->{question};
 say $options{'postfix/relayhost'}->{value};
 say $options{'postfix/relayhost'}->{already_set};

=cut

sub get_pkgconf {
  my ($package) = @_;

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "pkgconf", name => $package );

  my $pkgconf = Rex::PkgConf->get;

  $pkgconf->get_options($package);
}

=head2 set_pkgconf($package, $values, [%options])

Use this to set package configurations.

At least the package name and values must be specified. Values
must be an array ref, with each item containing a hashref with
the attributes specified that are required by the package
configuration program.

For example, for debconf, this must be the question, the type
and answer. In this case, the types can be any accetable debconf
type: string, boolean, select, multiselect, note, text, password.

Optionally the option "no_update" may be true, in which case the
question will not be updated if it has already been set.

See the synopsis for examples.

=cut

sub set_pkgconf {
  my ( $package, $values, %options ) = @_;

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "pkgconf", name => $package );

  my $pkgconf = Rex::PkgConf->get;

  my $return = $pkgconf->set_options( $package, $values, %options );

  if ( $return->{changed} ) {
    Rex::get_current_connection()->{reporter}->report(
      changed => 1,
      message => "Configuration values updated: @{$return->{names}}",
    );
  }
  else {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "pkgconf", name => $package );
}

1;
