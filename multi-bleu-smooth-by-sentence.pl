#!/usr/bin/perl -w

# Adapted from Philip Koehn's scorer by Wade Shen <swade@ll.mit.edu>
# Copyright 2005 Massachusetts Institute of Technology, Lincoln Laboratory
# Copyright 2004 Philip Koehn
# Revision: $Id: multi-bleu.pl,v 1.2 2005/08/02 04:06:41 swade Exp $

### KLM  -- version to report scores for each sentence

### revised by KLM 
# to facilitate sentence-level scoring, revised this to match the smoothing algorithm used in mteval 
# since multi-bleu.pl by design gives 0 values when there are no matching 4-grams

# also revised to prevent division by zero for very short hypothesis files
# e.g., "Thank you" has no trigrams or 4-grams, so need to prevent calcuations of trigrams-correct/total-trigrams
# TODO test this thoroughly

# NOTE:  mteval uses tokenization that differs from tokenizer.perl
# e.g., mteval does not split [don't] into [don 't]
# and this makes some scores differ

# NOTE: the smoothing has only been tested so far on files containing a single line
# generally don't need smoothing over a longer file, since there are probably at least some matching 4-grams

use strict;
my @REF;

# philip's old system stem . refnumber
#my $stem = $ARGV[0];
#my $ref=0;
#while(-e "$stem$ref") {
#    &add_to_ref("$stem$ref",\@REF);
#    $ref++;
#}
#&add_to_ref($stem,\@REF) if -e $stem;

foreach my $rf (@ARGV)
{ add_to_ref($rf, \@REF); }

sub add_to_ref {
    my ($file,$REF) = @_;
    my $s=0;
    open(REF,$file);
    while(<REF>) {
	chop;
	push @{$$REF[$s++]}, $_;
	#print "recorded reference line, $_\n"; 
    }
    close(REF);
}

