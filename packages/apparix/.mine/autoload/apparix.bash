# shellcheck disable=SC2155,SC2181,SC2016 shell=bash
# vim: ft=sh ts=4 sw=0 sts=-1 et

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                              A P P A R I X
#
#        bookmarks for the command line with comprehensive tab completion
#                             works for bash and zsh
#                                                            Authors:
#                                                            Stijn van Dongen
#                                                            Sitaram Chamarty
#                                                            Izaak van Dongen
#                               Quick Guide:
#
#  -  save this file in $HOME/.bourne-apparix
#  -  issue 'source $HOME/.bourne-apparix
#  -  go to a directory and issue 'bm foo'
#  -  you can now go to that directory by issuing 'to foo'
#  -  you can go straight to a subdirectory       'to foo asubdirname'
#  -  you can use tab completion:                 'to foo as<TAB>'
#                                                 'to foo asubdirname/<TAB>'
#  -  try tab completion and command substitution, see the examples below.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#  This Apparix is a pure shell implementation of an older system written
#  partly in C. This shell re-implementation is the reason why several of the
#  names here use apparish.  I prefer to think of the abstract system itself as
#  apparix. Never mind!
#
#    An overview of apparix functionality.

function ahoy() {
    cat <<EOH
Apparix functions, grouped and roughly ordered by expected use.
             Below all SUBDIR and FILE can be tab-completed.

  bm   MARK               Bookmark current directory as mark
  to   MARK [SUBDIR]      Jump to mark or a subdirectory of mark
----------------------------------------------
  als  MARK [SUBDIR] [ls-options]  List mark dir or subdir
  ald  MARK [SUBDIR]      List subdirs of mark dir or subdir
                          ignores hidden directories
  aldr MARK [SUBDIR]      Like ald, recursively
  amd  MARK [SUBDIR] [mkdir options] Make dir in mark
  a    MARK [SUBDIR/]FILE Echo the true location of file, useful
                 e.g. in: cp file \$(a mark dir)
---------------------------------
  aget MARK [SUBDIR/]FILE Copy file to current directory
  aput MARK [SUBDIR] -- FiLE+   Copy files to mark (-- required)
-----------------------------
  ae MARK [SUBDIR/]FILE [editor options] Edit file in mark
  av MARK [SUBDIR/]FILE [editor options] View file in mark
------------------------
  amibm                   See if current directory is a bookmark
  bmgrep PATTERN          List all marks where target matches PATTERN
--------------------
  agather MARK            List all targets for bookmark mark
  whence MARK             Menu selection for mark with multiple targets
----------------
  todo MARK [SUBDIR]      Edit TODO file in mark dir
  rme MARK [SUBDIR]       Edit README file
  portal                  current directory subdirs become mark names
  portal-expand           Re-expand all portals
  aghast MARK [SUBDIR/]FILE [dummy options] testing the apparix muxer
-------
  Where options passing is indicated above:
   - The sequence has to start with a '-' or '+' character.
   - Multiple options with arguments can be passed.
   - -- occurrences are removed but will start a sequence.
   - FWIW Arguments with spaces in them seemed to work under limited
     testing, e.g. ae pl main.nf '+set paste'
EOH
}

#                            Use notes
#
#  - Use apparix with cyclic tab completion. It's what gives the oomph.
#  - Apparix uses by default the most recent MARK if identical marks exist.
#  - I rarely delete bookmarks. They serve as a chronology of my travails.
#  - For deleting bookmarks I find 'via' the quickest.
#  - Bookmark obscure and rarely visited but important locations.
#  - You can forget both mark and location; 'via' and 'bmgrep' will help.
#  - Use 'via' and 'bmgrep'
#  - It can e.g. be useful to use 'now' for the current hotspot of work.
#  - The list of 'now' bookmarks (seen with 'agather now') is a log of activity.
#  - The portal functionality mimics bash CDPATH. I don't use it.
#  - I find it useful to have this alias:
#        alias a=apparish
#  for use in command substitution, e.g.
#        cp myfile $(a bm)
#
#  This is a big decision from a Huffman point of view.  If you want to remove
#  it, go to all the places in the lines below where the name Huffman is
#  mentioned and remove the relevant part.

