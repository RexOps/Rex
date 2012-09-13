#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Exec::HTTP;
   
use strict;
use warnings;
use Rex::Commands;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub exec {
   my ($self, $cmd, $path) = @_;

   Rex::Logger::debug("Executing: $cmd");

   if($path) { $path = "PATH=$path" }
   $path ||= "";

   # let the other side descide if LC_ALL=C should be used
   # for example, this will not work on windows
   #$cmd = "LC_ALL=C $path " . $cmd;

   Rex::Commands::profiler()->start("exec: $cmd");
   my $resp = connection->post("/execute", {exec => $cmd});
   Rex::Commands::profiler()->stop("exec: $cmd");

   if($resp->{ok}) {
      $? = $resp->{retval};
      my ($out, $err) =  ($resp->{output}, "");

      Rex::Logger::debug($out);

      if($err) {
         Rex::Logger::debug("========= ERR ============");
         Rex::Logger::debug($err);
         Rex::Logger::debug("========= ERR ============");
      }

      if(wantarray) { return ($out, $err); }

      return $out;
   }
   else {
      $? = 1;
   }

}

1;
