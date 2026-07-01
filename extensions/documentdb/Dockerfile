# syntax=docker/dockerfile:1
ARG PG_MAJOR=17
ARG PG_TAG=${PG_MAJOR}

FROM postgres:${PG_TAG} AS builder
ARG PG_MAJOR
ARG EXT_VERSION=v0.113-0

# Install system build dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    build-essential git ca-certificates cmake pkg-config curl \
    libcurl4-openssl-dev libssl-dev liblz4-dev libzstd-dev \
    libicu-dev libxml2-dev libtool \
    postgresql-server-dev-${PG_MAJOR} \
    postgresql-${PG_MAJOR}-cron \
    postgresql-${PG_MAJOR}-rum

# Build and install libbson (mongo-c-driver) from source
ARG LIBBSON_VERSION=1.28.0
RUN curl -fsSL "https://github.com/mongodb/mongo-c-driver/releases/download/${LIBBSON_VERSION}/mongo-c-driver-${LIBBSON_VERSION}.tar.gz" \
    | tar xz -C /tmp \
    && cd /tmp/mongo-c-driver-${LIBBSON_VERSION}/build \
    && cmake -DENABLE_MONGOC=ON -DMONGOC_ENABLE_ICU=OFF -DENABLE_ICU=OFF \
       -DCMAKE_C_FLAGS="-fPIC -g" -DCMAKE_BUILD_TYPE=Release \
       -DCMAKE_INSTALL_PREFIX=/usr .. \
    && make -j"$(nproc)" install \
    && rm -rf /tmp/mongo-c-driver-${LIBBSON_VERSION}

# Build and install Intel Decimal Math Library from source
ARG INTEL_MATH_VERSION=applied/2.0u3-1
RUN mkdir -p /tmp/intelmathlib && cd /tmp/intelmathlib \
    && git init && git remote add origin https://git.launchpad.net/ubuntu/+source/intelrdfpmath \
    && git fetch --depth 1 origin "${INTEL_MATH_VERSION}" && git checkout FETCH_HEAD \
    && cd LIBRARY \
    && make -j"$(nproc)" _CFLAGS_OPT=-fPIC CC=gcc CALL_BY_REF=0 GLOBAL_RND=0 GLOBAL_FLAGS=0 UNCHANGED_BINARY_FLAGS=0 \
    && mkdir -p /usr/lib/intelmathlib/LIBRARY \
    && cp -a libbid.a src /usr/lib/intelmathlib/LIBRARY/ \
    && PKG_DIR=$(pkg-config --variable=pc_path pkg-config | cut -d: -f1) \
    && mkdir -p "$PKG_DIR" \
    && { echo 'prefix=/usr/lib/intelmathlib'; \
         echo 'libdir=${prefix}/LIBRARY'; \
         echo 'includedir=${prefix}/LIBRARY/src'; \
         echo ''; \
         echo 'Name: intelmathlib'; \
         echo 'Description: Intel Decimal Floating point math library'; \
         echo 'Version: 2.0 Update 2'; \
         echo 'Cflags: -I${includedir}'; \
         echo 'Libs: -L${libdir} -lbid'; \
       } > "$PKG_DIR/intelmathlib.pc" \
    && rm -rf /tmp/intelmathlib

# Build and install PCRE2 from source (static with JIT)
ARG PCRE2_VERSION=10.40
RUN curl -fsSL "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.gz" \
    | tar xz -C /tmp \
    && cd /tmp/pcre2-${PCRE2_VERSION} \
    && ./configure --prefix=/usr --disable-shared --enable-static --enable-jit \
    && make -j"$(nproc)" AM_CFLAGS=-fPIC \
       pkgconfigdir="$(pkg-config --variable=pc_path pkg-config | cut -d: -f1)" install \
    && rm -rf /tmp/pcre2-${PCRE2_VERSION}

# Clone DocumentDB
RUN git clone --branch ${EXT_VERSION} --depth 1 \
    https://github.com/documentdb/documentdb.git /tmp/ext

WORKDIR /tmp/ext

# Build and install DocumentDB extensions
RUN make -j"$(nproc)" && make install DESTDIR=/output \
    && find /output -name '*.so' -exec strip --strip-unneeded {} \;

# Install Rust toolchain and build the gateway (pg_documentdb_gw)
ARG RUST_VERSION=1.92.0
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain ${RUST_VERSION} --profile minimal \
    && cargo install --locked cargo-pgrx@0.16.0 \
    && cargo pgrx init --pg${PG_MAJOR} "$(which pg_config)"

RUN cd /tmp/ext/pg_documentdb_gw_host \
    && cargo pgrx install --pg-config "$(which pg_config)" \
       --features "pg${PG_MAJOR}" --release \
    && cp -a $(pg_config --pkglibdir)/pg_documentdb_gw_host.so /output$(pg_config --pkglibdir)/ \
    && cp -a $(pg_config --sharedir)/extension/pg_documentdb_gw_host* /output$(pg_config --sharedir)/extension/ \
    && find /output -name 'pg_documentdb_gw_host.so' -exec strip --strip-unneeded {} \;

# Remove dependency artifacts (provided by separate layers)
RUN find /output -path '*pg_cron*' -delete \
    && find /output -path '*rum*' ! -path '*documentdb*' -delete

FROM scratch
COPY --from=builder /output/ /
