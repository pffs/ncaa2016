#!/usr/bin/env perl

use HTML::TreeBuilder::XPath;
use LWP::Simple;
use Data::Dumper;
use strict;

my $url = "http://www.collegeswimming.com/results/53000/event/160316P001.htm";

my $page = get($url);
my $tree = HTML::TreeBuilder::XPath->new_from_content($page);

print $tree->findvalue('//pre');
