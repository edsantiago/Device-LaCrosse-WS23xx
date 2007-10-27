#!/usr/bin/perl
#
# FIXME
#

# Get the 'canonical_name' function from Open2300.pm.  We can't just 'do'
# or 'require' the module, because the xs might not exist yet.
my $func_buffer = '';
open IN, '<', 'WS23xx.pm' or die;
while (<IN>) {
    if (/^sub\s+canonical_name/) {
	$func_buffer .= $_;
    }
    elsif ($func_buffer) {
	$func_buffer .= $_;
	if (/^\}/) {
	    close IN;
	    last;
	}
    }
}
eval $func_buffer;
die "$@" if $@;

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

	# Anything in plain parentheses, at the end, is a comment:
	#    0266 4    | LCD contrast: $BCD+1 (Read Only: ....)
	# strip it off.
	$line =~ s/\s*\(.*\)$//;

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
