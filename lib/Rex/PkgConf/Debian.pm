#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::PkgConf::Debian;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Helper::Run;

use Rex::PkgConf::Base;
use base qw(Rex::PkgConf::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub get_options {
  my ( $self, $pkg, $option ) = @_;
  die "Package name required to configure" unless $pkg;
  my $conf_cmd = "debconf-show $pkg";

  Rex::Logger::debug("Running command $conf_cmd");
  my @lines = i_run $conf_cmd;

  my %config;
  for my $line (@lines) {

    # Expecting: * postfix/relayhost: smtp.example.com
    Rex::Logger::debug("Parsing line $line");
    if ( $line =~ m!^(\*?)\s+(.+):\s*(.*)! ) {
      my ( $already_set, $question, $value ) = ( $1, $2, $3, $4 );
      Rex::Logger::debug(
        "Found configuration question $question with value $value");
      next if $option && $option ne $question;
      $already_set = $already_set ? 1 : 0;
      $config{$question} = {
        question    => $question,
        value       => $value,
        already_set => $already_set,
      };
    }
  }

  %config;
}

sub set_options {
  my ( $self, $pkg, $values, %options ) = @_;
  die "set_option usage: set_option package, values, options"
    unless $pkg && $values;

  # Get existing options first, to see if they need setting
  my %existing = $self->get_options($pkg);

  my @updated;
  for my $line (@$values) {

    my ( $question, $value, $type ) =
      ( $line->{question}, $line->{value}, $line->{type} );

    die "Question and type required for each package configuration option"
      unless $question && $type;

    if ( $existing{$question} && $existing{$question}->{value} eq $value ) {
      Rex::Logger::debug("Option $question already set to $value, ignoring");
      next;
    }

    if ( $options{no_update}
      && $existing{$question}
      && $existing{$question}->{already_set} )
    {
      Rex::Logger::debug("Option $question already set, not updating");
      next;
    }

    Rex::Logger::debug("Will set option $question: $value (type $type)");
    push @updated, "$pkg $question $type $value";
  }

  if (@updated) {
    my $settings = join '\n', @updated;
    my $conf_cmd = qq(echo -e "$settings"|debconf-set-selections);
    i_run $conf_cmd;
    return {
      changed => 1,
      names   => \@updated,
    };
  }
  else {
    return { changed => 0, };
  }
}

1;