#                       BASH and ZSH functions
#
#  Apparix should work for modern bourne-style shells, not including the
#  bourne shell.  Name this file for example .bourne-apparix in your $HOME
#  directory, and put the line 'source $HOME/.bourne-apparix' (without quotes)
#  in the file $HOME/.bashrc or $HOME/.bash_login if you use bash, in the file
#  $HOME/.zshrc if you use zsh.

#  This code goes a long way to dealing with spaces, tabs and nasty characters
#  in paths thanks to Izaak.  A much simpler parallel completion implementation
#  using bash native completion is triggered if you set APPARIX_BERTRAND_RUSSEL
#  to a nonzero value before sourcing this file, but it will not cope as well
#  with weird characters.

#
#  Big thanks to Sitaram Chamarty for all the important parts of the initial
#  bash completion code, and big thanks to Izaak van Dongen for figuring out
#  the zsh completion code, subsequently improving and standardising the bash
#  completion code, adding enhancements and rewrites all through the code base
#  and suggesting the name apparish. Although it's now called apparix again.
#  Still appreciate it.
#

APPARIX_HOME="${APPARIX_HOME:=$HOME}"
# ensure APPARIX_HOME exists
mkdir -p "$APPARIX_HOME"
APPARIXRC="${APPARIXRC:=$APPARIX_HOME/.apparixrc}"
APPARIXEXPAND="${APPARIXEXPAND:=$APPARIX_HOME/.apparixexpand}"
APPARIXLOG="${APPARIXLOG:=$APPARIX_HOME/.apparixlog}"

# ensure set up and log files exist
touch "$APPARIXRC"
touch "$APPARIXEXPAND"
touch "$APPARIXLOG"

APPARIX_FILE_FUNCTIONS=(a ae av aget toot apparish aghast) # Huffman (remove a)
APPARIX_DIR_FUNCTIONS=(to als aput ald aldr amd todo rme)

# require one or two
function apx_onetwo() {
    (($1 == 1)) || (($1 == 2))
}

# print usage
function apx_usage() {
    echo -n $(ahoy | grep "^  *$1\>")
    echo " (use ahoy for more)"
}

# sanitise $1 so that it becomes suitable for use with your basic grep
function apx_grepsanitise() {
    sed 's/[].*^$]\|\[/\\&/g' <<<"$1"
}

# vim-like: totally silence the given command. does not
# affect return status, so can be used inside if statements.
function apx_silent() {
    "$@" >/dev/null 2>/dev/null
}

# Usage:
#     amux mark [dir] [opt/or/arg+] ++ command [oPt/oR/aRg+]
# This will be translated to
#     command [opt/or/arg+] [oPt/oR/aRg+] TARGET
# where
#     [opt/or/arg+]
# comes from the user commandline invocation
#     command [oRt/oR/aRg+]
# comes from the amux-wrapping function The optional sequence of opt-or-arg is
# recognised/consumed as follows
# - anything starting with - or + and all subsequent arguments up until ++
# - among these, -- is a sentinel and will be discarded.
# This can be used to start FILE+ arguments such as aput does.
# Note that -- is part of the aput usage itself.

