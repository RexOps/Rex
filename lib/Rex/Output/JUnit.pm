#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Output::JUnit;
   
use strict;
use warnings;

use Data::Dumper;
use Rex::Template;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   $self->{time}  = time();
   $self->{error} = "";

   return $self;
}

sub add {
   my ($self, $task, %option) = @_;
   $option{name} = $task;
   $option{time} = time() - $self->{time};

   push(@{$self->{"data"}}, { %option });

   if(exists $option{error}) {
      $self->error($option{msg});
   }
}

sub error {
   my ($self, $msg) = @_;
   $self->{error} .= $msg . "\n";
}


sub DESTROY {
   my ($self) = @_;

   my $t = Rex::Template->new;
   my $data = eval { local $/; <DATA>; };
   my $time = time() - $self->{time};

   my $s = $t->parse($data, {
      errors        => scalar(grep { $_->{"error"} && $_->{"error"} == 1 } @{$self->{"data"}}),
      tests         => scalar(@{$self->{"data"}}),
      time_over_all => $time,
      system_out    => $self->{"error"} || "",
      items         => $self->{"data"},
   });

   print $s;
   if($s) {
      open(my $fh, ">", "junit_output.xml") or die($!);
      print $fh $s;
      close($fh);
   }
}

1;

__DATA__
<?xml version='1.0' encoding='utf-8'?>
<testsuites>
  <testsuite name="rex" errors="<%= $::errors %>" failures="0" tests="<%= $::tests %>" time="<%= $::time_over_all %>">
    <system-out><%= $::system_out %></system-out>                                                                                               
    <% foreach my $item (@$::items) { %>
    <% if($item->{"error"}) { %>
    <testcase name="<%= $item->{"name"} %>" classname="t_rex_proc" time="<%= $item->{"time"} %>">
       <failure message="<%= $item->{"name"} %>" type="Rex::Task"></failure>
    </testcase>
    <% } else { %>
    <testcase name="<%= $item->{"name"} %>" classname="t_rex_task" time="<%= $item->{"time"} %>" />
    <% } %>
    <% } %>
  </testsuite>
</testsuites>

