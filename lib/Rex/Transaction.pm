#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Transaction - Transaction support.

=head1 DESCRIPTION

With this module you can define transactions and rollback szenarios on failure.

=head1 SYNOPSIS

 task "do-something", "server01", sub {
   on_rollback {
      rmdir "/tmp/mydata";
   };

   transaction {
      mkdir "/tmp/mydata";
      upload "files/myapp.tar.gz", "/tmp/mydata";
      run "cd /tmp/mydata; tar xzf myapp.tar.gz";
      if($? != 0) { die("Error extracting myapp.tar.gz"); }
   };
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut



package Rex::Transaction;

use strict;
use warnings;

require Exporter;

use vars qw(@EXPORT @ROLLBACKS);
use base qw(Exporter);

use Rex::Logger;
use Rex::TaskList;
use Data::Dumper;

@EXPORT = qw(transaction on_rollback);

=item transaction($codeRef)

Start a transaction for $codeRef. If $codeRef dies it will rollback the transaction.

 task "deploy", group => "frontend", sub {
     on_rollback {
         rmdir "...";
     };
     deploy "myapp.tar.gz";
 };
   
 task "restart_server", group => "frontend", sub {
     run "/etc/init.d/apache2 restart";
 };
   
 task "all", group => "frontend", sub {
     transaction {
         do_task qw/deploy restart_server/;
     };
 };

=cut

sub transaction(&) {
   my ($code) = @_;
   my $ret = 1;

   Rex::Logger::debug("Cleaning ROLLBACKS array");
   @ROLLBACKS = ();

   Rex::TaskList->create()->set_in_transaction(1);

   eval {
      &$code();
   };

   if($@) {
      Rex::Logger::info("Transaction failed. Rolling back.");

      $ret = 0;
      for my $rollback_code (reverse @ROLLBACKS) {
         # push the connection of the task back
         Rex::push_connection($rollback_code->{"connection"});

         # run the rollback code
         &{ $rollback_code->{"code"} }();

         # and pop it away
         Rex::pop_connection();
      }

      die("Transaction failed. Rollback done.");
   }

   Rex::TaskList->set_in_transaction(0);

   return $ret;

}

=item on_rollback($codeRef)

This code will be executed if one step in the transaction fails.

See I<transaction>.

=cut

sub on_rollback(&) {
   my ($code) = @_;

   push (@ROLLBACKS, {
      code       => $code,
      connection => Rex::get_current_connection()
   });
}

=back

=cut

1;