function amux() {
    local optorarg=()
    local mark=$1
    local dir=
    local copy=("$@")
    shift
    local get_options=false
    local caller=${FUNCNAME[1]}

    if [[ $mark == '++' ]]; then
        apx_usage "$caller"
        echo "Arguably a lack of argument"
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        item="$1"
        shift
        if [[ $item == '++' ]]; then
            break
        elif $get_options || [[ $item == [+-]* ]]; then
            if [[ $item != '--' ]]; then
                optorarg+=("$item")
            fi
            get_options=true
        elif [[ -z "$dir" ]]; then
            dir="$item"
        else
            2>&1 echo "Mixed up mess in amux (caller ${copy[@]})"
            break
        fi
    done

    command=$1
    shift
    [[ -n "$command" ]] && ! apx_silent command -v "$command" && 2>&1 echo "Not a command, $command"

    if ! loc=$(apparish "$mark" "$dir"); then
        return 1
    fi
    $command "${optorarg[@]}" "$@" "$loc"
}

# apparix list
function als() {
    amux "$@" ++ ls --
}

# apparix mkdir in mark
function amd() {
    amux "$@" ++ mkdir --
}

# apparix view of file
function av() {
    amux "$@" ++ view --
}

# apparix edit of file
function ae() {
    amux "$@" ++ "${EDITOR:-vim}" --
}

# cd to a mark
function to() {
    amux "$@" ++ cd --
}

# intermediate function to swap argument order
function apparix_aget_cp() {
    cp -vi "$@" .
}

# apparix get; copy something from mark
function aget() {
    amux "$@" ++ apparix_aget_cp
}

# apparix put; copy something to mark
function aput() {
    if ! apx_elemOf '--' "${@:2:2}"; then
        apx_usage aput
        return 1
    fi
    amux "$@" ++ cp -vi
}

function aghast_test() {
    for i in "$@"; do echo "[$i]"; done
}

function aghast() {
    amux "$@" ++ aghast_test -- test1 test2
}

# apparix listing of directories (rather than files) directly below mark.
# With find argument/option order requirements not yet really amux material,
# unless placeholder parachuting is added. 🤔 The outcome of apparix
# *is* always just a simple string.
# These versions print paths relative to target and ignore hidden files.
# Future version perhaps pass in + parse flags to control
# (1) prefix behaviour (-P for print prefix)
# (2) hidden behaviour (-H for hidden)
# Then also extract -maxdepth 1.
function ald() {
    local loc
    if ! apx_onetwo $#; then
        apx_usage ald
    else
        loc="$(apparish "$@")" &&
            find -L "$loc" -mindepth 1 -maxdepth 1 -type d -a \( -name ".*" -prune -o -printf '%P\n' \)
    fi
}
# apparix listing of subdirectories of mark, recursively
function aldr() {
    local loc
    if ! apx_onetwo $#; then
        apx_usage aldr
    else
        loc="$(apparish "$@")" &&
            find -L "$loc" -mindepth 1 -type d -a \( -name ".*" -prune -o -printf '%P\n' \)
    fi
}

# Huffman (remove this paragraph, or just alias "a" yourself)
# if ! apx_silent command -v a; then
#     alias a='apparish'
# else
#     >&2 echo "Apparix: not aliasing a"
# fi
#
# if ! apx_silent command -v via; then
#     alias via='"${EDITOR:-vim}" "$APPARIXRC"'
# else
#     >&2 echo "Apparix: not aliasing via"
# fi
#
# if ! apx_silent bind -q menu-complete; then
#     cat <<EOH
# --> Consider adding the line
# bind '"\t":menu-complete'
# <-- to e.g. $HOME/.bashrc
# This enables cyclic tab completion on directories and files below apparix marks.
# We apologise profusely for this interruption.
# EOH
# fi

function apparish() {
    if [[ 0 == "$#" ]]; then
        cat -- "$APPARIXRC" "$APPARIXEXPAND" | tr ', ' '\t_' | column -t
        return
    fi
    local mark="$1"
    local list="$(command grep -F ",$mark," "$APPARIXRC" "$APPARIXEXPAND")"
    if [[ -z "$list" ]]; then
        >&2 echo "Mark '$mark' not found"
        return 1
    fi
    local target="$( (tail -n 1 | cut -f 3 -d ',') <<<"$list")"
    if [[ 2 == "$#" ]]; then
        echo "$target/$2"
    else
        echo "$target"
    fi
}

