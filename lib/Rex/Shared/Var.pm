#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Shared::Var - Share variables across Rex tasks

=head1 DESCRIPTION

Share variables across Rex tasks with the help of Storable, using a C<vars.db.$PID> file in the local directory, where C<$PID> is the PID of the parent process.

Attention: Currently it is only possible to store flat hashs and arrays. Multidimensional hashs and arrays are not supported.

=head1 SYNOPSIS

 BEGIN {                           # put share in a BEGIN block
   use Rex::Shared::Var;
   share qw($scalar @array %hash); # share the listed variables
 }

=head1 METHODS

=cut

package Rex::Shared::Var;

use strict qw(vars subs);
use warnings;

# VERSION

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(share);

=head2 share

Share the passed list of variables across Rex tasks. Should be used in a C<BEGIN> block.

 BEGIN {
   use Rex::Shared::Var;
   share qw($error_count);
 }

 task 'count', sub {
   $error_count += run 'wc -l /var/log/syslog';
 };

 after_task_finished 'count', sub {
   say "Total number of errors: $error_count";
 };

=cut

sub share {
  my @vars = @_;
  my ( $package, $file, $line ) = caller;

  my ( $sigil, $sym );
  for my $var (@vars) {

    if ( ( $sigil, $sym ) = ( $var =~ /^([\$\@\%\*\&])(.+)/ ) ) {
      $sym = "${package}::$sym";

      if ( $sigil eq "\$" ) {
        eval "use Rex::Shared::Var::Scalar;";
        tie $$sym, "Rex::Shared::Var::Scalar", $sym;
        *$sym = \$$sym;
      }
      elsif ( $sigil eq "\@" ) {
        eval "use Rex::Shared::Var::Array;";
        tie @$sym, "Rex::Shared::Var::Array", $sym;
        *$sym = \@$sym;
      }
      elsif ( $sigil eq "\%" ) {
        eval "use Rex::Shared::Var::Hash;";
        tie %$sym, "Rex::Shared::Var::Hash", $sym;
        *$sym = \%$sym;
      }
    }

  }
}

1;
