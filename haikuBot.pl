#!/usr/bin/perl
use DBI;
use Lingua::EN::Syllable;
use strict;
use warnings;

my $config = do("./configfile.pl");
die "Error parsing config file: $@" if $@;
die "Error reading config file: $!" unless defined $config;

my $driver   = "SQLite"; 
my $database = $config->{database};
my $dsn = "DBI:$driver:dbname=$database";
my $userid = $config->{dbuser};
my $password = $config->{dbpass};
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) 
   or die $DBI::errstr;

print "Opened database successfully\n";
 
package HaikuBot;
use base qw(Bot::BasicBot::Pluggable);
use Regexp::Profanity::US;
use Lingua::EN::Syllable;

my $regex = "^([?.!])(" . $config->{trigger} . ")\$";
my $idregex = "^([?.!])(" . $config->{triggerID} . ')';
my $new5regex = "^([?.!])(" . $config->{trigger5} . ")";
my $new7regex = "^([?.!])(" . $config->{trigger7} . ")";
my $helpregex = "^([?.!])(" . $config->{triggerHelp} . ")\$";
my $topregex = "^([?.!])(" . $config->{triggerTop} . ")\$";

sub said {
  my ($self, $message) = @_;
  if ($message->{body} =~ qr/$regex/) {
    sleep(2);
    # Statement 1
    my $stmt = qq(SELECT id, syllable, text, datetime, user_id FROM haiku WHERE syllable = 5 AND placement != 3 ORDER BY random() LIMIT 1;);
    my $sth = $dbh->prepare( $stmt );
    my $rv = $sth->execute() or die $DBI::errstr;
    if($rv < 0) { return $DBI::errstr; }
    my @row = $sth->fetchrow_array();

    # Statement 2
    my $stmt2 = qq(SELECT id, syllable, text, datetime, user_id from haiku where syllable = 7 order by random() limit 1;);
    my $sth2 = $dbh->prepare( $stmt2 );
    my $rv2 = $sth2->execute() or die $DBI::errstr;
    if($rv2 < 0) { return $DBI::errstr; }
    my @row2 = $sth2->fetchrow_array();

    # Statement 3
    my $stmt3 = qq(SELECT id, syllable, text, datetime, user_id FROM haiku WHERE syllable = 5 AND placement != 1 ORDER BY random() limit 1;);
    my $sth3 = $dbh->prepare( $stmt3 );
    my $rv3 = $sth3->execute() or die $DBI::errstr;
    if($rv3 < 0) { return $DBI::errstr; }
    my @row3 = $sth3->fetchrow_array();

    # Haiku
    my $haikuMsg = $row[2] . " / " . $row2[2] . " / " . $row3[2];
    my $haikuID = saveHaiku($haikuMsg, $message->{who});
    return $haikuMsg . " -- `\?$config->{triggerVote} $haikuID` -- $config->{URL}";
  } 

  #Haiku by ID
  if ($message->{body} =~ qr/$idregex/) {
    $message->{body} =~ qr/$idregex\s+(.*)$/;
    my $results = haikuID($3);
    #$message->{channel} = 'msg';
    return $results;
  }

  #Create new 5 syllable haiku
  if ($message->{body} =~ qr/$new5regex/) {
    $message->{body} =~ qr/$new5regex\s(.*)$/;
    my @text = split /\|/, $1;
    my $syllables = syllableCheck($text[0]);
    if( $syllables == 5 ) {
      return newHaiku(5,$text[0],$message->{who},$text[1], $message);
    } else {
      return "Syllable Check Failed: " . $syllables;
    }
  }

  #Create new 7 syllable haiku
  if ($message->{body} =~ qr/$new7regex/) {
    $message->{body} =~ qr/$new7regex\s(.*)$/;
    my @text = split /\|/, $1;
    my $syllables = syllableCheck($text[0]);
    if( $syllables == 7 ) {
      return newHaiku(7,$text[0],$message->{who},$text[1], $message);
    } else {
      return "Syllable Check Failed: " . $syllables;
    }
  }

  #Haiku Stats
  my $statsregex = "^([?.!])(" . $config->{triggerStats} . ")\$";
  if ($message->{body} =~ qr/$statsregex/) {
    return haikuStats();
  }
  
  #Vote for generated Haiku
  my $voteregex = "^([?.!])(" . $config->{triggerVote} . ")";
  if ($message->{body} =~ qr/$voteregex/) {
    $message->{body} =~ qr/$voteregex\s(.*)$/;
    return haikuVote($1, $message->{who}, $message);
  }

  #Haiku Help
  if ($message->{body} =~ qr/$helpregex/) {
    my $helpText =  $config->{helpText};
    $self->say(
      who => $message->{who},
      channel => 'msg',
      body => $helpText,
    );
  }

  #Top 5
  if ($message->{body} =~ qr/$topregex/) {
    my $results = haikuTop(5,$message);
    $message->{channel} = 'msg';
    return $results;
  }

  return;
}

#sub help {
#  "Base Commands: !haiku -- !haikuhelp for more"
#}

sub haikuStats {
  my $stmt = qq(SELECT SUM(CASE WHEN syllable = 5 THEN 1 END) AS syl5, SUM(CASE WHEN syllable = 5 AND (placement = 0 OR placement = 1) THEN 1 END) AS syl5a, SUM(CASE WHEN syllable = 7 THEN 1 END) AS syl7, SUM(CASE WHEN syllable = 5 AND (placement = 0 OR placement = 3) THEN 1 END) AS syl5b FROM haiku;);
  my $sth = $dbh->prepare( $stmt );
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) { return $DBI::errstr; }
  my @row = $sth->fetchrow_array();
  return "5 Syllable Lines: " . $row[0] . " | 7 Syllable Lines: " . $row[2] . " | Possible Permutations: " . commify(($row[1] * $row[2] * ($row[3]-1)));
}

