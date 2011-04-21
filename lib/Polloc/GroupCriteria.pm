=head1 NAME

Polloc::GroupCriteria - Rules to group loci

=head1 DESCRIPTION

Takes loci and returns groups of loci based on certain
rules.  If created via .bme (.cfg) files, it is defined
in the C<[ RuleGroup ]> and C<[ GroupExtension ]>
namespaces.

=head1 AUTHOR - Luis M. Rodriguez-R

Email lmrodriguezr at gmail dot com

=head1 IMPLEMENTS OR EXTENDS

=over

=item *

L<Polloc::Polloc::Root>

=back

=cut

package Polloc::GroupCriteria;

use strict;
use List::Util qw(min max);
use Polloc::Polloc::IO;
use Polloc::LociGroup;
use Bio::Tools::Run::Alignment::Muscle;
use Bio::Seq;
use Error qw(:try);

use base qw(Polloc::Polloc::Root);

#

=head1 APPENDIX

Methods provided by the package

=cut

=head2 new

Attempts to initialize a Polloc::Rule::* object

=head3 Arguments

=over

=item -type

The type of rule

=item -value

The value of the rule (depends on the type of rule)

=item -context

The context of the rule.  See L<Polloc::RuleI->context()>

=back

=head3 Returns

The C<Polloc::Rule::*> object

=head3 Throws

L<Polloc::Polloc::Error> if unable to initialize the proper object

=cut

sub new {
   my($caller,@args) = @_;
   my $self = $caller->SUPER::new(@args);
   $self->_initialize(@args);
   return $self;
}

=head2 source

=cut

sub source {
   my($self, $value) = @_;
   $self->{'_source'} = $value if defined $value;
   return $self->{'_source'};
}

=head2 target

=cut

sub target {
   my($self, $value) = @_;
   $self->{'_target'} = $value if defined $value;
   return $self->{'_target'};
}

=head2 locigroup

Gets/sets the input L<Polloc::LociGroup> object containing
all the loci to evaluate.

=cut

sub locigroup {
   my($self, $value) = @_;
   if(defined $value){
      $self->{'_locigroup'} = $value;
      $self->{'_reorder'} = 1;
   }
   return $self->{'_locigroup'};
}

=head2 condition

=cut

sub condition {
   my($self, $value) = @_;
   $self->{'_condition'} = $value if defined $value;
   return $self->{'_condition'};
}

=head2 evaluate

Compares two loci based on the defined conditions

=head3 Parameters

=over

=item *

The first locus (a L<Polloc::LocusI> object)

=item *

The second locus (a L<Polloc::LocusI> object)

=back

=head3 Returns

Boolean

=head3 Throws

L<Polloc::Polloc::Error> if unexpected input or undefined condition, source or
target

=cut

sub evaluate {
   my($self, $feat1, $feat2) = @_;
   # Test the input
   $feat1->isa('Polloc::LocusI') or
   	$self->throw("First feature of illegal class", $feat1);
   
   $feat2->isa('Polloc::LocusI') or
   	$self->throw("Second feature of illegal class", $feat2);
   
   defined $self->condition or
   	$self->throw("Undefined condition, impossible to group");
   
   $self->condition->{'-type'} eq 'bool' or
   	$self->throw("Unexpected type of condition", $self->condition);
   
   $self->throw("Undefined source features") unless defined $self->source;
   $self->throw("Undefined target features") unless defined $self->target;
   
   # Run
   return 0 unless $feat1->family eq $self->source;
   return 0 unless $feat2->family eq $self->target;
   $self->{'_FEAT1'} = $feat1;
   $self->{'_FEAT2'} = $feat2;
   my $o = $self->_operate($self->condition);
   $self->{'_FEAT1'} = undef;
   $self->{'_FEAT2'} = undef;
   return $o;
}

=head2 get_loci

Gets the stored loci

=head3 Note

The stored loci can also be obtained with C<$object-E<gt>locigroup-E<gt>loci>,
but this function ensures a consistent order in the loci for its evaluation.

=cut

sub get_loci {
   my($self,@args) = @_;
   $self->{'_features'} = $self->locigroup->loci
   	if defined $self->locigroup and not defined $self->{'_features'};
   $self->{'_features'} = [] unless defined $self->{'_features'};
   if($self->{'_reorder'} && $self->source ne $self->target){
      my @src = ();
      my @tgt = ();
      my @oth = ();
      for my $ft (@{$self->locigroup->loci}){
      	    if($ft->family eq $self->source){ push (@src, $ft) }
	 elsif($ft->family eq $self->target){ push (@tgt, $ft) }
	 else{ push @oth, $ft }
      }
      $self->{'_features'} = [];
      push @{$self->{'_features'}}, @tgt, @src, @oth;
      $self->{'_reorder'} = 0;
   }
   return $self->{'_features'};
}


=head2 get_locus

Get the locus with the specified index.