function agather() {
    if [[ 0 == "$#" ]]; then
        apx_usage agather
        return 1
    fi
    local mark="$1"
    command grep -F ",$mark," -- "$APPARIXRC" "$APPARIXEXPAND" | cut -f 3 -d ','
}

function bm() {
    if [[ 0 == "$#" ]]; then
        apx_usage bm
        return 1
    fi
    local mark="$1"
    local list="$(agather "$mark")"
    echo "j,$mark,$PWD" | tee -a -- "$APPARIXLOG" >>"$APPARIXRC"
    if [[ -n "$list" ]]; then
        listsize=$((1 + $(wc -l <<<"$list")))
        echo "$PWD added, $listsize total"
    fi
}

function portal() {
    echo "e,$PWD" >>"$APPARIXRC"
    portal-expand
}

function portal-expand() {
    local parentdir
    rm -f -- "$APPARIXEXPAND"
    true >"$APPARIXEXPAND"
    command grep '^e,' -- "$APPARIXRC" | cut -f 2 -d , |
        while read -r parentdir; do
            # run in an explicit bash subshell to be able to locally set the
            # right options
            parentdir="$parentdir" APPARIXEXPAND="$APPARIXEXPAND" bash <<EOF
            cd -- "\$parentdir" || return 1
            shopt -s nullglob
            shopt -u dotglob
            shopt -u failglob
            GLOBIGNORE="./:../"
            for _subdir in */ .*/; do
                subdir="\${_subdir%/}"
                echo "j,\$subdir,\$parentdir/\$subdir" >> "\$APPARIXEXPAND"
            done
EOF
        done
}

function whence() {
    if [[ 0 == "$#" ]]; then
        apx_usage whence
        return 1
    fi
    local mark="$1"
    select target in $(agather "$mark"); do
        cd -- "$target" || return 1
        break
    done
}

# This may need some love. But I mainly use the todo function.
function toot() {
    local file
    if [[ 3 == "$#" ]]; then
        file="$(apparish "$1" "$2")/$3"
    elif [[ 2 == "$#" ]]; then
        file="$(apparish "$1")/$2"
    else
        >&2 echo "toot tag dir file OR toot tag file"
        return 1
    fi
    if [[ "$?" == 0 ]]; then
        "${EDITOR:-vim}" "$file"
    fi
}

function todo() {
    toot "$@" TODO
}

function rme() {
    toot "$@" README
}

function apx_amibm() {
    command grep -- "^j,.*,$(apx_grepsanitise "$PWD")$" "$APPARIXRC" "$APPARIXEXPAND" | cut -f 2 -d ','
}

function apx2_amibm() {
    for tag in $(apx_amibm); do
        local path=$(apparish $tag)
        local annot=""
        if [[ "$path" != "$PWD" ]]; then
            annot='-'
        elif (($(agather "$tag" | wc -l) > 1)); then
            annot='+'
        fi
        echo "$tag$annot"
    done
}

# apparix search bookmark
function amibm() {
    echo $(apx2_amibm)
}

# apparix search bookmark
function bmgrep() {
    pat="${1?Need a pattern to search}"
    command grep -- "$pat" "$APPARIXRC" | cut -f 2,3 -d ',' | tr ',' '\t' | column -t
}

