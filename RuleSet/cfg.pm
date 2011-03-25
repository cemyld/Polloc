package Polloc::RuleSet::cfg;

use strict;
use Polloc::Polloc::Config;
use Polloc::RuleI;
use Polloc::GroupRules;
use Bio::Seq;

use base qw(Polloc::RuleIO);

sub new {
   my($caller,@args) = @_;
   my $self = $caller->SUPER::new(@args);
   $self->_initialize(@args);
   return $self;
}

sub _initialize {
   my($self,@args) = @_;
   my($init_id) = $self->_rearrange([qw(INIT_ID)], @args);
   $self->init_id($init_id);
   $self->_parse_cfg(@args);
}

sub _parse_cfg {
   my($self,@args) = @_;
   $self->_cfg( Polloc::Polloc::Config->new(-noparse=>1, @args) );
   $self->_cfg->spaces(".rule");
   $self->_cfg->spaces(".rulegroup");
   $self->_cfg->spaces(".groupextension");
   $self->read(@args);
}

sub read {
   my($self,@args) = @_;
   $self->_cfg->_register_handle_function(
   		-obj=>$self,
		-fun=>"_parse_rule",
		-token=>".rule.add");
   $self->_cfg->_register_handle_function(
   		-obj=>$self,
		-fun=>"_parse_set",
		-token=>".rule.set");
   $self->_cfg->_register_handle_function(
   		-obj=>$self,
		-fun=>"_parse_set",
		-token=>".rule.setrule",
		-defaults=>[-isrule=>1]);
   $self->_cfg->_register_handle_function(
   		-obj=>$self,
		-fun=>"_parse_glob",
		-token=>".rule.glob");
   $self->_cfg->_register_handle_function(
   		-obj=>$self,
		-fun=>"_parse_glob",
		-token=>".rulegroup.glob");
   $self->_cfg->_register_handle_function(
   		-obj=>$self,
		-fun=>"_parse_group_var",
		-token=>".rulegroup.var");
   $self->_cfg->_register_handle_function(
   		-obj=>$self,
		-fun=>"_parse_group_eval",
		-token=>".rulegroup.eval");
   $self->_cfg->_register_handle_function(
   		-obj=>$self,
		-fun=>"_parse_ext_eval",
		-token=>".groupextension.eval"
		);
   $self->_cfg->parse(@args);
}

sub value {
   my($self,@args) = @_;
   my($key,$value,$alert) = $self->_rearrange([qw(KEY VALUE ALERT)], @args);
   $self->_cfg->_save(-key=>$key, -value=>$value, -space=>"rule") if $value;

   # Search first in the Rule.Set space
   $value = $self->_cfg->value(-key=>$key, -space=>"rule.set", -noalert=>1);
   return $value if defined $value;
   # Then search in the Rule space
   $value = $self->_cfg->value(-key=>$key, -space=>"rule", -noalert=>1);
   return $value if defined $value;
   # Search in the root space otherwise
   return $self->_cfg->value(-key=>$key, -space=>".", -noalert=>!$alert);
}

sub _cfg {
   my($self,$value) = @_;
   $self->{'_cfg_obj'} = $value if $value;
   return unless $self->{'_cfg_obj'};
   $self->{'_cfg_obj'}->isa('Polloc::Polloc::Config') or
   	$self->throw("Unexpected type of cfg object", $self->{'_cfg_obj'});
   return $self->{'_cfg_obj'};
}