=head3 Arguments

The index (int).

=head3 Returns

A L<Polloc::LocusI> object or undef.

=head3 Note

This is a lazzy method, and should be used B<ONLY> after C<get_loci()>
were called at least once.  Otherwise, the order might not be the expected,
and weird results would appear.

=cut

sub get_locus {
   my($self, $index) = @_;
   return unless defined $index;
   return unless defined $self->{'_features'};
   return $self->{'_features'}->[$index];
}

=head2 extension

Sets the conditions for group extensions.

=head3 Arguments

Array, hash or string with C<-key =E<gt> value> pairs.  Supported values are:

=over

=item -function I<str>

=over

=item C<context>

Searches the flanking regions in the target sequence.

=back

=item -upstream I<int>

Extension in number of residues upstream the feature.

=item -downstream I<int>

Extension in number of residues downstream the feature.

=item -detectstrand I<bool (int)>

Should I detect the proper strand?  Otherwise, the stored strand
is trusted.  This is useful for non-directed features like repeats,
which context is actually directed.

=item -alldetected I<bool (int)>

Include all detected features (even these overlapping with input features).

=item -feature I<bool (int)>

Should I include the feature region in the search? 0 by default.

=item -lensd I<float>

Number of Standar Deviations (SD) tolerated as half of the range of lengths
for a feature.  The average (Avg) and the standard deviation of the length
are calculated based on all the stored features, and the Avg+(SD*lensd) is
considered as the largest possible new feature.  No minimum length constraint
is given, unless explicitly set with -minlen.  This argument is ignored if
C<-maxlen> is explicitly set.  Default is 1.5.

=item -maxlen I<int>

Maximum length of a new feature in number of residues.  If zero (0) evaluates
C<-lensd> instead.  Default is 0.

=item -minlen I<int>

Minimum length of a new feature in number of residues.  Default is 0.

=item -similarity I<float>

Minimum fraction of similarity to include a found region. 0.8 by default.

=item -oneside I<bool (int)>

Should I consider features with only one of the sides?  Takes effect only if
both -upstream and -downstream are defined. 0 by default.

=item -algorithm I<str>

=over

=item C<blast>

Use BLAST to search (after multiple alignment and consensus calculation of
queries).  Default algorithm.

=item C<hmmer>

Use HMMer to search (after multiple alignment and C<hmmbuild> of query
sequences).

=back

=item -score I<int>

Minimum score for either algorithms B<blast> and B<hmmer>. 20 by default.

=item -consensusperc I<float>

Minimum percentage a residue must appear in order to include it in the
consensus used as query.  60 by default.  Only if -algorithm blast.

=item -e I<float>

If C<-algorithm> B<blast>, maximum e-value.  0.1 by default.

=item -p I<str>

If C<-algorithm> B<blast>, program used (C<[t]blast[npx]>).  B<blastn> by
default.

=back

=head3 Throws

L<Polloc::Polloc::Error> if unexpected input

=cut

sub extension {
my ($self, @args) = @_;
   @args = split /\s+/, $args[0] if $#args == 0;
   $self->throw("Odd number of elements, impossible to build key-value pairs", \@args)
   	unless $#args%2;
   my %f = @args;
   $f{'-function'} ||= 'context';
   $f{'-algorithm'} ||= 'blast';
   $f{'-feature'}+= 0 if defined $f{'-feature'};
   $f{'-detectstrand'}+= 0 if defined $f{'-detectstrand'};
   $f{'-alldetected'}+= 0 if defined $f{'-alldetected'};
   $f{'-lensd'} = defined $f{'-lensd'} ? $f{'-lensd'}+0 : 1.5;
   $f{'-maxlen'} = defined $f{'-maxlen'} ? $f{'-maxlen'}+0 : 0;
   $f{'-minlen'} = defined $f{'-minlen'} ? $f{'-minlen'}+0 : 0;
   $f{'-similarity'} = defined $f{'-similarity'} ? $f{'-similarity'}+0 : 0.8;
   $f{'-score'} = defined $f{'-score'} ? $f{'-score'}+0 : 20;
   $f{'-consensusperc'} = defined $f{'-consensusperc'} ? $f{'-consensusperc'}+0 : 60;
   $f{'-e'} = 0.1 unless defined $f{'-e'};
   $f{'-p'} = 'blastn' unless defined $f{'-p'};
   $self->{'_groupextension'} = \%f;
}


=head2 extend

Extends a group based on the arguments provided by L<Polloc::GroupCriteria->extension()>.

=head3 Arguments

=over

=item -loci I<Polloc::LociGroup>

The L<Polloc::LociGroup> containing the loci in the group to extend.

=back

=head3 Returns

A L<Polloc::LociGroup> object containing the updated group, i.e. the
original group PLUS the extended features.

=head3 Throws

L<Polloc::Polloc::Error> if unexpected input or weird extension definition.

=cut

