#!/usr/bin/perl

# unlink myself
#unlink $0;

open (my $in, "<%= $file %>") || exit(1);
my $found=0;
while(<$in>) {
      chomp;
      <% for my $r (@{ $regex }) { %>
        if ("<%= quotemeta($r) %>") {
            my $reg = qr/<%= $r %>/;
            ($_ =~ $reg) && ($found=1);
         }
         if ("<%= quotemeta($line) %>") {
            ($_ eq "<%= quotemeta($line) %>") && ($found=1);
         }
      <% } %>
}
close $in;
if (!$found) {
   open (my $out, ">><%= $file %>") || exit(3);
   print $out '<%= $line %>' . "\n";
   close $out;
}
