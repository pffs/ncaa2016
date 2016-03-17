#!/usr/bin/perl

## This scores the men's half of the meet. Let's go Lords!
use strict;
use DBI;
use Data::Dumper;
use Switch;
use Text::Table;

my $dbname = "ncaa2015";
my $dbh = DBI->connect("dbi:Pg:dbname=$dbname", "alex", "");

## Lets grab all our data first
my $results = $dbh->selectall_hashref("SELECT * FROM results",1);
my $schools = $dbh->selectall_hashref("SELECT * FROM schools", 1);
my $events = $dbh->selectall_hashref("SELECT * FROM events WHERE gender='m'", 1);;
my $swimmers = $dbh->selectall_hashref("SELECT * FROM swimmers",1);
my $teampoints;
my $positions;

## Let's make a thing that tells us the points for a place!

sub score {
  my $points;
  switch($_[0]) {
    case 0 {$points = 20;}
    case 1 {$points = 17;}
    case 2 {$points = 16;}
    case 3 {$points = 15;}
    case 4 {$points = 14;}
    case 5 {$points = 13;}
    case 6 {$points = 12;}
    case 7 {$points = 11;}
    case 8 {$points = 9;}
    case 9 {$points = 7;}
    case 10 {$points = 6;}
    case 11 {$points = 5;}
    case 12 {$points = 4;}
    case 13 {$points = 3;}
    case 14 {$points = 2;}
    case 15 {$points = 1;}
  }
  return $points;
}

sub namifyevent {
  my $eventid = $_[0];
  my $getevent = $dbh->prepare("SELECT * FROM events WHERE id=?");
  $getevent->execute($eventid);
  my $eventinfo = $getevent->fetchrow_hashref();

  my $returnval;
  switch($eventinfo->{'gender'}) {
    case "m" {$returnval .= "Mens ";}
    case "w" {$returnval .= "Womens ";}
  }
  $returnval .= $eventinfo->{'distance'};
  $returnval .= ($eventinfo->{'stroke'} == 5 ? " mtr " : " yard ");
  switch($eventinfo->{'stroke'}) {
    case 0 {$returnval .= ($eventinfo->{"relay"} ? "Medley Relay" : "Individual Medley");}
    case 1 {$returnval .= "Butterfly";}
    case 2 {$returnval .= "Backstroke";}
    case 3 {$returnval .= "Breaststroke";}
    case 4 {$returnval .= ($eventinfo->{"relay"} ? "Freestyle Relay" : "Freestyle");}
    case 5 {$returnval .= "Diving";}
  }

return $returnval;

}
foreach my $key (keys $events) {

  #print "We are in event ".namifyevent($key)."\n";

  ## First let's see if we have finals results for the event, as we should score those otherwise.
  my $race = "prelim";
  my $checkfinals = $dbh->prepare("
    SELECT COUNT(*)
    FROM results
    WHERE event = ? AND
          race = 'final'");
  $checkfinals->execute($key);
  if (($checkfinals->fetchrow_array)[0] != 0) {
    $race = "final";
  }

  ## Now let's grab the top 16 results for our event
  my @top16;
  if ($race eq "final") {
    my $tophalf = $dbh->prepare("
      SELECT *
      FROM results
      WHERE event=:event AND
            race='final' AND
            swimmer in (
              SELECT swimmer
              FROM results
              WHERE event=:event AND
              race='prelim'
              ORDER BY time ASC
              LIMIT 8)
            ORDER BY time ASC");
    $tophalf->bind_param(':event', $key);
    $tophalf->execute();
    while (my $row = $tophalf->fetchrow_hashref) {
      push @top16, $row;
    }
    my $bottomhalf = $dbh->prepare("
      SELECT *
      FROM results
      WHERE event=:event AND
            race='final' AND
            swimmer in (
              SELECT swimmer
              FROM results
              WHERE event=:event AND
              race='prelim'
              ORDER BY time ASC
              OFFSET 8
              LIMIT 8)
            ORDER BY time ASC");
    $bottomhalf->bind_param(':event', $key);
    $bottomhalf->execute();
    while (my $row = $bottomhalf->fetchrow_hashref) {
      push @top16, $row;
    }
  } else {
    my $sth = $dbh->prepare("
      SELECT * 
      FROM results 
      WHERE event = ? AND
            race = 'prelim'
      ORDER BY time ASC
      LIMIT 16");
    $sth->execute($key);
    while (my $row = $sth->fetchrow_hashref) {
      push @top16, $row;
    }
  }
  if (scalar @top16 > 1) {
  my $tielevel = 1;
  my $tiepoints;
  for (my $i = 0; $i < scalar @top16; $i++) {
  my $currentpoints;
    ## Tie scoring nonsense.
  
    sub tiescore {
      my $subindex = shift;
      my $subarray = shift;
      my $level = shift;
      my $points = shift;
      $$points += score($subindex);
      if ($subindex+1 < @$subarray && $subarray->[$subindex]->{'time'} == $subarray->[$subindex+1]->{'time'}) {
        $$level++;
        tiescore($subindex+1, $subarray, $level, $points);
      }
      return $$points/$$level;
    }
    if ($tielevel == 1) {
      $tiepoints = tiescore($i, \@top16, \$tielevel, \$currentpoints);
    } else {
      $tielevel--;
    }
    $currentpoints = $tiepoints;
    $currentpoints*=2 if $events->{$key}->{'relay'};
    my $swimmerid = $top16[$i]->{'swimmer'};
    my $currentswimmer = $dbh->selectall_hashref("
      SELECT * FROM swimmers WHERE id=$swimmerid",1);
    $currentswimmer = $currentswimmer->{$swimmerid};
    my $schoolid = $currentswimmer->{'schoolid'};
    my $currentschool = $dbh->selectall_hashref("
      SELECT * FROM schools WHERE id=$schoolid",1);
    $currentschool = $currentschool->{$schoolid};
    $teampoints->{$currentschool->{'name'}} += $currentpoints;
    }
  }
}

## Let's print a nice little summary to show how we are scoring

## First let's figure out the last event with prelim results
my $lastprelim = $dbh->prepare("
  SELECT event
  FROM results
  WHERE race='prelim'
  ORDER BY id DESC
  LIMIT 1");
$lastprelim->execute();
my $prelimevent = ($lastprelim->fetchrow_array)[0];

my $lastfinal = $dbh->prepare("
  SELECT event
  FROM results
  WHERE race='final'
  ORDER BY id DESC
  LIMIT 1");
$lastfinal->execute();
my $finalevent = ($lastfinal->fetchrow_array)[0];


print "Men's team scores\n
Prelim results through " . namifyevent($prelimevent) . "
Finals results through " . namifyevent($finalevent) . "\n\n";

my $tb = Text::Table->new(
  "#","School", "Points"
);
my $place = 1;
my $oldplace = $place;
my $oldpoints;
foreach my $schoolname (sort { $teampoints->{$b} <=> $teampoints->{$a} } keys $teampoints) {
#  printf ("%s\t%s\n",$schoolname, $teampoints->{$schoolname});
  if ($oldpoints != $teampoints->{$schoolname}) {
    $oldplace = $place;
  }
  $tb->load([$oldplace, $schoolname, $teampoints->{$schoolname}]);
  $oldpoints = $teampoints->{$schoolname};
  $place++;
}
print $tb;


