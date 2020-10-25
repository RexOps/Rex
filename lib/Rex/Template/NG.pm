#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Template::NG;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->_init();

  return $self;
}

sub _init {
  my ($self) = @_;

  $self->{__output__}   = "";
  $self->{__code__}     = "";
  $self->{__raw_data__} = "";
}

sub parse {
  my $self = shift;
  my $c    = shift;
  my %in_vars;

  $self->_init();

  if ( ref $_[0] eq "HASH" ) {
    %in_vars = %{ +shift };
  }
  else {
    %in_vars = @_;
  }

  my %vars;

  for my $key ( keys %in_vars ) {
    my $new_key = $key;
    $new_key =~ s/[^a-zA-Z0-9_]/_/gms;
    $vars{$new_key} = $in_vars{$key};
  }

  # some backward compat. to old template module.
  $c =~ s/\$::([a-zA-Z0-9_]+)/_replace_var($1, \%vars)/egms;

  my $code = "";

  my $var_data = '
  
  return sub {
    my (
      $self,
  ';

  my @code_values;
  for my $var ( keys %vars ) {
    $var_data .= '$' . $var . ", \n";
    push( @code_values, $vars{$var} );
  }

  $var_data .= '$this_is_really_nothing) = @_;';
  $var_data .= "\n";

  $code = $var_data;

  $code .= $self->_parse($c);

  $code .= "\n}";

  my $idx_c = 1;
  for my $l ( split( /\n/, $code ) ) {
    $idx_c++;
    $l ||= "";
    Rex::Logger::debug("$idx_c. $l");
  }

  $self->{__code__}     = $code;
  $self->{__raw_data__} = $c;

  no warnings;
  my $tpl_code = eval($code);
  use warnings;

  if ($@) {

    my $error = $@;

    my ($error_line) = ( $error =~ m/line (\d+)[\.,]/ );
    my @code_lines   = split( /\n/, $code );
    my @raw_lines    = split( /\n/, $c );

    my $idx = $error_line - 5;
    for my $l ( @code_lines[ $error_line - 5 .. $error_line + 5 ] ) {
      $idx++;
      $l ||= "";
      Rex::Logger::debug("$idx. $l");
    }

    my $template_line     = 0;
    my $add_to_error_line = -1;

    # search the error line
    Rex::Logger::debug("Template-Error-Line: $error_line");
    for ( my $bi = $error_line - 1 ; $bi >= 0 ; $bi-- ) {
      if ( $code_lines[$bi] =~ m/^# LINE: (\d+)$/ ) {
        $template_line = $1 + $add_to_error_line;
        last;
      }
      $add_to_error_line++;
    }

    if ( !$template_line ) {
      die "Uncatchable error in template: $error ($error_line)";
    }

    my $start_part = $template_line - 5;
    $start_part = 0 if $start_part <= 0;
    my $end_part = $template_line + 5;
    $end_part = scalar @raw_lines if $end_part > scalar @raw_lines;

    my $idx_t = $start_part;

    for my $l ( @raw_lines[ $start_part .. $end_part ] ) {
      $idx_t++;
      $l ||= "";
      Rex::Logger::info("$idx_t. $l");
    }

    my $tpl_error = $error;
    $tpl_error =~ s/at \(eval \d+\) line \d+/at template line $template_line/;

    if ( $error =~ m/Global symbol "([^"]+)" requires explicit package name/ ) {
      $tpl_error =
        "Unknown variable name $1 in code line: ,,$raw_lines[$template_line-1]'' line: $template_line.\nOriginal Error:\n$error\n";
    }

    # internal parsing error, maybe runaway line without ";"
    elsif ( $raw_lines[ $template_line - 2 ] =~ m/^%/
      && $raw_lines[ $template_line - 2 ] !~ m/[;{("']/ )
    {
      Rex::Logger::debug(
        "Template Error in compiled line: $code_lines[$error_line-1]");
      Rex::Logger::info(
        "Template Error somewhere around: $raw_lines[$template_line-2]",
        "error" );

      my $template_line_ = $template_line - 1;
      $tpl_error =
        "Maybe missing <<;, {, (, \" or '>> in code line: ,,$raw_lines[$template_line-2]'' line $template_line_.\nOriginal Error:\n$error\n";
    }
    else {
      $tpl_error =
        "Failed parsing template. Unkown error near $template_line.\nOriginal Error:\n$error\n";
    }

    die $tpl_error;
  }

  $tpl_code->( $self, @code_values );

  return $self->{__output__};
}

sub __out {
  my ( $self, $str ) = @_;

  $self->{__output__} .= defined $str ? $str : "";
}

sub _parse {
  my ( $self, $c ) = @_;

  my $parsed = "";

  my @chars = split( //, $c );

  my $begin_line        = 0;
  my $code_line         = 0;
  my $code_block        = 0;
  my $code_block_output = 0;
  my $current_char_idx  = -1;
  my $line_count        = 1;
  my $string_open       = 0;
  my $skip_next         = 0;
  my $skip_next_newline = 0;

  for my $curr_char (@chars) {
    $current_char_idx++;

    if ($skip_next) {
      $skip_next = 0;
      next;
    }

    my $prev_char = $chars[ $current_char_idx - 1 ] || "";
    my $next_char = $chars[ $current_char_idx + 1 ] || "";

    if ( $skip_next_newline && $curr_char eq "\n" ) {
      $skip_next_newline = 0;
      $curr_char         = "";
    }

    if ( $curr_char eq "\n" && $prev_char ne "\n" ) { # count lines, for error messages
      $line_count++;
      $parsed .= $curr_char;

      if ($string_open) {
        $parsed .= "});\n";
      }

      # reset vars
      $code_line   = 0;
      $string_open = 0;

      next;
    }

    if ( $curr_char eq "\n" && $prev_char eq "\n" ) {
      $parsed .= "\$self->__out(q{\n});\n";
      $line_count++;
      next;
    }

    if ( $curr_char eq "-"
      && $next_char eq "%"
      && ( $prev_char eq " " || $prev_char eq "\n" )
      && $chars[ $current_char_idx + 2 ] eq ">" )
    {
      # skip "-" of -%> sequence
      $skip_next_newline = 1;
      next;
    }

    # catch code line
    # % some code
    if (
      !$code_block
      && ( $prev_char eq "\n"
        || $current_char_idx == 0 ) # first line or new line
      && $curr_char eq "%"
      && $next_char eq " "          # code block, and no % char escape sequence
      )
    {
      $code_line = 1;
      $parsed .= "\n# LINE: $line_count\n";
      next;
    }

    # catch '<% ' ...
    if ( $prev_char eq "<"
      && $curr_char eq "%"
      && ( $next_char eq " " || $next_char eq "\n" ) )
    {
      $code_block = 1;
      if ($string_open) {
        $parsed .= "});\n";
        $string_open = 0;
      }

      $parsed .= "\n# LINE: $line_count\n";

      next;
    }

    # catch ' %>'
    if (
      $code_block
      && ( ( $code_block_output || $prev_char eq " " )
        || $prev_char eq "\n"
        || $prev_char eq "-" )
      && $curr_char eq "%"
      && $next_char eq ">"
      )
    {
      $code_block = 0;

      if ($code_block_output) {
        $parsed .= ");\n";
        $code_block_output = 0;
      }

      $string_open = 1;
      $parsed .= "\n\$self->__out(q{";

      next;
    }

    # catch '<%='
    if ( $prev_char eq "<" && $curr_char eq "%" && $next_char eq "=" ) {
      $code_block        = 1;
      $code_block_output = 1;

      if ($string_open) {
        $parsed .= "});\n";
      }

      $parsed .= "\n# LINE: $line_count\n";
      $parsed .= "\$self->__out(";
      $skip_next = 1;

      next;
    }

    if ( $code_line || $code_block ) {
      $parsed .= $curr_char;
      next;
    }

    if ( !$string_open ) {
      $string_open = 1;
      $parsed .= '$self->__out(q{';
    }

    # don't catch opening <
    if ( $curr_char eq "<" && $next_char eq "%" ) {
      next;
    }

    # don't catch closing >
    if ( $curr_char eq ">" && $prev_char eq "%" ) {
      next;
    }

    # escaping of % sign
    if ( $curr_char eq "%" && $prev_char eq "%" ) {
      next;
    }

    $parsed .= $curr_char =~ m/[{}]/ ? "\\$curr_char" : $curr_char;

  }

  if ($string_open) {
    $parsed .= "});\n";
  }

  return $parsed;

}

sub _replace_var {
  my ( $var, $t_vars ) = @_;

  if ( exists $t_vars->{$var} ) {
    return '$' . $var;
  }
  else {
    return '$::' . $var;
  }
}

1;
