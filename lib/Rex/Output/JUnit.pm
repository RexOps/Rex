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

   return $self;
}

sub add {
   my ($self, %option) = @_;
   push(@{$self->{"data"}}, { %option });
}

sub error {
   my ($self, $msg) = @_;
   $self->{"error"} = $msg;
}

sub print {
   my ($self) = @_;

   my $t = Rex::Template->new;

   my $data = eval { local $/; <DATA>; };

   my $time;
      $time += $_->{"time"} for @{$self->{"data"}};

   open(my $fh, ">", "junit_output.xml") or die($!);
   print $fh $t->parse($data, {
      errors => scalar(grep { $_->{"status"} eq "failed" } @{$self->{"data"}}),
      tests => scalar(@{$self->{"data"}}),
      time_over_all => $time,
      system_out => $self->{"error"} || "",
      items => $self->{"data"},
   });
   close($fh);
}

1;

__DATA__
<?xml version='1.0' encoding='utf-8'?>
<testsuites>
  <testsuite name="rex" errors="<%= $::errors %>" failures="0" tests="<%= $::tests %>" time="<%= $::time_over_all %>">
    <system-out><%= $::system_out %></system-out>
    <% foreach my $item (@$::items) { %>
    <% if($item->{"status"} eq "failed") { %>
    <testcase name="<%= $item->{"name"} %>" classname="t_rex_proc" time="<%= $item->{"time"} %>">
       <failure message="not ok - <%= $item->{"name"} %>" type="Rex::Task"></failure>
    </testcase>
    <% } else { %>
    <testcase name="<%= $item->{"name"} %>" classname="t_rex_proc" time="<%= $item->{"time"} %>" />
    <% } %>
    <% } %>
  </testsuite>
</testsuites>