my(@CORRECT,@TOTAL,$length_translation,$length_reference);
@CORRECT = (0.0, 0.0, 0.0, 0.0, 0.0);
@TOTAL = (0.0, 0.0, 0.0, 0.0, 0.0);
my $s=0;
my $hypothesisLine;
my $referenceLine; 
while(<STDIN>) {
	# reset counts for this sentence
	my @sentence_CORRECT = (0.0, 0.0, 0.0, 0.0, 0.0);
	my @sentence_TOTAL = (0.0, 0.0, 0.0, 0.0, 0.0);
	print "------------------------------\n"; 
    chop;
    $hypothesisLine = $_; 
    #print "read hypothesis, $hypothesisLine\n"; 
    my @WORD = split;
    my %REF_NGRAM = ();
    my $length_translation_this_sentence = scalar(@WORD);
    #print "hypothesis: @WORD\n"; 
    my ($closest_diff,$closest_length) = (9999,9999);
    foreach my $reference (@{$REF[$s]}) {
    	$referenceLine = $reference;   ## we are only using single references
    print "reference: $referenceLine\n";
    print "hypothesis: $hypothesisLine\n\n"; 
      #print "$s $_ <=> $reference\n";
	my @WORD = split(/ /,$reference);
	my $length = scalar(@WORD);
	if (abs($length_translation_this_sentence-$length) < $closest_diff) {
	    $closest_diff = abs($length_translation_this_sentence-$length);
	    $closest_length = $length;
	#print "$s: closest diff = abs($length_translation_this_sentence-$length)<BR>\n";
	}
	# collect unigrams, then bigrams, etc.  
	for(my $n=1;$n<=4;$n++) {
	    my %REF_NGRAM_N = ();
	    for(my $start=0;$start<=$#WORD-($n-1);$start++) {
		my $ngram = "$n";
		#print "starting with ngram $ngram\n";
		for(my $w=0;$w<$n;$w++) {
		    $ngram .= " ".$WORD[$start+$w];
		 #   print "making it $ngram\n";
		}
		$REF_NGRAM_N{$ngram}++;
		#print "adding ngram ($ngram) to ref-ngram-n\n";
	    }
	    foreach my $ngram (keys %REF_NGRAM_N) {
	    #print "checking $ngram\n";
if (defined($REF_NGRAM{$ngram})) {
#print "already defined in other structure, ref-ngram\n";
}
# print "ref-ngram-n $REF_NGRAM_N{$ngram}\n";
		if (!defined($REF_NGRAM{$ngram}) || 
		    $REF_NGRAM{$ngram} < $REF_NGRAM_N{$ngram}) {
		    $REF_NGRAM{$ngram} = $REF_NGRAM_N{$ngram};
#print "adding ($ngram) to other structure ref-ngram\n";
#ref-ngram stores counts
	    #print "$s: REF_NGRAM{$ngram} = $REF_NGRAM{$ngram}<BR>\n";
		}
	    }
	}
    }
    $length_translation += $length_translation_this_sentence;
    $length_reference += $closest_length;
    for(my $n=1;$n<=4;$n++) {
	my %T_NGRAM = ();
	for(my $start=0;$start<=$#WORD-($n-1);$start++) {
	    my $ngram = "$n";
	    for(my $w=0;$w<$n;$w++) {
		$ngram .= " ".$WORD[$start+$w];
	    }
	    $T_NGRAM{$ngram}++;
	}
	foreach my $ngram (keys %T_NGRAM) {
	    $ngram =~ /^(\d+) /;
	    my $n = $1;
	#print "$s e $ngram $T_NGRAM{$ngram}<BR>\n";
	    $TOTAL[$n] += $T_NGRAM{$ngram};
	    $sentence_TOTAL[$n] += $T_NGRAM{$ngram};
	    if (defined($REF_NGRAM{$ngram})) {
		if ($REF_NGRAM{$ngram} >= $T_NGRAM{$ngram}) {
		    $CORRECT[$n] += $T_NGRAM{$ngram};
		    $sentence_CORRECT[$n] += $T_NGRAM{$ngram};
	   # print "$s e correct1 $T_NGRAM{$ngram}<BR>\n";
		}
		else {
		    $CORRECT[$n] += $REF_NGRAM{$ngram};
		    $sentence_CORRECT[$n] += $REF_NGRAM{$ngram};
	    #print "$s e correct2 $REF_NGRAM{$ngram}<BR>\n";
		}
	    }
	}
    }
    $s++;
#  }   ## former end of while <STDIN>

my $sentence_brevity_penalty = 1;
#print "total unigrams $TOTAL[1]\n";
#print "total bigrams $TOTAL[2]\n";
#print "total trigrams $TOTAL[3]\n";
#print "total 4grams $TOTAL[4]\n";

   # print "reference: $referenceLine\n";
   # print "hypothesis: $hypothesisLine\n"; 

#$length_translation_this_sentence/$closest_length;
#if ($length_translation<$length_reference) {
if ($length_translation_this_sentence<$closest_length) {
	print "translation shorter than reference, assessing brevity penalty\n";
   #print "reference length $closest_length, translation length $length_translation_this_sentence\n";
   # $sentence_brevity_penalty = exp(1-$length_reference/$length_translation);
   $sentence_brevity_penalty = exp(1-$closest_length/$length_translation_this_sentence);
}
#print "reference length $length_reference, translation length $length_translation\n";
print "reference length $closest_length, translation length $length_translation_this_sentence\n";
print "brevity penalty $sentence_brevity_penalty\n"; 


## original calcuation, no smoothing ##
# 	my $bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] ) +
#				   my_log( $CORRECT[2]/$TOTAL[2] ) +
#				   my_log( $CORRECT[3]/$TOTAL[3] ) +
#				   my_log( $CORRECT[4]/$TOTAL[4] ) ) / 4);

# my $sentence_bleu;
my $sentence_bleu = 0; ## avoid problem when line contains * 
my $sentence_fourgram;
my $sentence_trigram;
my $sentence_bigram; 

# for very short hypothesis sentences, may have 0 values for $TOTAL[4], $TOTAL[3], or even $TOTAL[2]
# this leads to division by 0 unless we screen for it

# note:  if number of matching 4-grams > 0, then we know we have 4-grams in the hypothesis, and we don't have to worry about division by zero
# if number of matching trigrams > 0, then we know we have trigrams in the hypothesis, but we do have to check for 4-grams
# etc. 

if ($sentence_CORRECT[4]>0) {
	print "normal multi-bleu scoring\n"; 
	$sentence_bleu = $sentence_brevity_penalty * exp((my_log( $sentence_CORRECT[1]/$sentence_TOTAL[1] ) +
			my_log( $sentence_CORRECT[2]/$sentence_TOTAL[2] ) +
			my_log( $sentence_CORRECT[3]/$sentence_TOTAL[3] ) +
			my_log( $sentence_CORRECT[4]/$sentence_TOTAL[4] ) ) / 4);
} elsif ($sentence_CORRECT[3]>0)  {
	if ($sentence_TOTAL[4]>0) {
		print "no 4-gram matches, smoothing 4-gram count to 0.5\n"; 
		$sentence_fourgram = 0.5;
		$sentence_bleu = $sentence_brevity_penalty * exp((my_log( $sentence_CORRECT[1]/$sentence_TOTAL[1] ) +
				my_log( $sentence_CORRECT[2]/$sentence_TOTAL[2] ) +
				my_log( $sentence_CORRECT[3]/$sentence_TOTAL[3] ) +
				my_log( $sentence_fourgram/$sentence_TOTAL[4] ) ) / 4);
	} else {
		# prevent division by zero
		print "no 4-grams in hypothesis, calculating BLEU for trigrams\n";
		$sentence_bleu = $sentence_brevity_penalty * exp((my_log( $sentence_CORRECT[1]/$sentence_TOTAL[1] ) +
				my_log( $sentence_CORRECT[2]/$sentence_TOTAL[2] ) +
				my_log( $sentence_CORRECT[3]/$sentence_TOTAL[3] )) / 3);
	} # end if else have some 4-grams in hypothesis

} elsif ($sentence_CORRECT[2]>0) {
	if ($sentence_TOTAL[4]>0) {
		print "no trigram matches, smoothing trigram count to 0.5, smoothing 4-gram count to 0.25\n";
		$sentence_trigram = 0.5;
		$sentence_fourgram = 0.25;
		$sentence_bleu = $sentence_brevity_penalty * exp((my_log( $sentence_CORRECT[1]/$sentence_TOTAL[1] ) +
				my_log( $sentence_CORRECT[2]/$sentence_TOTAL[2] ) +
				my_log( $sentence_trigram/$sentence_TOTAL[3] ) +
				my_log( $sentence_fourgram/$sentence_TOTAL[4] ) ) / 4);
	} elsif ($sentence_TOTAL[3]>0) {
		# prevent division by 0 for 4-grams
		print "no 4-grams in hypothesis, calculating BLEU for trigrams\n";
		print "no trigram matches, smoothing trigram count to 0.5\n";
		$sentence_trigram = 0.5;
		$sentence_bleu = $sentence_brevity_penalty * exp((my_log( $sentence_CORRECT[1]/$sentence_TOTAL[1] ) +
				my_log( $sentence_CORRECT[2]/$sentence_TOTAL[2] ) +
				my_log( $sentence_CORRECT[3]/$sentence_TOTAL[3] )) / 3);		
	} else {
		# prevent division by 0 for 4-grams and 3-grams
		print "no 4-grams or trigrams in hypothesis, calculating BLEU for bigrams\n";
		$sentence_bleu = $sentence_brevity_penalty * exp((my_log( $sentence_CORRECT[1]/$sentence_TOTAL[1] ) +
				my_log( $sentence_CORRECT[2]/$sentence_TOTAL[2] )) / 2); 
	} # end if else else have some 4-grams, have some trigrams in hypothesis
				   
} elsif ($sentence_CORRECT[1]>0) {
	if ($sentence_TOTAL[4]>0) {
		print "no bigram matches, smoothing bigram count to 0.5, trigram count to 0.25, and 4-gram count to 0.125\n";
		$sentence_bigram = 0.5; 
		$sentence_trigram = 0.25;
		$sentence_fourgram = 0.125;
		$sentence_bleu = $sentence_brevity_penalty * exp((my_log( $sentence_CORRECT[1]/$sentence_TOTAL[1] ) +
				my_log( $sentence_bigram/$sentence_TOTAL[2] ) +
				my_log( $sentence_trigram/$sentence_TOTAL[3] ) +
				my_log( $sentence_fourgram/$sentence_TOTAL[4] ) ) / 4);
	} elsif ($sentence_TOTAL[3]>0) {
		# prevent division by 0 for 4-grams
		print "no 4-grams in hypothesis, calculating BLEU for trigrams\n";
		print "no bigram matches, smoothing bigram count to 0.5, trigram count to 0.25\n";
		$sentence_bigram = 0.5; 
		$sentence_trigram = 0.25;
		$sentence_bleu = $sentence_brevity_penalty * exp((my_log( $sentence_CORRECT[1]/$sentence_TOTAL[1] ) +
				my_log( $sentence_CORRECT[2]/$sentence_TOTAL[2] ) +
				my_log( $sentence_CORRECT[3]/$sentence_TOTAL[3] )) / 3); 		
	} elsif ($sentence_TOTAL[2]>0)  {
		# prevent division by 0 for 4-grams and trigrams
		print "no 4-grams or trigrams in hypothesis, calculating BLEU for bigrams\n";
		print "no bigram matches, smoothing bigram count to 0.5\n";
		$sentence_bigram = 0.5; 
		$sentence_bleu = $sentence_brevity_penalty * exp((my_log( $sentence_CORRECT[1]/$sentence_TOTAL[1] ) +
				my_log( $sentence_CORRECT[2]/$sentence_TOTAL[2] )) / 2);
	} else {
		# not even any bigrams
		# prevent division by 0 for 4-grams, trigrams, bigrams
		print "no 4-grams, trigrams, or bigrams in hypothesis, calculating BLEU for unigrams\n";
		$sentence_bleu = $sentence_brevity_penalty * exp((my_log( $sentence_CORRECT[1]/$sentence_TOTAL[1] )));
	} # end if else else else have some 4-grams, have some trigrams, have some bigrams in hypothesis

} # end if else else have matching 4-grams, trigrams, bigrams, unigrams


# prevent division by 0 for very small hypothesis sentences like "Thank you"
if ($sentence_TOTAL[4] > 0) {
#printf "BLEU = %.2f, %.1f/%.1f/%.1f/%.1f \n(BP=%.3f, ration=%.3f):$sentence_CORRECT[1]:$sentence_TOTAL[1]:=$sentence_CORRECT[2]:total=$sentence_TOTAL[2]:$sentence_CORRECT[3]:$sentence_TOTAL[3]:$sentence_CORRECT[4]:$sentence_TOTAL[4]:$length_reference\n",
printf "BLEU = %.2f, %.1f/%.1f/%.1f/%.1f \n(BP=%.3f, ration=%.3f):$sentence_CORRECT[1]:$sentence_TOTAL[1]:=$sentence_CORRECT[2]:total=$sentence_TOTAL[2]:$sentence_CORRECT[3]:$sentence_TOTAL[3]:$sentence_CORRECT[4]:$sentence_TOTAL[4]:$closest_length\n",
    100*$sentence_bleu,
    100*$sentence_CORRECT[1]/$sentence_TOTAL[1],
    100*$sentence_CORRECT[2]/$sentence_TOTAL[2],
    100*$sentence_CORRECT[3]/$sentence_TOTAL[3],
    100*$sentence_CORRECT[4]/$sentence_TOTAL[4],
    $sentence_brevity_penalty,
   $length_translation_this_sentence/$closest_length;
      # $length_translation / $length_reference;
   #print "reference length $closest_length, translation length $length_translation_this_sentence\n";
print "\nbleu $sentence_bleu\n$sentence_CORRECT[1]/$sentence_TOTAL[1] unigrams, $sentence_CORRECT[2]/$sentence_TOTAL[2] bigrams, $sentence_CORRECT[3]/$sentence_TOTAL[3] trigrams, $sentence_CORRECT[4]/$sentence_TOTAL[4] 4grams\n";
} elsif ($sentence_TOTAL[3] > 0) {
print "[no 4-grams]\n"; 
# printf "BLEU = %.2f, %.1f/%.1f/%.1f/\n(BP=%.3f, ration=%.3f):$sentence_CORRECT[1]:$sentence_TOTAL[1]:=$sentence_CORRECT[2]:total=$sentence_TOTAL[2]:$sentence_CORRECT[3]:$sentence_TOTAL[3]:$sentence_CORRECT[4]:$sentence_TOTAL[4]:$length_reference\n",
printf "BLEU = %.2f, %.1f/%.1f/%.1f/\n(BP=%.3f, ration=%.3f):$sentence_CORRECT[1]:$sentence_TOTAL[1]:=$sentence_CORRECT[2]:total=$sentence_TOTAL[2]:$sentence_CORRECT[3]:$sentence_TOTAL[3]:$sentence_CORRECT[4]:$sentence_TOTAL[4]:$closest_length\n",
    100*$sentence_bleu,
    100*$sentence_CORRECT[1]/$sentence_TOTAL[1],
    100*$sentence_CORRECT[2]/$sentence_TOTAL[2],
    100*$sentence_CORRECT[3]/$sentence_TOTAL[3],
  #  100*$sentence_CORRECT[4]/$sentence_TOTAL[4],
    $sentence_brevity_penalty,
    $length_translation_this_sentence/$closest_length;
    #$length_translation / $length_reference;
print "\nbleu $sentence_bleu\n$sentence_CORRECT[1]/$sentence_TOTAL[1] unigrams, $sentence_CORRECT[2]/$sentence_TOTAL[2] bigrams, $sentence_CORRECT[3]/$sentence_TOTAL[3] trigrams, $sentence_CORRECT[4]/$sentence_TOTAL[4] 4grams\n";
} elsif ($sentence_TOTAL[2] > 0) {
print "[no 4-grams or trigrams]\n"; 
#printf "BLEU = %.2f, %.1f/%.1f//\n(BP=%.3f, ration=%.3f):$sentence_CORRECT[1]:$sentence_TOTAL[1]:=$sentence_CORRECT[2]:total=$sentence_TOTAL[2]:$sentence_CORRECT[3]:$sentence_TOTAL[3]:$sentence_CORRECT[4]:$sentence_TOTAL[4]:$length_reference\n",
printf "BLEU = %.2f, %.1f/%.1f//\n(BP=%.3f, ration=%.3f):$sentence_CORRECT[1]:$sentence_TOTAL[1]:=$sentence_CORRECT[2]:total=$sentence_TOTAL[2]:$sentence_CORRECT[3]:$sentence_TOTAL[3]:$sentence_CORRECT[4]:$sentence_TOTAL[4]:$closest_length\n",
    100*$sentence_bleu,
    100*$sentence_CORRECT[1]/$sentence_TOTAL[1],
    100*$sentence_CORRECT[2]/$sentence_TOTAL[2],
  #  100*$sentence_CORRECT[3]/$sentence_TOTAL[3],
  #  100*$sentence_CORRECT[4]/$sentence_TOTAL[4],
    $sentence_brevity_penalty,
    $length_translation_this_sentence/$closest_length;
  #  $length_translation / $length_reference;
print "\nbleu $sentence_bleu\n$sentence_CORRECT[1]/$sentence_TOTAL[1] unigrams, $sentence_CORRECT[2]/$sentence_TOTAL[2] bigrams, $sentence_CORRECT[3]/$sentence_TOTAL[3] trigrams, $sentence_CORRECT[4]/$sentence_TOTAL[4] 4grams\n";
} elsif ($sentence_TOTAL[1] > 0) {
print "[no 4-grams or trigrams or bigrams]\n"; 
#printf "BLEU = %.2f, %.1f///\n(BP=%.3f, ration=%.3f):$sentence_CORRECT[1]:$sentence_TOTAL[1]:=$sentence_CORRECT[2]:total=$sentence_TOTAL[2]:$sentence_CORRECT[3]:$sentence_TOTAL[3]:$sentence_CORRECT[4]:$sentence_TOTAL[4]:$length_reference\n",
printf "BLEU = %.2f, %.1f///\n(BP=%.3f, ration=%.3f):$sentence_CORRECT[1]:$sentence_TOTAL[1]:=$sentence_CORRECT[2]:total=$sentence_TOTAL[2]:$sentence_CORRECT[3]:$sentence_TOTAL[3]:$sentence_CORRECT[4]:$sentence_TOTAL[4]:$closest_length\n",
    100*$sentence_bleu,
    100*$sentence_CORRECT[1]/$sentence_TOTAL[1],
  #  100*$sentence_CORRECT[2]/$sentence_TOTAL[2],
  #  100*$sentence_CORRECT[3]/$sentence_TOTAL[3],
  #  100*$sentence_CORRECT[4]/$sentence_TOTAL[4],
    $sentence_brevity_penalty,
    $length_translation_this_sentence/$closest_length;
   # $length_translation / $length_reference;
print "\nbleu $sentence_bleu\n$sentence_CORRECT[1]/$sentence_TOTAL[1] unigrams, $sentence_CORRECT[2]/$sentence_TOTAL[2] bigrams, $sentence_CORRECT[3]/$sentence_TOTAL[3] trigrams, $sentence_CORRECT[4]/$sentence_TOTAL[4] 4grams\n";

} # end if else else else have some 4-grams etc. in hypothesis




} # end while <STDIN>
print "\n----- totals for file -----\n";
####### scores for entire file #########
my $brevity_penalty = 1;
#print "total unigrams $TOTAL[1]\n";
#print "total bigrams $TOTAL[2]\n";
#print "total trigrams $TOTAL[3]\n";
#print "total 4grams $TOTAL[4]\n";

   # print "reference: $referenceLine\n";
   # print "hypothesis: $hypothesisLine\n"; 

