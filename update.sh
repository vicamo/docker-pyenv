#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

generated_warning() {
    cat <<-EOF
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

EOF
}

versions=(
    $(docker run vicamo/pyenv sh -c " \
        for prefix in \$(pyenv install --list | \
            grep -e '^  [[:digit:]]\(\.[[:digit:]]\+\)\+$' | \
            cut -d. -f1,2 | \
            sort -u -V) \
        ; do \
            pyenv latest -p \$prefix; \
        done | sort -u -V"
    )
)

for dir in \
    {buster,bullseye}{/slim,} \
; do
    variant="$(basename "$dir")"

    [ -d "$dir" ] || continue

    case "$variant" in
    slim)
        template='debian'
        suite=$(basename "$(dirname "$dir")")
        base="debian:$suite-slim"
        ;;
    *)
        template='debian'
        suite="$variant"
        base="buildpack-deps:$variant"
        ;;
    esac
    template="Dockerfile-${template}.template"

    { generated_warning; cat "$template"; } > "$dir/Dockerfile"

    sed -ri \
        -e "s!%%BASE_IMAGE%%!${base}!" \
        -e "s!%%PYENV_VERSIONS%%!${versions[*]}!" \
        "$dir/Dockerfile"
done
