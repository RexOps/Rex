#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Report::Base;
   
use strict;
use warnings;

use Data::Dumper;
use Rex::Logger;
use Time::HiRes qw(time);
use PadWalker qw/peek_sub/;   # really evil ^_^

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub report {
   my ($self, $msg) = @_;
   return 1;
}

sub register_reporting_hooks {
   my ($self) = @_;

   my @modules = qw(File Fs Pkg Run Service Sync Upload User Cron Download Process);

   my @skip_functions = qw/
      file_write
      file_append
      file_read
      template
      is_dir
      is_file
      can_run
      free
      df
      du
   /;

   for my $mod (@modules) {
      my @exports = eval "\@Rex::Commands::${mod}::EXPORT";
      for my $export (@exports) {
         if(grep { $_ eq $export } @skip_functions) {
            next;
         }
         no strict 'refs';
         no warnings;
         my $orig_sub = \&{ "Rex::Commands::${mod}::$export" };
         *{"Rex::Commands::${mod}::$export"} = sub {
            my $ret;
            my $start_time = time;
            eval {
               $ret = $orig_sub->(@_);
               if(ref $ret eq "HASH") {
                  $self->report({
                        command    => $export,
                        module     => "Rex::Commands::$mod",
                        start_time => $start_time,
                        end_time   => time,
                        data       => \@_,
                        success    => 1,
                        %{ $ret },
                  });
               }
               else {
                  $self->report({
                        command    => $export,
                        module     => "Rex::Commands::$mod",
                        start_time => $start_time,
                        end_time   => time,
                        data       => \@_,
                        success    => 1,
                  });
               }
               1;
            } or do {
               $self->report({
                     command    => $export,
                     module     => "Rex::Commands::$mod",
                     start_time => $start_time,
                     end_time   => time,
                     data       => \@_,
                     success    => 0,
               });

               die($@);
            };

            return $ret;
         };
      }
   }
}

sub write_report {}


1;