sub newHaiku {
  my $syllable = shift;
  my $text = shift;
  my $user_id = shift;
  my $placement = shift;
  my $message = shift;
  if(! defined $placement || ($placement != 1 && $placement != 3)) { $placement = 0; }
  if( canInsert($user_id) == 1 ) {
    my $stmt = qq(INSERT INTO haiku (syllable,text,datetime,user_id,placement) 
      SELECT ?, ?, datetime('now'), ?, ? 
      WHERE NOT EXISTS (SELECT 1 FROM haiku WHERE lower(text) = lower(?)));
    my $sth = $dbh->prepare( $stmt );
    my $profane = profane($text, $config->{degree});
    if($profane eq "0") {
      my $rv = $dbh->do($stmt, undef, $syllable, $text, $user_id, $placement, $text) or die $DBI::errstr;
    } 
    return "New $syllable Syllable Haiku Added: $text";
  } else {
    return "User Not Authorized -- Msg " . $config->{botOwner} . " for access";
  }
}

sub saveHaiku {
  my $text = shift;
  my $user_id = shift;
  my $stmt = qq(INSERT INTO generated_haiku (haiku,datetime,user_id) 
    SELECT ?, datetime('now'), ? 
    WHERE NOT EXISTS (SELECT 1 FROM generated_haiku WHERE lower(haiku) = lower(?)));
  my $sth = $dbh->prepare( $stmt );
  my $rv = $dbh->do($stmt, undef, $text, $user_id, $text) or die $DBI::errstr;
  my $rowid = $dbh->last_insert_id();

  return $rowid; 
}

sub haikuVote {
  my $haikuID = shift;
  my $user_id = shift;
  my $message = shift;
  if(!$haikuID || !$user_id || !$message) { return "Missing ID -- See more: " . $config->{URL} . " -- See ?" . $config->{triggerHelp}; }
  my $stmt = qq(INSERT INTO haiku_votes (haiku_id, user_id, datetime) 
    SELECT ?, ?, datetime('now')
    WHERE NOT EXISTS (SELECT 1 FROM haiku_votes WHERE haiku_id = ? AND user_id = ?));
  my $sth = $dbh->prepare( $stmt );
  my $rv = $dbh->do($stmt, undef, $haikuID, $user_id, $haikuID, $user_id) or die $DBI::errstr;
  $message->{channel} = 'msg';
  return "Thanks for voting! See more: " . $config->{URL} . " -- See ?" . $config->{triggerHelp};
}

sub haikuID {
  my $id = shift;
  if(!$id) { return "Missing ID -- See more: " . $config->{URL} . " -- See ?" . $config->{triggerHelp}; }
  my $stmt = "SELECT id, haiku FROM generated_haiku WHERE id = ? ORDER BY datetime";
  my $sth = $dbh->prepare( $stmt );
  $sth->bind_param(1, $id);
  $sth->execute() or die $DBI::errstr;
  my $data = $sth->fetchall_arrayref();
  my $results;
  for my $row (@$data) {
    my ($rowid, $haiku) = @$row;
    $results .= $rowid . ": " . $haiku . "\n";
  }
  return $results;
}

sub haikuTop {
  my ($top, $message) = @_;
  my $stmt;

  $stmt = qq(SELECT h.id, count(hv.haiku_id) as votes, h.haiku, h.datetime 
    FROM generated_haiku h 
    INNER JOIN haiku_votes hv ON h.id = hv.haiku_id 
    GROUP BY h.id ORDER BY votes DESC, h.datetime DESC LIMIT ?);

  my $sth = $dbh->prepare( $stmt );
  $sth->bind_param(1, $top);
  $sth->execute() or die $DBI::errstr;
  my $data = $sth->fetchall_arrayref();
  my $results;
  for my $row (@$data) {
    my ($rowid, $count, $haiku, $datetime) = @$row;
    $results .= "Votes: " . $count . " -- " . "ID: " . $rowid . " -- " . $haiku . "\n";
  }
  $results .= "Upvote using: ?" . $config->{triggerVote} . " <ID> -- See ?" . $config->{triggerHelp} . "\n";
  return $results;
}

sub commify {
  my $text = reverse $_[0];
  $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $text
}

sub connected {
  my $self = shift;
  $self->mode($self->nick, '+B');
}

sub syllableCheck {
  my $haiku = shift;
  my $sylTotal = 0;
  my @hArray = split /\s+/, $haiku;
  foreach (@hArray) {
    $sylTotal = syllable($_) + $sylTotal;
  }
  return $sylTotal;
}

sub canInsert {
  my $user_id = shift;
  my $stmt = qq(SELECT authlevel FROM users WHERE username = \"$user_id\");
  my $sth = $dbh->prepare( $stmt );
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0) { return 0; }
  my @row = $sth->fetchrow_array();
  if(@row && $row[0] <= 2) { return 1; } else { return 0; }
}

my $bot = HaikuBot->new(
    server      => $config->{ircServer},
    port        => $config->{ircPort},
    channels    => $config->{ircChannels},
    nick        => $config->{ircNick},
    password    => $config->{ircPass},
    name        => $config->{ircName},
    ssl         => $config->{ircSSL},
)->run();
HaikuBot->load("Log");

