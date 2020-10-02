#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Template - Simple Template Engine.

=head1 DESCRIPTION

This is a simple template engine for configuration files.

=head1 SYNOPSIS

 my $template = Rex::Template->new;
 print $template->parse($content, \%template_vars);

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Template;

use strict;
use warnings;
use Symbol;

# VERSION

use Rex::Config;
use Rex::Logger;
require Rex::Args;

our $DO_CHOMP = 0;
our $BE_LOCAL = 1;

sub function {
  my ( $class, $name, $code ) = @_;

  my $ref_to_name = qualify_to_ref( $name, $class );
  *{$ref_to_name} = $code;
}

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub parse {
  my $self = shift;
  my $data = shift;

  my $vars = {};

  if ( ref( $_[0] ) eq "HASH" ) {
    $vars = shift;
  }
  else {
    $vars = {@_};
  }

  my $new_data;
  my $___r = "";

  my $do_chomp = 0;
  $new_data = join(
    "\n",
    map {
      my ( $code, $type, $text ) = ( $_ =~ m/(\<%)*([+=])*(.+)%\>/s );

      if ($code) {
        my $pcmd = substr( $text, -1 );
        if ( $pcmd eq "-" ) {
          $text     = substr( $text, 0, -1 );
          $do_chomp = 1;
        }

        my ( $var_type, $var_name ) = ( $text =~ m/([\$])::([a-zA-Z0-9_]+)/ );

        if ( $var_name && !ref( $vars->{$var_name} ) && !$BE_LOCAL ) {
          $text =~ s/([\$])::([a-zA-Z0-9_]+)/$1\{\$$2\}/g;
        }
        elsif ( $var_name && !ref( $vars->{$var_name} ) && $BE_LOCAL ) {
          $text =~ s/([\$])::([a-zA-Z0-9_]+)/$1$2/g;
        }
        else {
          $text =~ s/([\$])::([a-zA-Z0-9_]+)/\$$2/g;
        }

        if ( $type && $type =~ m/^[+=]$/ ) {
          "\$___r .= $text;";
        }
        else {
          $text;
        }

      }

      else {
        my $chomped = $_;
        if ( $DO_CHOMP || $do_chomp ) {
          chomp $chomped;
          $do_chomp = 0;
        }
        '$___r .= "' . _quote($chomped) . '";';

      }

    } split( /(\<%.*?%\>)/s, $data )
  );

  eval {
    no strict 'vars';

    for my $var ( keys %{$vars} ) {
      Rex::Logger::debug("Registering: $var");

      my $ref_to_var = qualify_to_ref($var);

      unless ( ref( $vars->{$var} ) ) {
        $ref_to_var = \$vars->{$var};
      }
      else {
        $ref_to_var = $vars->{$var};
      }
    }

    if ( $BE_LOCAL == 1 ) {
      my $var_data = '
      
      return sub {
        my $___r = "";
        my (
      
      ';

      my @code_values;
      for my $var ( keys %{$vars} ) {
        my $new_var = _normalize_var_name($var);
        Rex::Logger::debug("Registering local: $new_var");
        $var_data .= '$' . $new_var . ", \n";
        push( @code_values, $vars->{$var} );
      }

      $var_data .= '$this_is_really_nothing) = @_;';
      $var_data .= "\n";

      $var_data .= $new_data;

      $var_data .= "\n";
      $var_data .= ' return $___r;';
      $var_data .= "\n};";

      Rex::Logger::debug("BE_LOCAL==1");

      my %args = Rex::Args->getopts;
      if ( defined $args{'d'} && $args{'d'} > 1 ) {
        Rex::Logger::debug($var_data);
      }

      my $tpl_code = eval($var_data);

      if ($@) {
        Rex::Logger::info($@);
      }

      $___r = $tpl_code->(@code_values);

    }
    else {
      Rex::Logger::debug("BE_LOCAL==0");
      my %args = Rex::Args->getopts;
      if ( defined $args{'d'} && $args{'d'} > 1 ) {
        Rex::Logger::debug($new_data);
      }

      $___r = eval($new_data);

      if ($@) {
        Rex::Logger::info($@);
      }
    }

    # undef the vars
    for my $var ( keys %{$vars} ) {
      $$var = undef;
    }

  };

  if ( !$___r ) {
    Rex::Logger::info(
      "It seems that there was an error processing the template", "warn" );
    Rex::Logger::info( "because the result is empty.", "warn" );
    die("Error processing template");
  }

  return $___r;
}

sub _quote {
  my ($str) = @_;

  $str =~ s/\\/\\\\/g;
  $str =~ s/"/\\"/g;
  $str =~ s/\@/\\@/g;
  $str =~ s/\%/\\%/g;
  $str =~ s/\$/\\\$/g;

  return $str;
}

sub _normalize_var_name {
  my ($input) = @_;
  $input =~ s/[^A-Za-z0-9_]/_/g;
  return $input;
}

=head2 is_defined($variable, $default_value)

This function will check if $variable is defined. If yes, it will return the value of $variable, otherwise it will return $default_value.

You can use this function inside your templates.

 ServerTokens <%= is_defined($::server_tokens, "Prod") %>

=cut

sub is_defined {
  my ( $check_var, $default ) = @_;
  if ( defined $check_var ) { return $check_var; }

  return $default;
}

1;
