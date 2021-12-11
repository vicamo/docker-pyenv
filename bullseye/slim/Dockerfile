#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM debian:bullseye-slim AS base

ENV PYENV_ROOT="/opt/pyenv"
ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:$PATH"

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# runtime dependencies
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update --quiet; \
    apt-get install --yes --no-install-recommends \
        bzip2 \
        ca-certificates \
        curl \
        git \
        libexpat1 \
        $(apt-cache search --names-only 'libffi[0-9]+$' 2>/dev/null | awk '{print $1}') \
        $(apt-cache search --names-only 'libmpdec[0-9]+$' 2>/dev/null | awk '{print $1}') \
        libncursesw5 \
        $(apt-cache show libncursesw6 >/dev/null 2>&1 && echo libncursesw6 || true) \
        $(apt-cache search --names-only 'libreadline[0-9]+$' 2>/dev/null | awk '{print $1}') \
        libsqlite3-0 \
        libssl1.1 \
        lzma \
        zlib1g \
    ; \
    rm -rf /var/lib/apt/lists/*_dists_*

RUN set -eux; \
    curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash; \
    git clone https://github.com/momo-lab/xxenv-latest \
        ${PYENV_ROOT}/plugins/xxenv-latest \
    ; \
    pyenv update

# > =============================================================== <

FROM base AS builder

# runtime dependencies
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update --quiet; \
    apt-get install --yes --no-install-recommends \
        build-essential \
        gdb \
        lcov \
        libbz2-dev \
        libffi-dev \
        libgdbm-compat-dev \
        libgdbm-dev \
        libmpdec-dev \
        liblzma-dev \
        libncursesw5-dev \
        $(apt-cache show libncurses-dev >/dev/null 2>&1 && echo libncurses-dev || true) \
        libreadline6-dev \
        libsqlite3-dev \
        libssl-dev \
        lzma \
        lzma-dev \
        pkg-config \
        tk-dev \
        uuid-dev \
        zlib1g-dev \
    ; \
    rm -rf /var/lib/apt/lists/*_dists_*

# > =============================================================== <

FROM builder AS build-all

ARG PYENV_VERSIONS="2.1.3 2.2.3 2.3.7 2.4.6 2.7.18 3.5.10 3.6.15 3.7.12 3.8.12 3.9.9 3.10.1"
ARG ALLOW_FAILURES=

RUN set -eux; \
    for version in ${PYENV_VERSIONS}; do \
        env PYTHON_CONFIGURE_OPTS=" \
            --enable-shared \
            --enable-loadable-sqlite-extensions \
            --with-lto \
            --with-system-expat \
            --with-system-ffi \
            --with-system-mpdec \
            " \
            pyenv latest install ${version} || test -n "${ALLOW_FAILURES}"; \
    done; \
    pyenv global $(pyenv versions --bare | tac); \
    pyenv versions; \
    \
    find ${PYENV_ROOT}/versions -depth \
        \( \
            \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
            -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \
            -o \( -type f -a -name 'wininst-*.exe' \) \
        \) -exec rm -rf '{}' +

# > =============================================================== <

FROM base

COPY --from=build-all ${PYENV_ROOT}/versions/ ${PYENV_ROOT}/versions/

RUN set -eux; \
    pyenv rehash; \
    pyenv global $(pyenv versions --bare | tac); \
    pyenv versions
