#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Template;


use strict;
use warnings;

use Rex::Logger;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub parse {
   my $self = shift;
   my $data = shift;
   my $vars = shift;

   my $new_data;
   my $r="";

   $new_data = join("\n", map {
      my ($code, $type, $text) = ($_ =~ m/(\<%)*([+])*(.+)%\>/s);

      if($code) {
         my($var_type, $var_name) = ($text =~ m/([\$])::([a-zA-Z0-9_]+)/);

         if($type && $type eq "+") {

            if(! ref($vars->{$var_name})) {
               $text =~ s/([\$])::([a-zA-Z0-9_]+)/$1\{\$$2\}/g;
            }
            else {
               $text =~ s/([\$])::([a-zA-Z0-9_]+)/\$$2/g;
            }

            $_ = "\$r .= $text;";

         }

         else {

            $_ = $text;

         }

      } 
      
      else {

         s/"/\\"/g;
         $_ = '$r .= "' . $_ . '";';

      }

   } split(/(\<%.*?%\>)/s, $data));

   eval {
      no strict 'refs';
      no strict 'vars';

      for my $var (keys %{$vars}) {
         unless(ref($vars->{$var})) {
            $$var = \$vars->{$var};
         } else {
            $$var = $vars->{$var};
         }
      }

      eval($new_data);

      if($@) {
         Rex::Logger::info($@);
      }

   };

   return $r;
}

1;

