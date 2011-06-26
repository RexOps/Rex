#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Transaction;

use strict;
use warnings;

require Exporter;

use vars qw(@EXPORT @ROLLBACKS);
use base qw(Exporter);

use Rex::Logger;

@EXPORT = qw(transaction on_rollback);

sub transaction(&) {
   my ($code) = @_;

   Rex::Logger::debug("Cleaning ROLLBACKS array");
   @ROLLBACKS = ();

   eval {
      &$code();
   };

   if($@) {
      print "Wuhuuuu bin jestorbaaeeaeaennnn!! $@\n";
      exit 1;
   }

}

sub on_rollback(&) {
   my ($code) = @_;

   push @ROLLBACKS, $code;
}

1;
