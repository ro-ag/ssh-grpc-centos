FROM centos:8

ARG       MAKE_J=6
ARG   GO_VERSION=1.14.3
ARG GRPC_VERSION=1.28.1

# GRPC for GO tracing
ARG LOG_VERBOSITY_LEVEL=99
ARG LOG_SEVERITY_LEVEL=info
ENV GRPC_GO_LOG_VERBOSITY_LEVEL=${LOG_VERBOSITY_LEVEL}
ENV GRPC_GO_LOG_SEVERITY_LEVEL=${LOG_SEVERITY_LEVEL}

# GRPC C
ARG C_GRPC_VERBOSITY=info
ARG C_GRPC_TRACE=api
ENV GRPC_VERBOSITY=${C_GRPC_VERBOSITY}
ENV GRPC_TRACE=${C_GRPC_TRACE}


ENV PACKAGE_SET="gcc-toolset-9 cmake autoconf automake bzip2 wget git nano zlib lzo-devel libfastjson"
RUN yum update -y
RUN yum install -y --setopt=tsflags=nodocs ${PACKAGE_SET}
RUN rpm -V $PACKAGE_SET 
RUN yum install -y --setopt=tsflags=nodocs cpan python3 vim vi 
RUN yum clean all

# Install Go

RUN cd /tmp && \
    wget -nv https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -xvf go${GO_VERSION}.linux-amd64.tar.gz && \
    mv go /usr/local

ENV GOROOT=/usr/local/go
ENV GOPATH=${HOME}/go
ENV GOBIN=${GOPATH}/bin
ENV PATH=${GOPATH}/bin:${GOROOT}/bin:{$PATH}
RUN go version
RUN go get -u \
    google.golang.org/grpc \
    github.com/golang/protobuf/protoc-gen-go \
    github.com/go-delve/delve/cmd/dlv \
    github.com/stretchr/testify \
    go.mongodb.org/mongo-driver/mongo \
    github.com/gorilla/mux

# Go Dev Tools for VS code
RUN go get -u \
    github.com/mdempsky/gocode \
    github.com/uudashr/gopkgs/v2/cmd/gopkgs \
    github.com/sqs/goreturns \
    github.com/pborman/getopt \
    github.com/rogpeppe/godef

# GRPC C++
ENV GRPC_DIR=/usr/local/grpc
ENV PATH=${GRPC_DIR}:${GRPC_DIR}/bin:${PATH}
RUN mkdir -p ${GRPC_DIR};
RUN git clone --recurse-submodules -b v${GRPC_VERSION} https://github.com/grpc/grpc
RUN cd grpc \
    && mkdir -p cmake/build \
    && pushd cmake/build \
    && scl enable gcc-toolset-9 'cmake -DgRPC_INSTALL=ON -DgRPC_BUILD_TESTS=OFF -DCMAKE_INSTALL_PREFIX=${GRPC_DIR} ../..' \
    && scl enable gcc-toolset-9 'make -j ${MAKE_J}'\
    && scl enable gcc-toolset-9 'make install'  \
    && popd
# Clean
RUN rm -rf grpc

# GRPC python and protobuf

RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install grpcio grpcio-tools protobuf

# SSH configuration
RUN yum install -y openssh-server passwd sudo; yum clean all
RUN /usr/bin/ssh-keygen -A
RUN mkdir -p /var/run/sshd \
  && sed -i "s/UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g"  /etc/ssh/sshd_config \
  && sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
  && touch /root/.Xauthority \
  && true

# Addd docker user
RUN useradd docker \
        && passwd -d docker \
        && mkdir -p /home/docker \
        && chown docker:docker /home/docker \
        && usermod -aG wheel docker \
        && true

# Default Command 
COPY run.sh /usr/bin/run.sh
RUN chmod +x /usr/bin/run.sh

# Set root password
COPY set_root_pw.sh /usr/bin/set_root_pw.sh
RUN chmod +x /usr/bin/set_root_pw.sh


EXPOSE 22

# Add Environment Variables and SCL for gcc
RUN echo "export GRPC_DIR=${GRPC_DIR}" >> /etc/profile.d/go_path.sh
RUN echo "export GOROOT=${GOROOT}"  >> /etc/profile.d/go_path.sh
RUN echo "export GOPATH=${GOPATH}"  >> /etc/profile.d/go_path.sh
RUN echo "export GOBIN=${GOBIN}"    >> /etc/profile.d/go_path.sh
RUN echo "export PATH=${GOPATH}/bin:${GOROOT}/bin:$PATH" >> /etc/profile.d/go_path.sh
RUN echo 'source /opt/rh/gcc-toolset-9/enable' >> /etc/profile.d/go_path.sh
RUN chmod +x /etc/profile.d/go_path.sh ; rm /run/nologin 

CMD ["/usr/bin/run.sh"]