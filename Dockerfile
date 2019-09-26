# -*- mode: conf -*-
FROM ubuntu:xenial
MAINTAINER Nobody

USER root
COPY resources/sources.list.ucsb /etc/apt/sources.list
RUN export DEBIAN_FRONTEND=noninteractive && \
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y virtualenvwrapper python2.7-dev build-essential sudo \
    libxml2-dev libxslt1-dev git libffi-dev cmake libreadline-dev libtool \
    debootstrap debian-archive-keyring libglib2.0-dev libpixman-1-dev \
    libpq-dev python-dev \
    # clang dependencies (for compilerex)
    libc6:i386 libncurses5:i386 libstdc++6:i386 zlib1g:i386 \
    # stuff for the fuzzer
    pkg-config zlib1g-dev libtool libtool-bin wget automake autoconf coreutils bison libacl1-dev \
    # fidget
    qemu-user qemu-kvm socat \
    # other CGC stuff
    postgresql-client nasm binutils-multiarch llvm clang && \
    rm -f /var/cache/apt/archives/*.deb

RUN useradd -s /bin/bash -m angr
RUN echo "workon angr" >> /home/angr/.bashrc
RUN echo "angr ALL=NOPASSWD: ALL" > /etc/sudoers.d/angr
WORKDIR /home/angr

ARG CACHEBUST=

RUN su - angr -c "mkdir ~/.ssh; ssh-keyscan github.com git.seclab.cs.ucsb.edu >> ~/.ssh/known_hosts"
COPY resources/angr_deploy_key /home/angr/.ssh/id_rsa
RUN chown angr.angr /home/angr/.ssh/id_rsa
RUN chmod 600 /home/angr/.ssh/id_rsa

# make the entrypoint actually parse the bashrc
USER angr
ENTRYPOINT ["bash", "-i"]

# first clone, then install (for quicker builds from cache)
ARG EXTRA_REPOS="identifier fidget angrop driller fuzzer tracer compilerex povsim rex farnsworth patcherex colorguard common-utils network_poll_creator ids_rules patch_performance worker meister ambassador scriba"
ARG BRANCH=master
RUN git clone git@git.seclab.cs.ucsb.edu:angr/angr-dev && cd angr-dev
RUN cd angr-dev && git pull && git checkout $BRANCH
RUN angr-dev/setup.sh -C -r git@git.seclab.cs.ucsb.edu:cgc -b $BRANCH $EXTRA_REPOS && rm -rf angr-dev/{unicorn,capstone}
RUN angr-dev/setup.sh -v -i -w -p angr -r git@git.seclab.cs.ucsb.edu:cgc peewee $EXTRA_REPOS && rm -rf wheels

#CMD bash -c "source /etc/bash_completion.d/virtualenvwrapper && workon angr && nice -n 20 worker"
