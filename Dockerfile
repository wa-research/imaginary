FROM ubuntu:16.04 as builder
LABEL maintainer damir.simunic@wa-research.ch

ENV LIBVIPS_VERSION 8.6.5

# Installs libvips + required libraries
RUN \
  # Install dependencies
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ca-certificates \
  automake build-essential curl \
  gobject-introspection gtk-doc-tools libglib2.0-dev libjpeg-turbo8-dev libpng12-dev \
  libwebp-dev libtiff5-dev libgif-dev libexif-dev libxml2-dev libpoppler-glib-dev \
  swig libmagickwand-dev libpango1.0-dev libmatio-dev libopenslide-dev libcfitsio-dev \
  libgsf-1-dev fftw3-dev liborc-0.4-dev librsvg2-dev gcc git libc6-dev make && \
  # Build libvips
  cd /tmp && \
  curl -OL https://github.com/libvips/libvips/releases/download/v${LIBVIPS_VERSION}/vips-${LIBVIPS_VERSION}.tar.gz && \
  tar zvxf vips-${LIBVIPS_VERSION}.tar.gz && \
  cd /tmp/vips-${LIBVIPS_VERSION} && \
  ./configure --enable-debug=no --without-python $1 && \
  make && \
  make install && \
  ldconfig

# Go version to use
ENV GOLANG_VERSION 1.10

ENV GOLANG_DOWNLOAD_URL https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz
ENV GOLANG_DOWNLOAD_SHA256 b5a64335f1490277b585832d1f6c7f8c6c11206cba5cd3f771dcb87b98ad1a33

RUN curl -fsSL --insecure "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
  && echo "$GOLANG_DOWNLOAD_SHA256 golang.tar.gz" | sha256sum -c - \
  && tar -C /usr/local -xzf golang.tar.gz \
  && rm golang.tar.gz

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH

# Fetch the latest version of the package
RUN go get -u golang.org/x/net/context
RUN go get -u github.com/golang/dep/cmd/dep

# Copy imaginary sources
COPY . $GOPATH/src/github.com/wa-research/imaginary

# Compile imaginary
RUN go build -o bin/imaginary github.com/wa-research/imaginary

RUN apt-get remove -y curl automake build-essential git && \
  apt-get autoremove -y && \
  apt-get autoclean && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

FROM ubuntu:16.04

RUN \
  # Install runtime dependencies
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
  libglib2.0-0 libjpeg-turbo8 libpng12-0 libopenexr22 \
  libwebp5 libtiff5 libgif7 libexif12 libxml2 libpoppler-glib8 \
  libmagickwand-6.q16-2 libpango1.0-0 libmatio2 libopenslide0 \
  libgsf-1-114 fftw3 liborc-0.4 librsvg2-2 libcfitsio2 && \
  # Clean up
  apt-get autoremove -y && \
  apt-get autoclean && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder /usr/local/lib /usr/local/lib
RUN ldconfig
COPY --from=builder /go/bin/imaginary bin/
COPY --from=builder /etc/ssl/certs /etc/ssl/certs

# Server port to listen
ENV PORT 10001

# Run the entrypoint command by default when the container starts.
ENTRYPOINT ["bin/imaginary"]

# Expose the server TCP port
EXPOSE 10001
