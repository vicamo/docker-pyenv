#!/usr/bin/env bash
set -Eeuo pipefail
#set -x

declare -A aliases=(
    [2.7]='2'
    [3.10]='3 latest'
)

defaultDebianSuite='bullseye'
declare -A debianSuites=(
    #[3.10]='bullseye'
)

self="$(basename "${BASH_SOURCE[0]}")"
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

versions=( $(
    find -name Dockerfile -exec grep -e '^ARG PYENV_VERSIONS=' {} + | \
        cut -d\" -f2 | \
        tr ' ' '\n' | \
        sort -u -V
    )
)

# get the most recent commit which modified any of "$@"
fileCommit() {
    git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
    local dir="$1"; shift
    (
        cd "$dir"
        fileCommit \
            Dockerfile \
            $(git show HEAD:./Dockerfile | awk '
                toupper($1) == "COPY" {
                    for (i = 2; i < NF; i++) {
                        print $i
                    }
                }
            ')
    )
}

getArches() {
    local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

    eval "declare -g -A parentRepoToArches=( $(
        find -name 'Dockerfile' -exec awk '
                toupper($1) == "FROM" && $2 !~ /^(base|build|builder)(:|$)/ {
                    print "'"$officialImagesUrl"'" $2
                }
            ' '{}' + \
            | sort -u \
            | xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
    ) )"
}
getArches

cat <<-EOH
# this file is generated via https://github.com/vicamo/docker-pyenv/blob/$(fileCommit "$self")/$self

Maintainers: You-Sheng Yang <vicamo@gmail.com> (@vicamo)
GitRepo: https://github.com/vicamo/docker-pyenv.git
EOH

# prints "$2$1$3$1...$N"
join() {
    local sep="$1"; shift
    local out; printf -v out "${sep//%/%%}%s" "$@"
    echo "${out#$sep}"
}

for dir in \
    {bullseye,buster,bionic,focal}{,/slim} \
; do
    variant="$(basename "$dir")"

    if [ "$variant" = 'slim' ]; then
        # convert "slim" into "slim-jessie"
        # https://github.com/docker-library/ruby/pull/142#issuecomment-320012893
        variant="$variant-$(basename "$(dirname "$dir")")"
    fi

    [ -f "$dir/Dockerfile" ] || continue

    commit="$(dirCommit "$dir")"

    versionAliases=()
    for fullVersion in "${versions[@]}"; do
        version=${fullVersion%.*}
        versionAliases+=( $fullVersion $version ${aliases[$version]:-} )
    done

    # slim-bullseye
    variantAliases=( "$variant" )

    # 3.10.1-slim-bullseye, 3.10-slim-bullseye, latest-slim-bullseye, etc.
    variantAliases+=( "${versionAliases[@]/%/-$variant}" )

    # 3.10.1-slim, 3.10-slim, latest-slim, slim, etc.
    debianSuite="${debianSuites[$version]:-$defaultDebianSuite}"
    case "$variant" in
    *-"$debianSuite") # "slim-bullseye", etc need "slim"
        variantAliases+=(
            "${variant%-$debianSuite}"
            "${versionAliases[@]/%/-${variant%-$debianSuite}}"
        )
        ;;
    esac

    case "$dir" in
    *)
        variantParent="$(awk 'toupper($1) == "FROM" && $2 !~ /^(base|build|builder)(:|$)/ { print $2 }' "$dir/Dockerfile")"
        variantArches="${parentRepoToArches[$variantParent]}"
        ;;
    esac

    sharedTags=()
    if [ "$variant" = "$debianSuite" ]; then
        sharedTags+=( "${versionAliases[@]}" )
    fi

    echo
    echo "Tags: $(join ', ' "${variantAliases[@]}")"
    if [ "${#sharedTags[@]}" -gt 0 ]; then
        echo "SharedTags: $(join ', ' "${sharedTags[@]}")"
    fi
    cat <<-EOE
	Architectures: $(join ', ' $variantArches)
	GitCommit: $commit
	Directory: $dir
	EOE
done
