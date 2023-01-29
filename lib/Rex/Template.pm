#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

=head1 NAME

Rex::Template - simple template engine

=head1 SYNOPSIS

 use Rex::Template;

 my $template = Rex::Template->new;

 print $template->parse($content, \%template_vars);
 print $template->parse($content, @template_vars);

=head1 DESCRIPTION

This is a simple template engine for configuration files. It is included mostly for backwards compatibility, and it is recommended to use L<Rex::Template::NG> instead (for better control of chomping new lines, and better diagnostics if things go wrong).

=head2 SYNTAX

The following syntax is recognized:

=over 4

=item * anything between C<E<lt>%> and C<%E<gt>> markers are considered as a template directive, which is treated as Perl code

=item * if the opening marker is followed by an equal sign (C<E<lt>%=>) or a plus sign (C<E<lt>%+>), then the directive is replaced with the value it evaluates to

=item * if the closing marker is prefixed with a minus sign (C<-%E<gt>>), then any trailing newlines are chomped for that directive

=back

The built-in template support is intentionally kept basic and simple. For anything more sophisticated, please use your favorite template engine.

=head2 EXAMPLES

Plain text is unchanged:

 my $result = $template->parse( 'one two three', {} );

 # $result is 'one two three'

Variable interpolation:

 my $result = template->parse( 'Hello, this is <%= $::name %>', { name => 'foo' } ); # original format
 my $result = template->parse( 'Hello, this is <%+ $::name %>', { name => 'foo' } ); # alternative format with + sign
 my $result = template->parse( 'Hello, this is <%= $name %>',   { name => 'foo' } ); # local variables
 my $result = template->parse( 'Hello, this is <%= $name %>',     name => 'foo'   ); # array of variables, instead of hashref

 # $result is 'Hello, this is foo' for all cases above

Simple evaluation:

 my $result = $template->parse( '<%= join("/", @{$elements} ) %>', elements => [qw(one two three)] );
 # $result is 'one/two/three'

Embedded code blocks:

 my $content = '<% if ($logged_in) { %>
 Logged in!
 <% } else { %>
 Logged out!
 <% } %>';

 my $result = $template->parse( $content, logged_in => 1 );

 # $result is "\nLogged in!\n"

=head1 DIAGNOSTICS

Not much, mainly due to the internal approach of the module.

If there was a problem, it prints an C<INFO> level I<"syntax error at ...">, followed by a C<WARN> about I<"It seems that there was an error processing the template because the result is empty.">, and finally I<"Error processing template at ...">.

The beginning of the reported syntax error might give some clue where the error happened in the template, but that's it.

Use L<Rex::Template::NG> instead for better diagnostics.

=head1 CONFIGURATION AND ENVIRONMENT

If C<$Rex::Template::BE_LOCAL> is set to a true value, then local template variables are supported instead of only global ones (C<$foo> vs C<$::foo>). The default value is C<1> since Rex-0.41. It can be disabled with the L<no_local_template_vars|Rex#no_local_template_vars> feature flag.

If C<$Rex::Template::DO_CHOMP> is set to a true value, then any trailing new line character resulting from template directives are chomped. Defaults to C<0>.

This module does not support any environment variables.

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Template;

use v5.12.5;
use warnings;
use Symbol;

our $VERSION = '9999.99.99_99'; # VERSION

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

=head2 parse($content, $variables)

Parse C<$content> as a template, using C<$variables> hash reference to pass name-value pairs of variables to make them available for the template function.

Alternatively, the variables may be passed as an array instead of a hash reference.

=cut

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

This function will check if C<$variable> is defined. If yes, it will return the value of C<$variable>, otherwise it will return C<$default_value>.

You can use this function inside your templates, for example:

 ServerTokens <%= is_defined( $::server_tokens, 'Prod' ) %>

=cut

sub is_defined {
  my ( $check_var, $default ) = @_;
  if ( defined $check_var ) { return $check_var; }

  return $default;
}

1;

__END__

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

It might not be able to chomp new line characters resulting from templates in every case.

It can't report useful diagnostic messages upon errors.

Use L<Rex::Template::NG> instead.

=cut
