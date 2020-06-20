#compdef rex
# zsh completions for 'rex'
# initially generated with http://github.com/RobSis/zsh-completion-generator
# complete groups, environments, hosts and tasks (default)

local curcontext="$curcontext" state state_descr line context ret=1

typeset -A opt_args
_hostgroups(){
	groups=(${(f)"$(rex -Ty 2>/dev/null| perl -MYAML -e 'my $groups = Load(join "", <>)->{groups}; print "$_\n" for keys %$groups;')"})
	_wanted hostgroups expl "available host groups" compadd -a groups
}

_envs(){
	envs=(${(f)"$(rex -Ty 2>/dev/null| perl -MYAML -e 'my $envs = Load(join "", <>)->{envs}; print "$_\n" for @$envs;')"})
	_wanted environments expl "available environments" compadd -a envs
}

# return hosts managed by rex or any other host availabe via zsh's _hosts function
_rex_hosts() {
	rexhosts=(${(f)"$(rex -Ty 2>/dev/null| perl -MYAML -MList::MoreUtils=uniq -E 'my $groups = Load(join "", <>)->{groups}; say $_->{name} for uniq sort map { @{ $groups->{$_} } } keys %$groups')"})
	_wanted hosts expl "rex managed hosts" compadd -a rexhosts || _hosts
}

local arguments
arguments=(
	'-b[run batch]'
	'-e[run the given code fragment]'
	'-E[execute a task on the given environment]:environments:_envs'
	'-G[|-g  Execute a task on the given server groups]:hosts group:_hostgroups'
	'-H[execute a task on the given hosts (space delimited)]:host:_rex_hosts'
	'-z[execute a task on hosts from this commands output]'
	'-K[public key file for the ssh connection]'
	'-P[private key file for the ssh connection]'
	'-p[password for the ssh connection]'
	'-u[username for the ssh connection]'
	'-d[show debug output]'
	'-ddd[show more debug output (includes profiling output)]'
	'-m[monochrome output: no colors]'
	'-o[output format]'
	'-q[quiet mode: no log output]'
	'-qw[quiet mode: only output warnings and errors]'
	'-Q[really quiet: output nothing]'
	'-T[list tasks]'
	'-Ta[List all tasks, including hidden]'
	'-Tm[list tasks in machine-readable format]'
	'-Tv[list tasks verbosely]'
	'-Ty[list tasks in YAML format]'
	'-c[turn cache ON]'
	'-C[turn cache OFF]'
	'-f[use this file instead of Rexfile]:filename:_files'
	'-F[force: disregard lock file]'
	'-h[display this help message]'
	'-M[load this module instead of Rexfile]'
	'-O[pass additional options, like CMDB path]'
	'-s[use sudo for every command]'
	'-S[password for sudo]'
	'-t[number of threads to use (aka parallelism param)]'
	'-v[display (R)?ex version]'
	'*:options:->vary'
)

_arguments -C -s -A "*" $arguments  && ret=0

case "$state" in
	vary)
		local optsfile
		optsfile='Rexfile'
		if [[ -e $optsfile ]]; then
			tasks=(${(f)"$(rex -Ty 2>/dev/null| perl -MYAML -E 'my $tasks = Load(join "", <>)->{tasks}; say $_ for @$tasks;')"})
			_wanted tasks expl "available tasks" compadd -a tasks
		fi
		;;
esac

return $ret