if [[ -n "$BASH_VERSION" ]]; then
    # bash specific helper functions

    # assert that bash version is at least $1.$2.$3
    version_assert() {
        for i in {1..3}; do
            if ((BASH_VERSINFO[$((i - 1))] > ${!i})); then
                return 0
            elif ((BASH_VERSINFO[$((i - 1))] < ${!i})); then
                # echo "Your bash is older than $1.$2.$3" >&2
                return 1
            fi
        done
        return 0
    }

    # define a function to read lines from a file into an array
    # https://github.com/koalaman/shellcheck/wiki/SC2207
    if apx_silent version_assert 4 0 0; then
        function read_array() {
            mapfile -t goedel_array <"$1"
        }
    elif apx_silent version_assert 3 0 0; then
        function read_array() {
            goedel_array=()
            while IFS='' read -r line; do
                goedel_array+=("$line")
            done <"$1"
        }
    else
        >&2 echo "really, bash 2 is too cool to run apparix"
        function read_array() {
            local IFS=$'\n'
            # this is a bad fallback implementation on purpose
            # shellcheck disable=SC2207
            goedel_array=($(cat -- "$1"))
        }
    fi

    # https://stackoverflow.com/questions/3685970/check-if-a-bash-array-...
    # contains-a-value
    function apx_elemOf() {
        local e match="$1"
        shift
        for e; do [[ "$e" == "$match" ]] && return 0; done
        return 1
    }

    # a file, used by _apparix_comp
    function _apparix_comp_file() {
        local caller="$1"
        local cur_file="$2"

        if apx_elemOf "$caller" "${APPARIX_DIR_FUNCTIONS[@]}"; then
            if [[ -n "$APPARIX_BERTRAND_RUSSEL" ]]; then
                # # Directories (add -S / for slash separator):
                COMPREPLY=($(compgen -d -- "$cur_file"))
            else
                goedel_compfile "$cur_file" d
            fi
        elif apx_elemOf "$caller" "${APPARIX_FILE_FUNCTIONS[@]}"; then
            # complete on filenames. this is a little harder to do nicely.
            if [[ -n "$APPARIX_BERTRAND_RUSSEL" ]]; then
                COMPREPLY=($(compgen -f -- "$cur_file"))
            else
                goedel_compfile "$cur_file" f
            fi
        else
            >&2 echo "Unknown caller: Izaak has probably messed something up"
            return 1
        fi
    }

    # the existence of this function is a counterexample to Gödel's little known
    # incompletion theorem: there's no such thing as good completion on files in
    # Bash
    function goedel_compfile() {
        local part_esc="$1"
        case "$2" in
        f)
            local find_files=true
            ;;
        d) ;;
        *)
            >&2 echo "Specify file type"
            return 1
            ;;
        esac
        local part_unesc="$(bash -c "printf '%s' $part_esc")"
        local part_dir="$(dirname "$part_unesc")"
        COMPREPLY=()
        # Cannot pipe to while as that's a subshell and we modify COMREPLY.
        # echo "[$part_dir]"
        # echo "[$part_unesc]"
        # echo "[${FUNCNAME[@]}]"
        while IFS='' read -r -d '' result; do
            # This is a bit of a weird hack because printf "%q\n" with no
            # arguments prints ''. It should be robust, because any actual
            # single quotes will have been escaped by printf.
            if [[ "$result" != "''" ]]; then
                COMPREPLY+=("${result%/}")
            fi
            # Use an explicit bash subshell to set some glob flags.
        done < <(
            part_dir="$part_dir" part_unesc="$part_unesc" \
                find_files="$find_files" bash -c '
            shopt -s nullglob
            shopt -s extglob
            shopt -u dotglob
            shopt -u failglob
            GLOBIGNORE="./:../"
            if [[ "\$part_dir" == "." ]]; then
                find_name_prefix="./"               # what is this.
            fi
            # here we delay the %q escaping because I want to strip trailing /s
            if [ -d "$part_unesc" ]; then
                if [[ ! "$part_unesc" =~ '"'"'^/+$'"'"' ]]; then
                    part_unesc="${part_unesc%%+(/)}"
                fi
                if [ "$find_files" = "true" ]; then
                    printf "%q\0" "$part_unesc"/* "$part_unesc"/*/
                else
                    printf "%q\0" "$part_unesc"/*/
                fi
            else
                if [ "$find_files" = "true" ]; then
                    printf "%q\0" "$part_unesc"*/ "$part_unesc"*
                else
                    printf "%q\0" "$part_unesc"*/
                fi
            fi'
        )
    }

    # generate completions for a bookmark
    # this is currently case sensitive. Good? Bad? Who knows!
    function _apparix_compgen_bm() {
        cut -f2 -d, -- "$APPARIXRC" "$APPARIXEXPAND" | sort |
            command grep -i -- "^$(apx_grepsanitise "$1")"
        if [[ -n "$1" ]]; then
            cut -f2 -d, -- "$APPARIXRC" "$APPARIXEXPAND" | sort |
                command grep -i -- "^..*$(apx_grepsanitise "$1")"
        fi
    }

    # complete an apparix tag followed by a file inside that tag's
    # directory
    function _apparix_comp() {
        local tag="${COMP_WORDS[1]}"
        COMPREPLY=()
        if [[ "$COMP_CWORD" == 1 ]]; then
            read_array <(_apparix_compgen_bm "$tag" |
                xargs -d $'\n' printf "%q\n")
            COMPREPLY=("${goedel_array[@]}")
        else
            local cur_file="${COMP_WORDS[2]}"
            local app_dir="$(apparish "$tag" 2>/dev/null)"
            if [[ -d "$app_dir" ]]; then
                # can't run in subshell as _apparix_comp_file modifies
                # COMREPLY.  Just hope that nothing goes wrong, basically
                apx_silent pushd -- "$app_dir"
                # below, just using "$cur_file", bash -c blows up down the
                # line in the case that user types a quote (that is present
                # in directory name).  However to MARK <TAB> and to MARK
                # xyz<TAB> still work on subdirectories containing a quote as
                # longs as the user does not meddle with the quote(s)
                # themself.
                _apparix_comp_file "$1" $(printf %q "$cur_file")
                apx_silent popd
            else
                COMPREPLY=()
            fi
        fi
        return 0
    }

    # Register completions
    #   'nospace' prevents bash putting a space after partially completed paths
    #   'nosort' prevents bash from messing up the bespoke order in which bookmarks
    #   are completed
    apparix_o_nosort="-o nosort"
    if ! version_assert 4 4 0; then
        # >&2 echo "(Apparix: Can't disable alphabetic sorting of completions)"
        apparix_o_nosort=""
    fi
    complete -o nospace $apparix_o_nosort -F _apparix_comp \
        "${APPARIX_FILE_FUNCTIONS[@]}" "${APPARIX_DIR_FUNCTIONS[@]}"
    unset apparix_o_nosort

elif [[ -n "$ZSH_VERSION" ]]; then
    # Use zsh's completion system, as this seems a lot more robust, rather
    # than using bashcompinit to reuse the bash code but really this wasn't
    # a hassle to write
    autoload -Uz compinit
    compinit

    function _apparix_file() {
        IFS=$'\n'
        _arguments \
            '1:mark:($(cut -d, -f2 "$APPARIXRC" "$APPARIXEXPAND"))' \
            '2:file:_path_files -W "$(apparish "$words[2]" 2>/dev/null)"'
    }

    function _apparix_directory() {
        IFS=$'\n'
        _arguments \
            '1:mark:($(cut -d, -f2 "$APPARIXRC" "$APPARIXEXPAND"))' \
            '2:file:_path_files -/W "$(apparish "$words[2]" 2>/dev/null)"'
    }

    compdef _apparix_file "${APPARIX_FILE_FUNCTIONS[@]}"
    compdef _apparix_directory "${APPARIX_DIR_FUNCTIONS[@]}"
else
    >&2 echo "Aparix: I do not know how to generate completions"
fi

# shellcheck: Ignore errors about
# - testing $?, because that's useful when you have branches
# - declaring and assigning at the same time just because
# - unexpanded substitutions in single quotes for similar reasons
