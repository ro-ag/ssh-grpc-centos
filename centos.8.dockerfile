FROM centos:8

ARG       MAKE_J=6
ARG   GO_VERSION=1.16.3
ARG GRPC_VERSION=1.28.1

ENV PACKAGE_SET="gcc-toolset-9 autoconf automake bzip2 wget git nano zlib lzo-devel libfastjson"
RUN yum update -y
RUN yum install -y --setopt=tsflags=nodocs ${PACKAGE_SET}
RUN rpm -V $PACKAGE_SET 
RUN yum install -y --setopt=tsflags=nodocs cpan python3 vim vi 
RUN yum clean all

# Install CMAKE - Higher vesrion is not available with YUM 

WORKDIR /tmp

ARG CMAKE_DIR=/usr
RUN source /opt/rh/gcc-toolset-9/enable \
    && mkdir -p ${CMAKE_DIR} \
    && wget -q -O cmake-linux.sh https://github.com/Kitware/CMake/releases/download/v3.17.3/cmake-3.17.3-Linux-x86_64.sh \
    && sh cmake-linux.sh --skip-license --prefix=${CMAKE_DIR} \
    && rm cmake-linux.sh

RUN cmake --version

# Install Go

RUN wget -nv https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && \
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

RUN gcc --version
ENV GRPC_DIR=/usr/local/grpc
ENV PATH=${GRPC_DIR}:${GRPC_DIR}/bin:${PATH}
RUN mkdir -p ${GRPC_DIR};
RUN git clone --recurse-submodules -b v${GRPC_VERSION} https://github.com/grpc/grpc
RUN source /opt/rh/gcc-toolset-9/enable \
    && gcc --version \
    && cd grpc \
    && mkdir -p cmake/build \
    && pushd cmake/build \
    && cmake -DgRPC_INSTALL=ON -DgRPC_BUILD_TESTS=OFF -DCMAKE_INSTALL_PREFIX=${GRPC_DIR} ../.. \
    && make -j ${MAKE_J} \
    && make install  \
    && popd

# GRPC python and protobuf

RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install grpcio grpcio-tools protobuf pandas

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

# Cleanning UP

RUN rm -rf /tmp/*

CMD ["/usr/bin/run.sh"]
