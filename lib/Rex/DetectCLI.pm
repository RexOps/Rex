#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::DetectCLI;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use List::MoreUtils qw'firstidx';
use Data::Dumper;

use PPI;

@EXPORT = qw(detect_cli);

sub detect_cli {
  my @args = @ARGV;
  my $file_idx = firstidx { $_ eq "-f" || $_ eq "--rexfile" } @args;

  my $rexfile = "Rexfile";
  my $cli     = "v1";     # default is 1.x compat

  if ( $file_idx >= 0 ) {
    $rexfile = $args[ $file_idx + 1 ];
  }

  if ( !-f $rexfile ) { return $cli; }

  my $doc = PPI::Document->new($rexfile);

  my $found = $doc->find(
    sub {
      $_[1]->isa("PPI::Statement::Include")
        && $_[1]->type eq "use"
        && $_[1]->module eq "Rex";
    }
  );

  my @params = $found->[0]->arguments;

  my $feature_idx = firstidx {
    ( $_->isa("PPI::Token::Word") && $_->content() =~ m/^\-?feature$/ )
      || ( ref($_) =~ m/^PPI::Token::Quote::/
      && $_->string() =~ m/^-?feature$/ )
  }
  @params;
  if ( $feature_idx >= 0 ) {
    my @features = @params[ 2 .. $#params ];
  OUTER: for my $feature (@features) {
      if ( ref($feature) =~ m/^PPI::Token::Quote::/ ) {
        if ( $feature->string() =~ m/cli_(.*)/ ) {
          $cli = $1;
          last OUTER;
        }
      }

      my $feature_ref = $feature->find(
        sub {
          ref( $_[1] ) =~ m/^PPI::Token::Quote/;
        }
      );

      for my $feature_found ( @{$feature_ref} ) {
        if ( $feature_found->isa("PPI::Token::QuoteLike::Words") ) {
          for my $fk ( $feature_found->literal ) {
            if ( $fk =~ m/cli_(.*)/ ) {
              $cli = $1;
              last OUTER;
            }
          }
        }
        else {
          if ( $feature_found->string() =~ m/cli_(.*)/ ) {
            $cli = $1;
            last OUTER;
          }
        }
      }
    }
  }

  return $cli;
}

1;