if ($length_translation<$length_reference) {
	print "translation shorter than reference, assessing brevity penalty\n";
    $brevity_penalty = exp(1-$length_reference/$length_translation);
}
print "reference length $length_reference, translation length $length_translation\n";
print "brevity penalty $brevity_penalty\n"; 


## original calcuation, no smoothing ##
# 	my $bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] ) +
#				   my_log( $CORRECT[2]/$TOTAL[2] ) +
#				   my_log( $CORRECT[3]/$TOTAL[3] ) +
#				   my_log( $CORRECT[4]/$TOTAL[4] ) ) / 4);

my $bleu = 0;
my $fourgram;
my $trigram;
my $bigram; 

# for very short hypothesis sentences, may have 0 values for $TOTAL[4], $TOTAL[3], or even $TOTAL[2]
# this leads to division by 0 unless we screen for it

# note:  if number of matching 4-grams > 0, then we know we have 4-grams in the hypothesis, and we don't have to worry about division by zero
# if number of matching trigrams > 0, then we know we have trigrams in the hypothesis, but we do have to check for 4-grams
# etc. 

if ($CORRECT[4]>0) {
	print "normal multi-bleu scoring\n"; 
	$bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] ) +
			my_log( $CORRECT[2]/$TOTAL[2] ) +
			my_log( $CORRECT[3]/$TOTAL[3] ) +
			my_log( $CORRECT[4]/$TOTAL[4] ) ) / 4);
} elsif ($CORRECT[3]>0)  {
	if ($TOTAL[4]>0) {
		print "no 4-gram matches, smoothing 4-gram count to 0.5\n"; 
		$fourgram = 0.5;
		$bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] ) +
				my_log( $CORRECT[2]/$TOTAL[2] ) +
				my_log( $CORRECT[3]/$TOTAL[3] ) +
				my_log( $fourgram/$TOTAL[4] ) ) / 4);
	} else {
		# prevent division by zero
		print "no 4-grams in hypothesis, calculating BLEU for trigrams\n";
		$bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] ) +
				my_log( $CORRECT[2]/$TOTAL[2] ) +
				my_log( $CORRECT[3]/$TOTAL[3] )) / 3);
	} # end if else have some 4-grams in hypothesis

} elsif ($CORRECT[2]>0) {
	if ($TOTAL[4]>0) {
		print "no trigram matches, smoothing trigram count to 0.5, smoothing 4-gram count to 0.25\n";
		$trigram = 0.5;
		$fourgram = 0.25;
		$bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] ) +
				my_log( $CORRECT[2]/$TOTAL[2] ) +
				my_log( $trigram/$TOTAL[3] ) +
				my_log( $fourgram/$TOTAL[4] ) ) / 4);
	} elsif ($TOTAL[3]>0) {
		# prevent division by 0 for 4-grams
		print "no 4-grams in hypothesis, calculating BLEU for trigrams\n";
		print "no trigram matches, smoothing trigram count to 0.5\n";
		$trigram = 0.5;
		$bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] ) +
				my_log( $CORRECT[2]/$TOTAL[2] ) +
				my_log( $CORRECT[3]/$TOTAL[3] )) / 3);		
	} else {
		# prevent division by 0 for 4-grams and 3-grams
		print "no 4-grams or trigrams in hypothesis, calculating BLEU for bigrams\n";
		$bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] ) +
				my_log( $CORRECT[2]/$TOTAL[2] )) / 2); 
	} # end if else else have some 4-grams, have some trigrams in hypothesis
				   
} elsif ($CORRECT[1]>0) {
	if ($TOTAL[4]>0) {
		print "no bigram matches, smoothing bigram count to 0.5, trigram count to 0.25, and 4-gram count to 0.125\n";
		$bigram = 0.5; 
		$trigram = 0.25;
		$fourgram = 0.125;
		$bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] ) +
				my_log( $bigram/$TOTAL[2] ) +
				my_log( $trigram/$TOTAL[3] ) +
				my_log( $fourgram/$TOTAL[4] ) ) / 4);
	} elsif ($TOTAL[3]>0) {
		# prevent division by 0 for 4-grams
		print "no 4-grams in hypothesis, calculating BLEU for trigrams\n";
		print "no bigram matches, smoothing bigram count to 0.5, trigram count to 0.25\n";
		$bigram = 0.5; 
		$trigram = 0.25;
		$bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] ) +
				my_log( $CORRECT[2]/$TOTAL[2] ) +
				my_log( $CORRECT[3]/$TOTAL[3] )) / 3); 		
	} elsif ($TOTAL[2]>0)  {
		# prevent division by 0 for 4-grams and trigrams
		print "no 4-grams or trigrams in hypothesis, calculating BLEU for bigrams\n";
		print "no bigram matches, smoothing bigram count to 0.5\n";
		$bigram = 0.5; 
		$bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] ) +
				my_log( $CORRECT[2]/$TOTAL[2] )) / 2);
	} else {
		# not even any bigrams
		# prevent division by 0 for 4-grams, trigrams, bigrams
		print "no 4-grams, trigrams, or bigrams in hypothesis, calculating BLEU for unigrams\n";
		$bleu = $brevity_penalty * exp((my_log( $CORRECT[1]/$TOTAL[1] )));
	} # end if else else else have some 4-grams, have some trigrams, have some bigrams in hypothesis

} # end if else else have matching 4-grams, trigrams, bigrams, unigrams


