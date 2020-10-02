#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Transaction - Transaction support

=head1 DESCRIPTION

With this module you can define transactions and rollback scenarios on failure.

=head1 SYNOPSIS

 use Rex::Transaction;
 
 task 'do-something', 'server01', sub {
   transaction {
     on_rollback {
       rmdir '/tmp/mydata';
     };
 
     mkdir '/tmp/mydata';
     upload 'files/myapp.tar.gz', '/tmp/mydata';
     run 'tar xzf myapp.tar.gz -C /tmp/mydata';
     if ( $? != 0 ) { die('Error extracting myapp.tar.gz'); }
   };
 };

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Transaction;

use strict;
use warnings;

# VERSION

require Exporter;

use vars qw(@EXPORT @ROLLBACKS);
use base qw(Exporter);

use Rex::Logger;
use Rex::TaskList;
use Data::Dumper;

@EXPORT = qw(transaction on_rollback);

=head2 transaction($codeRef)

Start a transaction for C<$codeRef>. If C<$codeRef> dies, Rex will run the L<on_rollback|https://metacpan.org/pod/Rex::Transaction#on_rollback> code to roll back the transaction.

 task 'deploy', group => 'frontend', sub {
   on_rollback {
     rmdir '...';
   };

   deploy 'myapp.tar.gz';
 };
 
 task 'restart_server', group => 'frontend', sub {
   service apache2 => 'restart';
 };
 
 task 'all', group => 'frontend', sub {
   transaction {
     do_task [qw/deploy restart_server/];
   };
 };

=cut

sub transaction(&) {
  my ($code) = @_;
  my $ret = 1;

  Rex::Logger::debug("Cleaning ROLLBACKS array");
  @ROLLBACKS = ();

  Rex::TaskList->create()->set_in_transaction(1);

  eval { &$code(); };

  if ($@) {
    my $err = $@;
    Rex::Logger::info("Transaction failed. Rolling back.");

    $ret = 0;
    for my $rollback_code ( reverse @ROLLBACKS ) {

      # push the connection of the task back
      Rex::push_connection( $rollback_code->{"connection"} );

      # run the rollback code
      &{ $rollback_code->{"code"} }($err);

      # and pop it away
      Rex::pop_connection();
    }

    Rex::TaskList->create()->set_in_transaction(0);

    die("Transaction failed. Rollback done.");
  }

  Rex::TaskList->create()->set_in_transaction(0);

  return $ret;

}

=head2 on_rollback($codeRef)

This will execute C<$codeRef> if a step in the L<transaction|https://metacpan.org/pod/Rex::Transaction#transaction> fails.

=cut

sub on_rollback(&) {
  my ($code) = @_;

  push(
    @ROLLBACKS,
    {
      code       => $code,
      connection => Rex::get_current_connection()
    }
  );
}

1;