sub _parse_rule {
   my($self, $body, $defaults) = @_;
   $body or $self->throw("Empty body for .rule.add", $body);
   $body=~m/^\s*(\w+)\s*:\s*([\w\.]+)(\s+at\s+([^']+))?(\s+as\s+'(.+)')?\s*$/i or
   	$self->throw("Bad format for the body of .rule.add, ".
			"expecting type:name or type:name at context", $body);
   my($type,$key,$context,$name) = ($1,$2,$4,$6);
   my $value;
   unless($name) {
      $name = $key;
      $name =~ s/^\.rule\.//i;
      $name =~ s/^\.//;
   }
   my $id = $self->_next_child_id;
   $value = $self->_cfg->value(-key=>$key, -space=>"rule", -mandatory=>1)
   		unless defined $value;
   my $rule = Polloc::RuleI->new(
   			-type=>$type,
   			-format=>$self->format,
   			-name=>$name,
			-id=>defined $id ? $id : "",
			-context=>$self->_parse_context($4),
			-value=>$value);
   my $index = $self->add_rule( $rule );
   $self->{'_key_rule_map'} ||= {};
   $self->{'_key_rule_map'}->{ $self->_cfg->_parse_key(-key=>$key, -space=>"rule") } = $index;
}


=head2
 
 Description	: Parses the body of the .rule.set and the .rule.setrule statements
 		  with the structure [set|setrule] key param='value'.  If setrule,
		  the value is replaced by the corresponding Polloc::RuleI object
 Params		: Str body, described above
 		  Array reference defaults, supporting only the -isrule flag (to
		  distinguish among set and setrule)
 Return		: none

=cut
sub _parse_set {
   my($self,$body,$defaults) = @_;
   $body or $self->throw("Empty body for .rule.set", $body);
   $body =~ m/^\s*([^\s]+)\s+([\w-]+)\s*=\s*'(.*)'\s*/i or
   	$self->throw("Bad format for the body of .rule.set, ".
			"expecting key param='value'", $body);
   my($key,$param,$value) = ($1,$2,$3);
   my($isrule) = $self->_rearrange([qw(ISRULE)], @{$defaults});
   my $index = $self->{'_key_rule_map'}->{ $self->_cfg->_parse_key(-key=>$key, -space=>"rule") };
   $self->debug("Setting $param as $value on $key ($index)");
   if($isrule){
      my $obj = $self->{'_key_rule_map'}->{ $self->_cfg->_parse_key(-key=>$value, -space=>"rule") };
      $self->debug("Map $value: $obj");
      $self->throw("Impossible to locate the rule $value",$obj) unless defined $obj;
      $self->get_rule($index)->safe_value($param, $self->get_rule($obj));
   }else{
      $self->get_rule($index)->safe_value($param, $value);
   }
}

sub _parse_glob {
   my($self,$body,$defaults) = @_;
   $body or $self->throw("Empty body for .rule.glob", $body);
   $body =~ m/^\s*(\w+)\s*=\s*'(.*)'\s*/i or
   	$self->throw("Bad format for the body of .rule.glob, ".
			"expecting param='value'", $body);
   my($param,$value) = (lc($1), $2);
   $self->safe_value($param, $value);
}


sub _parse_group_var {
   my($self,$body,$defaults) = @_;
   $body or $self->throw("Empty body for .rulegroup.var", $body);
   $body =~ m/^([^\s]+)\s+([^\s=]+)\s*=\s*(.*)\s*/i or
   	$self->throw("Bad format for the body of .rule.glob, ".
			"expecting type name = operation...", $body);
    #my %rulegroup = (-type=>lc($1), -name=>$2, -operation=>$3, -source=>$self->safe_value("source"));
    my %rulegroup = (-type=>lc($1), -operation=>$3);
    $self->{'_rulegroup'} = {} unless defined $self->{'_rulegroup'};
    $self->debug("Saving '$2'");
    $self->{'_rulegroup'}->{$2} = \%rulegroup;
}


sub _parse_group_eval {
   my($self, $body,$defaults) = @_;
   return unless defined $self->{'_rulegroup'};
   defined $self->{'_rulegroup'}->{$body} or
      $self->throw("Impossible to evaluate an undefined variable", $body);
   my $group = new Polloc::GroupRules(
   	-source=>$self->safe_value("source"),
	-target=>$self->safe_value("target"));
   $group->condition($self->_parse_group_operation($body, $defaults));
   # $self->vardump($group->condition);
   $self->addgrouprules($group);
}

sub _parse_ext_eval {
   my($self, $body, $defaults) = @_;
   defined $self->{'_rulegroup'}
   	or $self->throw("Defining group extension but no grouping rule defined", $body);
   my @groups = @{$self->grouprules};
   my $group = $groups[$#groups];
   $group->extension($self->_cfg->value(-key=>$body, -space=>"groupextension", -mandatory=>1));
}

sub _parse_group_operation {
   my($self,$name,$defaults) = @_;
   return {-type=>'cons', -operation=>$name, -name=>$name} if defined $name and $name =~ /^FEAT[12]$/;
   my $body = $self->{'_rulegroup'}->{$name};
   defined $body or $self->throw("Impossible to locate the variable $name", $body);
   my $t = $body->{'-type'};
   my $o = $body->{'-operation'};
   defined $t or $self->throw("You declared an operation without return type", $body);
   defined $o or $self->throw("You declared an operation without body", $body);
   $o =~ s/^\s*//;
   $o =~ s/\s*$//;
   if($t eq 'bool'){
      if($o =~ m/^(t(rue)?|1)$/i){
	 return {-type=>'bool', -val=>1, -name=>$name};
      }elsif($o =~ m/^(f(alse)?|0)$/i){
         return {-type=>'bool', -val=>0, -name=>$name};
      }elsif($o =~ m/^([^\s]+)\s*([><]=?|&&?|\|\|?|\^|and|or|xor)\s*([^\s]+)$/i){
         my($o1b,$f,$o2b) = ($1,$2,$3);
	 my $o1 = $self->_parse_group_operation($o1b, $defaults);
	 my $o2 = $self->_parse_group_operation($o2b, $defaults);
	 return {-type=>'bool', -operators=>[$o1, $o2], -operation=>$f, -name=>$name};
      }elsif($o =~ m/^(!|not)\s*([^\s]+)$/i){
         my $f = $1;
         my $o1 = $self->_parse_group_operation($2, $defaults);
	 return {-type=>'bool', -operators=>[$o1], -operation=>$f, -name=>$name};
      }else{
         $self->throw("Impossible to parse boolean", $body);
      }
   }elsif($t eq 'num'){
      if($o =~ m/^[-+]?\d*\.?\d+(e[-+]?\d*\.?\d+)?$/) {
         return {-type=>'num', -val=>$o+0, -name=>$name};
      }elsif($o =~ m/^([^\s]*)\s*(\+|\-|\*\*?|\/|\^|%|aln-sim( with)?|aln-score( with)?)\s*([^\s]*)$/i){
         my($o1b,$f,$o2b) = ($1,$2,$5);
	 my $o1 = $self->_parse_group_operation($o1b, $defaults);
	 my $o2 = $self->_parse_group_operation($o2b, $defaults);
	 return {-type=>'num', -operators=>[$o1, $o2], -operation=>$f, -name=>$name};
      }else{
         $self->throw("Impossible to parse number", $body);
      }
   }elsif($t eq 'seq'){
      if($o =~ m/^[A-Za-z]+$/){
         return {-type=>'seq', -val=>Bio::Seq->new(-seq=>$o), -name=>$name};
      }elsif($o =~ m/^([^\s]+)\s+(at)\s*\[(-?\d)\s*[,;]\s*(-?\d+)\s*\.\.\s*(-?\d+)\]$/i){
         my($o1b,$extra1,$extra2,$extra3) = ($1, $3+0, $4+0, $5+0);
	 my $o1 = $self->_parse_group_operation($o1b, $defaults);
	 return {-type=>'seq', -operators=>[$o1, $extra1, $extra2, $extra3], -operation=>'sequence', -name=>$name};
      }elsif($o =~ m/^rev(comp?( of)?)?\s+([^\s]+)$/i){
         my $o1 = $self->_parse_group_operation($3, $defaults);
	 return {-type=>'seq', -operators=>[$o1], -operation=>'reverse', -name=>$name};
      }elsif($o =~ m/^seq\s+([^\s]+)/){
         my $o1 = $self->_parse_group_operation($1, $defaults);
	 return {-type=>'seq', -operators=>[$o1], -operation=>'sequence', -name=>$name};
      }else{
         $self->throw("Impossible to parse number", $body);
      }
   }
}


sub _parse_context {
   my($self,@args) = @_;
   my($context) = $self->_rearrange([qw(CONTEXT)], @args);
   $context ||= "default";
   $self->debug("Parsing context '$context'");
   return [0,0,0] if $context eq "default";
   $context =~ s/^[\[\(]+//;
   $context =~ s/[\]\)]+$//;
   if($context=~m/^([+-]?\d)\s*([;,:-]|\.\.)\s*([+-]?\d+)\s*([;,:-]|\.\.)\s*([+-]?\d+)/){
      return [$1+0, $3+0, $5+0];
   }
   if($context=~m/^[+-]?0+([;,-]|\.\.|)$/){
      return [0,0,0];
   }
   return [0,0,0];
}


1;
