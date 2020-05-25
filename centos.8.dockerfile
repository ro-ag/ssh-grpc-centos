FROM centos:8

ARG       MAKE_J=6
ARG   GO_VERSION=1.14.3
ARG GRPC_VERSION=1.28.1

RUN yum update -y
RUN yum install -y gcc-toolset-9 cmake autoconf automake
RUN yum install -y bzip2 wget git cpan nano vim vi python3 zlib lzo-devel libfastjson
RUN yum clean all

RUN \
    cd /tmp && \
    wget -nv https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -xvf go${GO_VERSION}.linux-amd64.tar.gz && \
    mv go /usr/local

ENV GOROOT=/usr/local/go
ENV GOPATH=${HOME}/go
ENV GOBIN=${GOPATH}/bin
ENV PATH=${GOPATH}/bin:${GOROOT}/bin:{$PATH}
RUN go version
RUN go get -u -v \
    google.golang.org/grpc \
    github.com/golang/protobuf/protoc-gen-go \
    github.com/go-delve/delve/cmd/dlv \
    github.com/stretchr/testify \
    go.mongodb.org/mongo-driver/mongo \
    github.com/gorilla/mux

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

# GRPC python
RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install grpcio
RUN python3 -m pip install grpcio-tools
RUN python3 -m pip install protobuf

# Enable GCC-9 by default
RUN yum install -y openssh-server passwd sudo; yum clean all
RUN /usr/bin/ssh-keygen -A
RUN mkdir -p /var/run/sshd \
  && sed -i "s/UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g"  /etc/ssh/sshd_config \
  && sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
  && touch /root/.Xauthority \
  && true

RUN useradd docker \
        && passwd -d docker \
        && mkdir -p /home/docker \
        && chown docker:docker /home/docker \
        && usermod -aG wheel docker \
        && true

# Persistent gcc-toolset-9

#RUN ls /etc/profile.d
COPY entrypoint.sh  /etc/profile.d/enable_gcc.sh
RUN chmod +x /etc/profile.d/enable_gcc.sh ; rm /run/nologin 
#RUN ls  /etc/profile.d

# External Commands
COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

COPY run.sh /usr/bin/run.sh
RUN chmod +x /usr/bin/run.sh

COPY set_root_pw.sh /usr/bin/set_root_pw.sh
RUN chmod +x /usr/bin/set_root_pw.sh

EXPOSE 22

ENTRYPOINT [ "/usr/bin/entrypoint.sh" ]
CMD ["/usr/bin/run.sh"]