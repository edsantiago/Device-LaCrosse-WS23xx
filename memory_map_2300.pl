#!/usr/bin/perl
#
# FIXME
#

# Get the 'canonical_name' function from Open2300.pm
# FIXME
sub canonical_name {
    my $desc = $1;
    my $canonical_name = '';

    # Min or Max?
    if ($desc =~ s/\bmin(imum)?\b/ /i) {
	$canonical_name .= 'Min_';
    }
    elsif ($desc =~ s/\bmax(imum)?\b/ /i) {
	$canonical_name .= 'Max_';
    }
    elsif ($desc =~ s/\b(High|Low)\s*Alarm\b/ /i) {
	$canonical_name .= ucfirst(lc($1)) . '_Alarm_';
    }
    elsif ($desc =~ s/\bCurrent\b/ /i) {
	# do nothing
    }

    # Where?
    if ($desc =~ s/\b(indoor|outdoor)s?\b/ /i) {
	$canonical_name .= ucfirst(lc($1)) . '_';
    }

    # What: Temperature, Windchill, Pressure, ...
    if ($desc =~ s/\btemp(erature)?\b/ /i) {
	$canonical_name .= 'Temperature';
    }
    elsif ($desc =~ s/\bPress(ure)?\b/ /i) {
	$desc =~ s/\bair\b/ /i;

	if ($desc =~ s/\b(Absolute|Relative)\b/ /i) {
	    $canonical_name .= ucfirst(lc($1)) . '_';
	}
	$canonical_name .= 'Pressure';
	if ($desc =~ s/\bCorrection\b/ /i) {
	    $canonical_name .= '_Correction';
	}
    }
    elsif ($desc =~ s/\b(Humidity|Windchill|Dewpoint)\b/ /i) {
	$canonical_name .= ucfirst(lc($1));
	$desc =~ s/\bRel(ative)?\b/ /i;
    }
    elsif ($desc =~ s/\b(Rain)\b//i) {
	$canonical_name .= "Rain";
	if ($desc =~ s/\b(1|24)(\s*h(ou)?r?)?\b//i) {
	    $canonical_name .= "_$1hour";
	}
	elsif ($desc =~ s/\btotal\b//i) {
	    $canonical_name .= "_Total";
	}
    }
    else {
	(my $tmp = $desc) =~ s/\s+/_/g;
	$canonical_name .= $tmp;
	# FIXME: warn?
    }

    # Is this a date/time field?
    if ($desc =~ s!\bDate/Time\b! !i) {
	$canonical_name .= '_datetime';
    }

    if ($desc =~ /\S/) {
	warn "leftover: $desc\n";
    }

    $canonical_name =~ s/_$//;

    return $canonical_name;
}

# Read the memory map, write out FIXME
(my $mapfile = $0) =~ s!^(.*/)?(.*)\.pl$!$2.txt!;
open IN, "<$mapfile"
  or die "Cannot read $mapfile: $!";

my @map;
my %macro;
my $previous_address;
while (my $line = <IN>) {
    chomp $line;
    $line =~ s/\s+$//;			# Remove trailing whitespace

    # E.g. 0019 0   alarm set flags
    if ($line =~ s!^([0-9a-f]{4})\s+[0-9a-f]\s*!!i) {
	my $address = hex($1);

	# This is not expected to trigger: check the sequence
	if (defined $previous_address) {
	    $address == $previous_address+1
	      or die sprintf("$mapfile:$.: Error between %04X and %04X",
			     $previous_address, $address);
	}
	$previous_address = $address;

	# Is it a definition line?
	if ($line =~ m!^\|\s+([^ 0-9].*?)\s*:\s*(.*)!) {
	    my ($desc, $formula) = ($1, $2);
	    push @map, {
			desc => $desc,
			name => canonical_name($desc),
			address => $address,
			length => 1,
			   };

	    # FIXME: formula
	    $formula =~ s{<(\S+)>}{
		my $key = $1;
		defined $macro{$key}
		  or die "$mapfile:$.: Undefined macro <$key>";
		$macro{$key};
	    }ge;

	    if ($formula =~ s/\s*\[(.*)\]\s*//) {
		$map[-1]->{units} = $1;
	    }

	    $map[-1]->{formula} = $formula;
	}
	elsif ($line =~ m!^_/!) {
	    my $l = $address - $map[-1]->{address} + 1;
	    if ($l > 10) {
		die "$mapfile:$.: preposterous length";
	    }
	    $map[-1]->{length} = $l;
	}
    }
    elsif ($line =~ /^\s*macro \s+ (\S+) \s+ = \s+ (\S.*\S)/x) {
	$macro{$1} = $2;
    }
    else {
	# FIXME: check for macro definition lines
    }
}

for my $entry (@map) {
    my $name = $entry->{name};
    if (my $units = $entry->{units}) {
	$name .= " [$units]";
    }

    printf "%04X:%-2d %-40s %s\n", @{$entry}{"address","length"},
      $name, $entry->{formula};
}
