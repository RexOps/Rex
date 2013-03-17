#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Cron::Base;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub list {
   my ($self) = @_;
   $self->_parse_cron($self->_read_cron);
}

sub add {
   my ($self) = @_;
}

sub delete {
   my ($self) = @_;
}

sub _parse_cron {
   my ($self, @lines) = @_;

   my @cron;

   for my $line (@lines) {

      # comment
      if($line =~ m/^#/) {
         push(@cron, {
            type => "comment",
            line => $line,
         });
      }

      # empty line
      elsif($line =~ m/^\s*$/) {
         push(@cron, {
            type => "empty",
            line => $line,
         });
      }

      # job
      elsif($line =~ m/^(@|\*|[0-9])/) {
         my ($min, $hour, $day, $month, $dow, $cmd) = split(/\s+/, $line, 6);
         push(@cron, {
            type => "job",
            line => $line,
            cron => {
               min => $min,
               hour => $hour,
               day => $day,
               mon => $month,
               dow => $dow,
               cmd => $cmd,
            },
         });
      }

      elsif($line =~ m/=/) {
         my ($name, $value) = split(/=/, $line, 2);
         $name  =~ s/^\s+//;
         $name  =~ s/\s+$//;
         $value =~ s/^\s+//;
         $value =~ s/\s+$//;

         push(@cron, {
            type  => "env",
            line  => $line,
            name  => $name,
            value => $value,
         });
      }

      else {
         Rex::Logger::debug("Error parsing cron line: $line");
         next;
      }

   }

   $self->{cron} = \@cron;
   return @cron;
}

sub _read_cron {
   my ($self, $user) = @_;
   my @lines = run "crontab -u $user -l";
   return @lines;
}

1;
