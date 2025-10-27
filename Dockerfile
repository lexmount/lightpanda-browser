# syntax=docker/dockerfile:1
FROM debian:stable

ARG MINISIG=0.12
ARG ZIG=0.15.2
ARG ZIG_MINISIG=RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U
ARG V8=14.0.365.4
ARG ZIG_V8=v0.1.33
ARG TARGETPLATFORM

RUN apt-get update -yq && \
    apt-get install -yq xz-utils \
        python3 ca-certificates git \
        pkg-config libglib2.0-dev \
        gperf libexpat1-dev \
        cmake clang \
        curl git openssh-client

# install minisig
RUN curl --fail -L -O https://github.com/jedisct1/minisign/releases/download/${MINISIG}/minisign-${MINISIG}-linux.tar.gz && \
    tar xvzf minisign-${MINISIG}-linux.tar.gz

# install zig
RUN case $TARGETPLATFORM in \
    "linux/arm64") ARCH="aarch64" ;; \
    *) ARCH="x86_64" ;; \
    esac && \
    curl --fail -L -O https://ziglang.org/download/${ZIG}/zig-${ARCH}-linux-${ZIG}.tar.xz && \
    curl --fail -L -O https://ziglang.org/download/${ZIG}/zig-${ARCH}-linux-${ZIG}.tar.xz.minisig && \
    minisign-linux/${ARCH}/minisign -Vm zig-${ARCH}-linux-${ZIG}.tar.xz -P ${ZIG_MINISIG} && \
    tar xvf zig-${ARCH}-linux-${ZIG}.tar.xz && \
    mv zig-${ARCH}-linux-${ZIG} /usr/local/lib && \
    ln -s /usr/local/lib/zig-${ARCH}-linux-${ZIG}/zig /usr/local/bin/zig

# clone lightpanda
RUN --mount=type=ssh \
    mkdir -p -m 0700 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git clone git@github.com:lexmount/lightpanda-browser.git

WORKDIR /lightpanda-browser

# install deps
RUN git submodule init && \
    git submodule update --recursive

# Build dependencies with baseline compatibility
RUN CFLAGS="-O2" CXXFLAGS="-O2" make install-libiconv && \
    CFLAGS="-O2" CXXFLAGS="-O2" make install-netsurf && \
    CFLAGS="-O2" CXXFLAGS="-O2" make install-mimalloc

# download and install v8
RUN case $TARGETPLATFORM in \
    "linux/arm64") ARCH="aarch64" ;; \
    *) ARCH="x86_64" ;; \
    esac && \
    curl --fail -L -o libc_v8.a https://github.com/lightpanda-io/zig-v8-fork/releases/download/${ZIG_V8}/libc_v8_${V8}_linux_${ARCH}.a && \
    # mkdir -p v8/out/linux/debug/obj/zig/ && \
    # mv libc_v8.a v8/out/linux/debug/obj/zig/libc_v8.a
    mkdir -p v8/out/linux/release/obj/zig/ && \
    mv libc_v8.a v8/out/linux/release/obj/zig/libc_v8.a
    

# build release with baseline CPU for maximum compatibility
# RUN zig build -Doptimize=ReleaseSafe -Dcpu=baseline -Dgit_commit=$(git rev-parse --short HEAD)
RUN zig build -Doptimize=Debug -Dcpu=baseline -Dgit_commit=$(git rev-parse --short HEAD)

FROM debian:stable-slim

# copy ca certificates
COPY --from=0 /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=0 /lightpanda-browser/zig-out/bin/lightpanda /bin/lightpanda

EXPOSE 9222/tcp

ENV LIGHTPANDA_DISABLE_TELEMETRY=true

RUN apt-get update -yq && \
    apt-get install -yq lldb

CMD ["/bin/lightpanda", "serve", "--host", "0.0.0.0", "--port", "9222", "--log_level", "info"]
