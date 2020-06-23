# bash completion for rex

_rex()
{
    local cur prev

    COMPREPLY=()
    _get_comp_words_by_ref -n : cur prev

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W '$(_parse_help "$1" -h)' -- "$cur") )
        return
    fi

    case "$prev" in
        -f)
            _filedir
            ;;
        -H)
            if [ -f Rexfile ]; then
                hosts=( $(rex -Ty 2>/dev/null | perl -MYAML -MList::MoreUtils=uniq -E 'my $groups = Load(join "", <>)->{groups}; say $_->{name} for uniq sort map { @{ $groups->{$_} } } keys %$groups') )
                COMPREPLY=( $( compgen -W '${hosts[@]}' -- "$cur" ) ) || _known_hosts_real -a "$cur"
            fi
            ;;
        -E)
            if [ -f Rexfile ]; then
                envs=( $(rex -Ty 2>/dev/null | perl -MYAML -e 'my $envs = Load(join "", <>)->{envs}; print "$_\n" for @$envs;') )
                COMPREPLY=( $( compgen -W '${envs[@]}' -- "$cur" ) )
            fi
            ;;
        -G)
            if [ -f Rexfile ]; then
                groups=( $(rex -Ty 2>/dev/null | perl -MYAML -e 'my $groups = Load(join "", <>)->{groups}; print "$_\n" for keys %$groups;') )
                COMPREPLY=( $( compgen -W '${groups[@]}' -- "$cur" ) )
            fi
            ;;

        *)
            if [ -f Rexfile ]; then
                tasks=( $(rex -Ty 2>/dev/null | perl -MYAML -E 'my $tasks = Load(join "", <>)->{tasks}; say $_ for @$tasks;') )
                COMPREPLY=( $( compgen -W '${tasks[@]}' -- "$cur" ) )
            fi
            ;;
    esac

    _rex_fix_colon_reply
    return 0

} &&
complete -F _rex rex

_rex_fix_colon_reply()
{
    local colprefs i
    colprefs=${cur%"${cur##*:}"}
    i=${#COMPREPLY[*]}
    while [ $((--i)) -ge 0 ]; do
        COMPREPLY[$i]=${COMPREPLY[$i]#"$colprefs"}
    done
}

# Local variables:
# mode: shell-script
# indent-tabs-mode: nil
# End:
# ex: ts=4 sw=4 et filetype=sh
