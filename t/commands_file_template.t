#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;

use File::Basename;

use Rex::Commands::File;
use Rex::Commands::Template;

my $basename = basename __FILE__;

{
  # templates from file
  my $tpl =
    Rex::Helper::File::Spec->catfile( dirname(__FILE__), 'commands', 'file',
    'test.tpl', );
  my $content = template $tpl, basename => $basename;

  is $content, $basename . "\n", "template from file";
}

{
  # test templates from __DATA__
  my $content = template
    '@second.tpl',
    basename => $basename;

  is $content, $basename . "\n", "second template from __DATA__";

  my $name          = 'Rex';
  my $content_first = template
    '@first.tpl',
    name => { test => $name };

  is $content_first, $name . "\n", "first template from __DATA__";
}

{
  # passing template content
  my $content = template
    \'<%= $basename %>',
    basename => $basename;

  is $content, $basename, "passing template content";
}

__DATA__
@first.tpl
<%= $name->{test} %>
@end
@second.tpl
<%= $basename %>
@end
