package tsheets::job;

use Moose;
use tsheets;
use Data::Dumper;

has api_key => (
    is          => 'rw',
    isa         => 'Str',
    required    =>  1
);

has client_url => (
	is			=> 'rw',
	isa			=> 'Str',
	required	=>	1
);

has username => (
    is          => 'rw',
    isa         => 'Str',
    required    =>  1
);

has password => (
    is          => 'rw',
    isa         => 'Str',
    required    =>  1
);


sub BUILD { 
	my $self = shift;
	$self->{ts} = tsheets->new(
		{
			'client_url'=>$self->{client_url},
			'username'=>$self->{username},
			'password'=>$self->{password},
			'api_key'=>$self->{api_key}
		}
	);	
}


sub DEMOLISH { 
	my $self = shift;
	$self->{ts}->logout();
}

sub load { 
	my $self = shift;
	my $jobID = shift;

	if (!$jobID) { 
		warn "You must specify a job ID!";
		return undef;
	}	

	my $job = $self->{ts}->listJobs({'ids'=>[$jobID]});
	
	if (defined($job)) { 
		$self->{current_job} = undef;
	}

	foreach my $key (keys %{$$job[0]}) { 
		$self->{current_job}{$key} = $$job[0]{$key};
	}

}

sub _changeJobAttr {
	my $self 	= shift;
	my $attr	= shift;
	my $value	= shift;
	my $name	= undef;

	if ($attr eq "name") { $attr = "job_code_name"; } 
	
	if ($attr eq 'job_code_name') { 
		$name = $value;	
	} else { 
		$name = $self->{current_job}{name};
	}

	my $newJob = $self->{ts}->editJob({
		'job_code_id'=>$self->{current_job}{id},
		'job_code_name'=>$name,
		$attr => $value,
	});

	return $newJob;
}

sub has_children { 
	my $self 	= shift;
	return $self->{current_job}{has_children};
}

sub ctime { 
	my $self 	= shift;
	return $self->{current_job}{ctime};
}

sub global { 
	my $self 	= shift;
	my $new  	= shift;
	if ($new && $new != $self->{current_job}{global}) { 
		$self->_changeJobAttr('global',$new);
	}
	return $self->{current_job}{global};
}
sub mtime { 
	my $self 	= shift;
	return $self->{current_job}{mtime};
}
sub name { 
	my $self 	= shift;
	my $new		= shift;
	if ($new && $new ne $self->{current_job}{name}) { 
		return $self->_changeJobAttr('job_code_name',$new);
	} else { 
		return $self->{current_job}{name};
	}
}
sub active {
	my $self 	= shift;
	my $new 	= shift;
	return $self->{current_job}{active};
}
sub client_id {
	my $self 	= shift;
	my $new		= shift;
	return $self->{current_job}{client_id};
}
sub parent_id {
	my $self 	= shift;
	my $new		= shift;
	return $self->{current_job}{parent_id};
}
sub rate {
	my $self 	= shift;
	my $new		= shift;
	return $self->{current_job}{rate};
}
sub billable {
	my $self 	= shift;
	my $new		= shift;
	return $self->{current_job}{billable};
}

sub mdate {
	my $self 	= shift;
	return $self->{current_job}{mdate};
}
sub type {
	my $self 	= shift;
	my $new		= shift
	return $self->{current_job}{type};
}

sub id {
	my $self = shift;
	return $self->{current_job}{id};
}


no Moose;

1;