# prevent division by 0 for very small hypothesis sentences like "Thank you"
if ($TOTAL[4] > 0) {
printf "BLEU = %.2f, %.1f/%.1f/%.1f/%.1f \n(BP=%.3f, ration=%.3f):$CORRECT[1]:$TOTAL[1]:=$CORRECT[2]:total=$TOTAL[2]:$CORRECT[3]:$TOTAL[3]:$CORRECT[4]:$TOTAL[4]:$length_reference\n",
    100*$bleu,
    100*$CORRECT[1]/$TOTAL[1],
    100*$CORRECT[2]/$TOTAL[2],
    100*$CORRECT[3]/$TOTAL[3],
    100*$CORRECT[4]/$TOTAL[4],
    $brevity_penalty,
    $length_translation / $length_reference;
print "\nbleu $bleu\n$CORRECT[1]/$TOTAL[1] unigrams, $CORRECT[2]/$TOTAL[2] bigrams, $CORRECT[3]/$TOTAL[3] trigrams, $CORRECT[4]/$TOTAL[4] 4grams\n";
} elsif ($TOTAL[3] > 0) {
print "[no 4-grams]\n"; 
printf "BLEU = %.2f, %.1f/%.1f/%.1f/\n(BP=%.3f, ration=%.3f):$CORRECT[1]:$TOTAL[1]:=$CORRECT[2]:total=$TOTAL[2]:$CORRECT[3]:$TOTAL[3]:$CORRECT[4]:$TOTAL[4]:$length_reference\n",
    100*$bleu,
    100*$CORRECT[1]/$TOTAL[1],
    100*$CORRECT[2]/$TOTAL[2],
    100*$CORRECT[3]/$TOTAL[3],
  #  100*$CORRECT[4]/$TOTAL[4],
    $brevity_penalty,
    $length_translation / $length_reference;
print "\nbleu $bleu\n$CORRECT[1]/$TOTAL[1] unigrams, $CORRECT[2]/$TOTAL[2] bigrams, $CORRECT[3]/$TOTAL[3] trigrams, $CORRECT[4]/$TOTAL[4] 4grams\n";
} elsif ($TOTAL[2] > 0) {
print "[no 4-grams or trigrams]\n"; 
printf "BLEU = %.2f, %.1f/%.1f//\n(BP=%.3f, ration=%.3f):$CORRECT[1]:$TOTAL[1]:=$CORRECT[2]:total=$TOTAL[2]:$CORRECT[3]:$TOTAL[3]:$CORRECT[4]:$TOTAL[4]:$length_reference\n",
    100*$bleu,
    100*$CORRECT[1]/$TOTAL[1],
    100*$CORRECT[2]/$TOTAL[2],
  #  100*$CORRECT[3]/$TOTAL[3],
  #  100*$CORRECT[4]/$TOTAL[4],
    $brevity_penalty,
    $length_translation / $length_reference;
print "\nbleu $bleu\n$CORRECT[1]/$TOTAL[1] unigrams, $CORRECT[2]/$TOTAL[2] bigrams, $CORRECT[3]/$TOTAL[3] trigrams, $CORRECT[4]/$TOTAL[4] 4grams\n";
} elsif ($TOTAL[1] > 0) {
print "[no 4-grams or trigrams or bigrams]\n"; 
printf "BLEU = %.2f, %.1f///\n(BP=%.3f, ration=%.3f):$CORRECT[1]:$TOTAL[1]:=$CORRECT[2]:total=$TOTAL[2]:$CORRECT[3]:$TOTAL[3]:$CORRECT[4]:$TOTAL[4]:$length_reference\n",
    100*$bleu,
    100*$CORRECT[1]/$TOTAL[1],
  #  100*$CORRECT[2]/$TOTAL[2],
  #  100*$CORRECT[3]/$TOTAL[3],
  #  100*$CORRECT[4]/$TOTAL[4],
    $brevity_penalty,
    $length_translation / $length_reference;
print "\nbleu $bleu\n$CORRECT[1]/$TOTAL[1] unigrams, $CORRECT[2]/$TOTAL[2] bigrams, $CORRECT[3]/$TOTAL[3] trigrams, $CORRECT[4]/$TOTAL[4] 4grams\n";

} # end if else else else have some 4-grams etc. in hypothesis


sub my_log {
  return -9999999999 unless $_[0];
  return log($_[0]);
}