sub extend {
   my ($self, @args) = @_;
   my ($loci) = $self->_rearrange([qw(LOCI)], @args);
   
   # Check input
   my $ext = $self->{'_groupextension'};
   return unless defined $ext;
   $self->throw("The loci are not into an object", $loci)
   	unless defined $loci and ref($loci) and UNIVERSAL::can($loci,'isa');
   $self->throw("Unexpected type for the group of loci", $loci)
   	unless $loci->isa('Polloc::LociGroup');
   return unless $#{$loci->loci}>=0;

   # Set ID base
   my $group_id = $self->_next_group_id;

   # Run
   my @new = ();
   $self->debug("--- Extending group (based on ".($#{$loci->loci}+1)." loci) ---");
   if(lc($ext->{'-function'}) eq 'context'){
      my ($up_aln, $down_aln, $in_aln);
      my ($up_pos, $down_pos, $in_pos);
      my ($eval_border, $eval_feature);

      # Fix the strands
      if($ext->{'-detectstrand'}
      			and (defined $ext->{'-upstream'}
			or defined $ext->{'-downstream'})){
         my $downsize = $ext->{'-downstream'};
	 my $upsize = $ext->{'-upstream'};
	 $downsize ||= 0;
	 $upsize ||= 0;
	 $loci->fix_strands(max($downsize, $upsize));
      }
      
      # Search
      if(defined $ext->{'-upstream'} and $ext->{'-upstream'}+0){
	 $self->debug("Searching upstream sequences");
	 $up_aln = $loci->align_context(-1, $ext->{'-upstream'}, 0);
	 $up_pos = $self->_search_aln_seqs($up_aln);
	 $eval_border = 0;
	 $self->debug(($#$up_pos+1)." results");
      }
      if(defined $ext->{'-downstream'} and $ext->{'-downstream'}+0){
         $self->debug("Searching downstream sequences");
	 $down_aln = $loci->align_context(1, $ext->{'-downstream'}, 0);
	 $down_pos = $self->_search_aln_seqs($down_aln);
	 $eval_border = 1 if defined $eval_border;
	 $self->debug(($#$down_pos+1)." results");
      }
      if(defined $ext->{'-feature'} and $ext->{'-feature'}+0){
         $self->debug("Searching in-feature sequences");
	 $in_aln = $loci->align_context(0, 0, 0);
	 $in_pos = $self->_search_aln_seqs($in_aln);
	 $eval_feature = 1;
	 $self->debug(($#$in_pos+1)." results");
      }

      # Determine maximum size
      my $max_len = $ext->{'-maxlen'};
      unless($max_len){
	 my($len_avg, $len_sd) = $self->locigroup->avg_length;
	 $self->warn("Building size constrains based in one sequence only")
	 	if $#{$self->locigroup->loci}<1;
	 $max_len = $len_avg + $len_sd*$ext->{'-lensd'};
      }
      $self->debug("Comparing results with maximum feature's length of $max_len");

      # Evaluate/pair
      if($eval_border){
	 # Detect border pairs
	 US: for my $us (@$up_pos){
	    $self->throw("Unexpected array structure (upstream): ".join(" | ", @$us), $us)
	       		unless defined $us->[0] and defined $us->[4];
	    $self->debug(" US: ", join(':', @$us));
	    my $found;
	    my $pair = [];
	    my $reason;
	    DS: for my $ds (@$down_pos){
	       $self->debug("    Discarded: $reason") if defined $reason;
	       $self->throw("Unexpected array structure (downstream): ".
	       		join(" | ", @$ds), $ds)
	       			unless defined $ds->[0] and defined $ds->[4];
	       $self->debug("  DS: ", join(':', @$ds));
	       # Same contig:
	       $reason = '!= ctg';
	       next DS unless $us->[0] eq $ds->[0];
	       # Different strand:
	       $reason = '== strand';
	       next DS unless $us->[3] != $ds->[3];
	       # Close enough:
	       $reason = 'too long';
	       my $dist = abs($ds->[2]-$us->[2]);
	       next DS if $dist > $max_len or $dist < $ext->{'-minlen'};
	       # Closer than previous pairs, if any:
	       $reason = 'other shorter';
	       next DS if defined $found and abs($us->[2]-$ds->[2]) > $found;
	       # Good!
	       $reason = undef;
	       $self->debug("Saving pair ".$us->[1]."..".$us->[2]."/".$ds->[1]."..".$ds->[2]);
	       $found = abs($us->[2]-$ds->[2]);
	       $pair = [$us->[0], $us->[2], $ds->[2], $us->[3], ($us->[4]+$ds->[4])/2];
	    }
	    $self->debug("    Discarded: $reason") if defined $reason;
	    push @new, $pair if $#$pair>1;
	 }
	 if($eval_feature){
	    $self->debug("Filtering results with in-feature sequences");
	    my @prefilter = @new;
	    @new = ();
	    BORDER: for my $br (@prefilter){
	       WITHIN: for my $in (@$in_pos){
		  $self->throw("Unexpected array structure (in-feature): ".
		  	join(" | ", @$in), $in)
		  		unless defined $in->[0] and defined $in->[4];
		  # Same contig:
		  next WI unless $br->[0] eq $in->[0];
		  # Upstream's strand:
		  next WI unless $br->[3] == $in->[3];
		  # Overlapping:
		  next WI unless $br->[3]*$in->[1] < $br->[3]*$br->[2]
		  		and $br->[3]*$in->[2] > $br->[3]*$br->[1];
		  # Good!
		  # ToDo: Should I use the loci' data to sharpen borders?...
		  $br->[4] = (2*$br->[4] + $in->[4])/3;
		  push @new, $br;
	       }
	    }
	 }
      }elsif($eval_feature){
	 # Just like that ;o)
	 @new = @$in_pos;
      }else{
	 $self->throw('Anything to evaluate!  '.
	 		'I need either the two borders or the middle sequence (or both)');
      }
   }else{
      $self->throw('Unsupported function for group extension', $ext->{'-function'});
   }

   # And finally, create the detected features, discarding loci overlapping input loci
   $self->debug("Found ".($#new+1)." loci, creating extend features");
   my $comments = "Based on group $group_id: ";
   for my $locus (@{$loci->loci}) { $comments.= $locus->id . ", " if defined $locus->id }
   $comments = substr $comments, 0, -2;
   
   my $newloci = Polloc::LociGroup->new();
   $newloci->name($loci->name."-ext") if defined $loci->name;
   $newloci->featurename($loci->featurename) if defined $loci->featurename;
   $newloci->genomes($loci->genomes) if defined $loci->genomes;
   NEW: for my $itemk (0 .. $#new){
      my $item = $new[$itemk];
      ($item->[1], $item->[2]) = (min($item->[1], $item->[2]), max($item->[1], $item->[2]));
      unless($ext->{'-alldetected'}){
         OLD: for my $locus (@{$loci->loci}){
	    # Not new! :
	    next NEW if $item->[1]<$locus->to and $item->[2]>$locus->from;
	 }
      }
      my $seq;
      my($Gk, $acc) = split /:/, $item->[0], 2;
      $Gk+=0;
      for my $ck (0 .. $#{$self->genomes->[$Gk]->get_sequences}){
         my $id = $self->genomes->[$Gk]->get_sequences->[$ck]->display_id;
	 if($id eq $acc or $id =~ m/\|$acc(\.\d+)?(\||\s*$)/){
	    $seq = [$Gk,$ck]; last;
	 }
      }
      $self->warn('I can not find the sequence', $acc) unless defined $seq;
      $self->throw('Undefined genome-contig pair', $acc, 'UnexpectedException')
      		unless defined $self->genomes->[$seq->[0]]->get_sequences->[$seq->[1]];
      my $id = $self->source . "-ext:".($Gk+1).".$group_id.".($#{$newloci->loci}+2);
      $newloci->add_loci(Polloc::LocusI->new(
      		-type=>'extend',
		-from=>$item->[1],
		-to=>$item->[2],
		-id=>(defined $id ? $id : ''),
		-strand=>($item->[3]==-1 ? '+' : '-'),
		# Seems complicated, but reduces clones:
		#		       Gk:Genome	 	   ck:Contig
		-seq=>$self->genomes->[$seq->[0]]->get_sequences->[$seq->[1]],
		-score=>$item->[4],
		-basefeature=>$loci->loci->[0],
		-comments=>$comments,
		-genome=>$self->genomes->[$Gk]
      ));
   }
   return $newloci;
}

=head2 build_bin

Compares all the included loci and returns the identity matrix

=head3 Arguments

=over

=item -complete I<bool (int)>

If true, calculates the complete matrix instead of only the bottom-left triangle.

=back

=head3 Returns

A reference to a boolean 2-dimensional array (only left-down triangle)

=head3 Note

B<WARNING!>  The order of the output is not allways the same of the input.
Please use C<get_loci()> instead, as source features B<MUST> be after
target features in the array.  Otherwise, it is not possible to have the
full picture without building the full matrix (instead of half).

=cut

sub build_bin {
   my($self,@args) = @_;
   my $bin = [];
   my($complete) = $self->_rearrange([qw(COMPLETE)], @args);
   for my $i (0 .. $#{$self->get_loci}){
      $bin->[$i] = [];
      my $lim = $complete ? $#{$self->get_loci} : $i;
      for my $j (0 .. $lim){
	 $bin->[$i]->[$j] = $self->evaluate(
	 	$self->get_loci->[$i],
		$self->get_loci->[$j]
	 );
      }
   }
   return $bin;
}


=head2 bin_build_groups

Builds groups of loci based on a binary matrix

=head3 Arguments

A matrix as returned by L<Polloc::GroupCriteria::build_bin()>

=head3 Returns

A 2-D matrix ref.

=head3 Note

This method is intended to build groups providing information on all-vs-all
comparisons.  If you do not need this information, use the much more
efficient L<Polloc::GroupCriteria::build_groups()> method, that relies on
transitive property of groups to avoid unnecessary comparisons.  Please note
that this function also relies on transitivity, but gives you the option to
examine all the paired comparisons and even write your own grouping function.

=cut

sub bin_build_groups {
   my($self,$bin) = @_;
   my $groups = [];
   FEAT: for my $f (0 .. $#{$self->get_loci}){
      GROUP: for my $g (0 .. $#{$groups}){
         MEMBER: for my $m (0 .. $#{$groups->[$g]}){
	    if($bin->[$f]->[$groups->[$g]->[$m]] ){
	       push @{$groups->[$g]}, $f;
	       next FEAT;
	    }
	 }
      }
      push @{$groups}, [$f]; # If not found in previous groups
   }
   # Change indexes by Polloc::LocusI objects
   return $self->_feat_index2obj($groups);
}


=head2 build_groups

This is the main method, creates groups of loci.

=head3 Arguments

=over

=item -cpus I<int>

If defined, attempts to distribute the work among the specified number of
cores. B<Warning>: This parameter is experimental, and relies on
C<Parallel::ForkManager>.  It can be used in production with certain
confidence, but it is highly probable to B<NOT> work in parallel (to avoid
errors, this method ignores the command at ANY possible error).

B<Unimplemented>: This argument is currently ignored. Some algorithmic
considerations must be addressed before using it. B<TODO>.

=item -advance I<ref to sub>

A reference to a function to call at every new pair.  The function is called
with three arguments, the first is the index of the first locus, the second
is the index of the second locus and the third is the total number of loci.
Note that this function is called B<BEFORE> running the comparison.

=over

=head3 Returns

A L<Polloc::LociGroup> object.

=head3 Note

This method is faster than combining C<build_bin()> and C<build_groups_bin()>,
and it should be used whenever transitivity can be freely assumed and you do
not need the all-vs-all matrix for further evaluation (for example, manual
inspection).

=cut

sub build_groups {
   my($self,@args) = @_;
   my ($cpus, $advance) = $self->_rearrange([qw(CPUS ADVANCE)], @args);
   
   my $groups = [[0]]; #<- this is bcs first feature is ignored in FEAT1
   my $loci = $self->get_loci;
   my $l_max = $#$loci;
   $self->debug("Building groups for ".($l_max+1)." loci");
   $self->warn('Nothing to do, any stored loci') unless $l_max>=0;
   FEAT1: for my $i (1 .. $l_max){
      FEAT2: for my $j (0 .. $i-1){
         $self->debug("Evaluate [$i vs $j]");
	 &$advance($i, $j, $l_max+1) if defined $advance;
         next FEAT2 unless $self->evaluate(
	 	$loci->[$i],
		$loci->[$j]
	 );
	 # --> If I am here, FEAT1 ~ FEAT2 <--
	 GROUP: for my $g (0 .. $#{$groups}){
	    MEMBER: for my $m (0 .. $#{$groups->[$g]}){
	       if($j == $groups->[$g]->[$m]){
	          # I.e., if FEAT2 is member of GROUP
		  push @{$groups->[$g]}, $i;
		  next FEAT1; #<- This is why the current method is way more efficient
	       }
	    }#MEMBER
	 }#GROUP
      }#FEAT2
      # --> If I am here, FEAT1 belongs to a new group <--
      push @{$groups}, [$i];
   }#FEAT1
   my $out = [];
   for my $gk (0 .. $#$groups){
      my $group = Polloc::LociGroup->new(-name=>$gk+1); #+++ ToDo: Is ID ok?
      for my $lk (0 .. $#{$groups->[$gk]}){
         my $locus = $loci->[ $groups->[$gk]->[$lk] ];
	 # Paranoid bugbuster:
	 $self->throw('Impossible to gather the locus back:'.
	 	' $groups->['.$gk.']->['.$lk.']: '.$groups->[$gk]->[$lk],
	 	$loci, 'Polloc::Polloc::UnexpectedException')
		unless defined $locus;
         $group->add_loci($locus);
      }
      push @$out, $group;
   }
   return $out;
}

=head2 genomes

Gets the genomes of the base group of loci.  This function is similar
to calling C<locigroup()-E<gt>genomes()>, but is read-only.

=cut

sub genomes {
   my ($self, $value) = @_;
   $self->warn("Attempting to set the genomes from a read-only function")
   	if defined $value;
   return unless defined $self->locigroup;
   return $self->locigroup->genomes;
}

=head1 INTERNAL METHODS

Methods intended to be used only within the scope of Polloc::*

=head2 _next_group_id

Returns an incremental ID that attempts to identify the group used as basis
of extension.  Please note that this method DOES NOT check if the group's ID
is the right one, and it is basically intended to keep track of how many
times the C<extend()> function has been called.

=cut

sub _next_group_id {
   my $self = shift;
   $self->{'_next_group_id'}||= 0;
   return ++$self->{'_next_group_id'};
}

=head2 _build_subseq

=head3 Arguments

All the following arguments are mandatory and must be passed in that order.
The strand will be determined by the relative position of from/to:

=over

=item seq I<Bio::Seq object>

The sequence

=item from I<int>

The B<from> position

=item to I<int>

The B<to> position

=back

=back

=back

=head3 Returns

A L<Bio::Seq> object.

=head3 Comments

This method should be located at a higher hierarchy module (Root?).

This method is static.

=cut

sub _build_subseq {
   my($self, $seq, $from, $to) = @_;
   my ($start, $end) = (min($to, $from), max($to, $from));
   $start = max($start, 1);
   $end = min($end, $seq->length);
   return unless $start != $end;
   my $seqstr = $seq->subseq($start, $end);
   my $cleanstr = $seqstr;
   $cleanstr =~ s/^N*//;
   $cleanstr =~ s/N*$//;
   return unless length $cleanstr > 0; # See issue BME#5
   my $subseq = Bio::Seq->new(-seq=>$seqstr);
   $subseq = $subseq->revcom if $from < $to;
   return $subseq;
}

=head2 _search_aln_seqs

Uses an alignment to search in the sequences of the collection of genomes

=head3 Arguments

A Bio::SimpleAlign object

=head3 Returns

A reference to an array of references to arrays, each with structure:
C<["genome-key:acc", from, to, strand, score]>

=cut

sub _search_aln_seqs {
   my ($self, $aln) = @_;
   my $ext = $self->{'_groupextension'};
   return unless defined $ext;
   return unless defined $self->genomes;
   my $pos = [];
   return $pos unless defined $aln; #<- For example, if zero sequences.  To gracefully exit.
   my $alg = lc $ext->{'-algorithm'};
   if($alg eq 'blast' or $alg eq 'hmmer'){ # ------------------------------- BLAST & HMMer
      # -------------------------------------------------------------------- Setup DB
      unless(defined $self->{'_seqsdb'}){
	 $self->{'_seqsdb'} = Polloc::Polloc::IO->tempdir();
	 $self->debug("Creating DB at ".$self->{'_seqsdb'});
	 for my $genomek (0 .. $#{$self->genomes}){
	    my $file = $self->{'_seqsdb'}."/$genomek";
	    my $fasta = Bio::SeqIO->new(-file=>">$file", -format=>'Fasta');
	    for my $ctg (@{$self->genomes->[$genomek]->get_sequences}){ $fasta->write_seq($ctg) }
	    # BLAST requires a formatdb (not only the fasta)
	    if($alg eq 'blast'){
	       my $run = Polloc::Polloc::IO->new(-file=>"formatdb -p F -i '$file' 2>&1 |");
	       while($run->_readline) {} # just run ;o)
	       $run->close;
	    }
	 }
      }
      # -------------------------------------------------------------------- Predefine vars
      my $factory;
      my $query;
      if($alg eq 'blast'){
         require Bio::Tools::Run::StandAloneBlast;
	 my $cons_seq = $aln->consensus_string($ext->{'-consensusperc'});
	 $cons_seq =~ s/\?/N/g;
         $query = Bio::Seq->new(-seq=>$cons_seq);
      }elsif($alg eq 'hmmer'){
	 require Bio::Tools::Run::Hmmer;
	 my $tmpio = Polloc::Polloc::IO->new();
	 # The following lines should be addressed with a three-lines code,
	 # but the buggy AUTOLOAD of Bio::Tools::Run::Hmmer let us no option
	 # -lrr
	 $factory = Bio::Tools::Run::Hmmer->new();
	 $factory->hmm($tmpio->tempfile);
	 $factory->program('hmmbuild');
	 $factory->run($aln);
	 #$factory->calibrate();
      }
      # -------------------------------------------------------------------- Search
      $self->debug("Searching... alg:$alg, sim:".$ext->{'-similarity'}." score:".$ext->{'-score'}." e:".$ext->{'-e'});
      GENOME: for my $Gk (0 .. $#{$self->genomes}){
         my $report;
	 if($alg eq 'blast'){
	    next GENOME if ($query->seq =~ tr/N//) > 0.25*$query->length; # issue#14
	    $factory = Bio::Tools::Run::StandAloneBlast->new(
	 	'-e'=>$ext->{'-e'}, '-program'=>$ext->{'-p'},
		'-db'=>$self->{'_seqsdb'}."/$Gk" );
	    # Try to handle issue#14 and possible undocumented related issues:
	    # (still causing some problems in the STDERR output)
	    try { $report = $factory->blastall($query); }
	    catch Error with {
	       $self->debug("Launch BLAST with query: ".$query->seq());
	       $self->warn("BLAST failed, skipping query and attempting to continue");
	       next GENOME;
	    }
	    otherwise {
	       $self->throw("BLAST failed", $_, 'Polloc::Polloc::UnexpectedException');
	    };
	 }elsif($alg eq 'hmmer'){
	    $factory->program('hmmsearch');
	    $report = $factory->run($self->{'_seqsdb'}."/$Gk");
	 }
	 # ----------------------------------------------------------------- Parse search
	 RESULT: while(my $res = $report->next_result){
	    HIT: while(my $hit = $res->next_hit){
	       HSP: while(my $hsp = $hit->next_hsp){
	          # -------------------------------------------------------- Eval criteria
	          if(	($alg eq 'blast'
				and $hsp->frac_identical('query') >= $ext->{'-similarity'}
				and $hsp->score >= $ext->{'-score'})
		  or
			($alg eq 'hmmer'
				and $hsp->score >= $ext->{'-score'}
				and $hsp->evalue <= $ext->{'-e'})
		  ){
			# -------------------------------------------------- Save result
			$self->debug("Found: sim:".$hsp->frac_identical('query').", score:".
				$hsp->score.", e:".$hsp->evalue);
			my $r_pos = ["$Gk:".$hit->accession,
				$hsp->strand('hit')!=$hsp->strand('query')?
						$hsp->start('hit'):$hsp->end('hit'),
				$hsp->strand('hit')!=$hsp->strand('query')?
						$hsp->end('hit'):$hsp->start('hit'),
				$hsp->strand('hit')!=$hsp->strand('query')?
						-1 : 1,
				$hsp->bits];
			push @$pos, $r_pos;
		  }
	       } # HSP
	    } # HIT
	 } # RESULT
      } # GENOME
   }else{ # ---------------------------------------------------------------- UNSUPPORTED
      $self->throw('Unsupported search algorithm', $ext->{'-algorithm'});
   }
   return $pos;
}

=head2 _feat_index2obj

Takes an index 2D matrix and returns it as the equivalent L<Polloc::LocusI> objects

=head3 Arguments

2D matrix of integers (ref)

=head3 Returns

2D matrix of L<Polloc::LocusI> objects (ref)

=cut

sub _feat_index2obj{
   my($self,$groups) = @_;
   for my $g (0 .. $#{$groups}){
      for my $m (0 .. $#{$groups->[$g]}){
         $groups->[$g]->[$m] = $self->get_locus($groups->[$g]->[$m]);
      }
   }
   return $groups;
}


=head2 _operate

Runs an operation

=head3 Arguments

The variable to interpret

=head3 Returns

Mix

=head3 Throws

L<Polloc::Polloc::Error> if no input

=cut

sub _operate {
   my($self, $var) = @_;
   $self->throw("Undefined variable to operate", $var) unless defined $var;
   return $var->{'-val'} if defined $var->{'-val'};
   my $o;
   my $s = lc $var->{'-type'};
   if($s eq 'bool')	{ $o = $self->_operate_bool($var) }
   elsif($s eq 'num')	{ $o = $self->_operate_num($var) }
   elsif($s eq 'seq')	{ $o = $self->_operate_seq($var) }
   elsif($s eq 'cons')	{ $o = $self->_operate_cons($var) }
   else			{ $self->throw("Unknown type of variable", $var) }
   return $o;
}


=head2 _operate_cons

Operates to recover a constant

=head3 Arguments

The variable to interpret.  Note that the name of the constant should not be
the B<-val>, but the B<-operation> in the variable. Otherwise, the literal
string of the name will be returned.

=head3 Returns

Mix

=cut

sub _operate_cons {
   my($self, $var) = @_;
   my $s = uc $var->{'-operation'};
   if($s eq 'FEAT1')	{ return $self->{'_FEAT1'} }
   elsif($s eq 'FEAT2')	{ return $self->{'_FEAT2'} }
   else			{ $self->throw("Undefined constant", $var) }
}


=head2 _operate_seq

Operates to generate a sequence

=head3 Arguments

The variable to interpret.

=head3 Returns

Bio::Seq object

=cut

sub _operate_seq {
   my($self, $var) = @_;
   my $fn = $var->{'-operation'};
   if($fn =~ /^sequence$/) {
	 my $feat = $self->_operate($var->{'-operators'}->[0]);
	 $var->{'-operators'}->[1] = 0 unless defined $var->{'-operators'}->[1];
	 my $ref = $var->{'-operators'}->[1]+0;
	 my ($from,$to);
	 if($ref<0){
	    $from = $feat->from + $var->{'-operators'}->[2];
	    $to = $feat->from + $var->{'-operators'}->[3];
	 }elsif($ref>0){
	    $from = $feat->to + $var->{'-operators'}->[2];
	    $to = $feat->to + $var->{'-operators'}->[3];
	 }else{
	    $from = $feat->from;
	    $to = $feat->to;
	 }
	 my($start,$end);
	 if($from<=$to){
	    $start = $from;
	    $end = $to;
	 }else{
	    $start = $to;
	    $end = $from;
	 }
	 $start = 1 unless $start>0;
	 $end = $feat->seq->length unless $end<$feat->seq->length;
	 my $seq = Bio::Seq->new(-seq=>$feat->seq->subseq($start,$end));
	 if($from>$to){
	    return $seq->revcom;
	 }
	 return $seq;
   }elsif($fn eq 'reverse') {
         my $seq = $self->_operate($var->{'-operators'}->[0]);
	 return $seq->revcom;
   } else {
         $self->throw("Unknown operation for sequence", $var);
   }
}


=head2 _operate_num

Operates to generate a number

=head3 Arguments

The variable to interpret.

=head3 Returns

float or int

=cut

sub _operate_num {
   my($self, $var) = @_;
   #$self->debug("Number calculation");
   my @ops = @{$var->{'-operators'}};
   my $op1 = $self->_operate($ops[0]);
   my $op2 = $self->_operate($ops[1]) if defined $ops[1];
   my $fn = $var->{'-operation'};
   if($fn eq '+')	{ return $op1 + $op2 }
   elsif($fn eq '-')	{ return $op1 - $op2 }
   elsif($fn eq '*')	{ return $op1 * $op2 }
   elsif($fn eq '/')	{ return $op1 / $op2 }
   elsif($fn eq '%')	{ return $op1 % $op2 }
   elsif($fn eq '**')	{ return $op1 ** $op2 }
   elsif($fn eq '^')	{ return $op1 ** $op2 }
   elsif($fn =~ /(aln-sim|aln-score)( with)?/i) { 
	 my $factory = Bio::Tools::Run::Alignment::Muscle->new();
	 $factory->quiet(1);
	 $op1->id('op1');
	 $op2->id('op2');
	 my $aln = $factory->align([$op1,$op2]);
	 my $out;
	 $out = $aln->overall_percentage_identity('long')/100
	 	if $var->{'-operation'} =~ /aln-sim( with)?/i;
	 $out = $aln->score if $var->{'-operation'} =~ /aln-score( with)?/i;
	 $factory->cleanup(); # This is to solve the issue #1
	 return $out;
   } else		{ $self->throw("Unknown numeric operation", $var) }
}


=head2 _operate_bool

Operates to generate boolean

=head3 Arguments

The variable to interpret.

=head3 Returns

bool

=cut

sub _operate_bool {
   my($self, $var) = @_;
   #$self->debug("Boolean calculation");
   my @ops = @{$var->{'-operators'}};
   my $op1 = $self->_operate($ops[0]);
   my $fn = $var->{'-operation'};
   if ($fn =~ />|gt/i)
     	 { return $op1 > $self->_operate($ops[1]) }
   elsif($fn =~ /<|lt/i)
     	 { return $op1 < $self->_operate($ops[1]) }
   elsif($fn =~ />=|ge/i)
     	 { return $op1 >= $self->_operate($ops[1]) }
   elsif($fn =~ /<=|le/i)
     	 { return $op1 <= $self->_operate($ops[1]) }
   elsif($fn =~ /&&?|and/i)
     	 { return ( $op1 and $self->_operate($ops[1]) ) }
   elsif($fn =~ /\|\|?|or/i)
     	 { return ( $op1 or $self->_operate($ops[1]) ) }
   elsif($fn =~ /\^|xor/i)
     	 { return ( $op1 xor $self->_operate($ops[1]) ) }
   elsif($fn =~ /\!|not/i)
     	 { return ( not $op1 ) }
   else { $self->throw("Unknown boolean operation", $var) }
}

=head _grouprules_cleanup

=cut

# Issue #7
sub _grouprules_cleanup {
   my $self = shift;
   if(defined $self->{'_seqsdb'}) {
      my $tmp = $self->{'_seqsdb'};
      for my $k (0 .. $#{$self->genomes}){
         while(<$tmp/$k.*>){
	    unlink $_ or $self->throw("Impossible to delete '$_'", $!);
	 }
	 unlink "$tmp/$k" or $self->throw("Impossible to delete '$tmp/$k'", $!);
      }
      rmdir $tmp;
   }
}

=head2 _initialize

=cut

sub _initialize {
   my($self, @args) = @_;
   $self->_register_cleanup_method(\&_grouprules_cleanup);
   my($source, $target, $features, $loci) =
   	$self->_rearrange([qw(SOURCE TARGET FEATURES LOCI)], @args);
   # $self->throw('Discouraged use of -features flag, use -loci instead');
   $self->source($source);
   $self->target($target);
   $loci = $features if defined $features and not defined $loci;
   $self->locigroup($loci);
}


1;

