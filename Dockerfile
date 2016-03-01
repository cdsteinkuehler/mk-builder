FROM machinekit/mk-builder:base
MAINTAINER GP Orcullo <kinsamanka@gmail.com>
#
# These variables configure the build.
#
ENV SUITE jessie
ENV ARCH  i386
#
# [Leave surrounding comments to eliminate merge conflicts]
#

ENV PROOT_OPTS "-b /dev/urandom"

# create chroot
ADD wheezy.conf jessie.conf raspbian.conf /
RUN multistrap -f /${SUITE}.conf -a ${ARCH} -d ${ROOTFS} && \
    proot-helper /var/lib/dpkg/info/dash.preinst install && \
    proot-helper dpkg --configure -a

ENV PROOT_OPTS "-b /dev/pts -b /dev/shm -b /dev/urandom"

# mk_depends lists deps independent of $SUITE and $ARCH
ADD mk_depends ${ROOTFS}/tmp/

# copy arm-linux-gnueabihf-* last to clobber package installs
ADD bin/* ${ROOTFS}/tmp/

# fix resolv.conf
# 3rd-party MK deps repo
# install MK dependencies
# cython package is in backports on Wheezy
# tcl/tk latest is v. 8.5 in Wheezy
# cleanup apt
# use modified arm-linux-gnueabihf-* if running on wheezy
# else use native arm-linux-gnueabihf-* 
# cleanup
# update ccache symlinks

RUN echo "nameserver 8.8.8.8\nnameserver 8.8.4.4" \
        > ${ROOTFS}/etc/resolv.conf && \
    proot-helper apt-key adv --keyserver hkp://keys.gnupg.net \
        --recv-key 43DDF224 && \
    echo "deb http://deb.machinekit.io/debian ${SUITE} main" \
         > ${ROOTFS}/etc/apt/sources.list.d/machinekit.list && \
    proot-helper apt-get update && \
    proot-helper xargs -a /tmp/mk_depends apt-get install -y && \
    rm ${ROOTFS}/tmp/mk_depends && \
    (test $SUITE = wheezy \
        && proot-helper apt-get install -y -t wheezy-backports cython \
        || proot-helper apt-get install -y cython) && \
    (test $SUITE = wheezy \
        && proot-helper apt-get install -y tcl8.5-dev tk8.5-dev \
        || proot-helper apt-get install -y tcl8.6-dev tk8.6-dev) && \
    proot-helper apt-get clean && \
    (rm -f /var/lib/apt/lists/* ${ROOTFS}/var/lib/apt/lists/* || true) && \
    (test $ARCH = armhf && test $SUITE = wheezy \
        && cp ${ROOTFS}/tmp/arm-* ${ROOTFS}/usr/bin/ \
        || true) && \
    (test $ARCH = armhf && test $SUITE != wheezy \
        && proot-helper sh -c '\
            for a in $(ls /host-rootfs/usr/bin/arm-linux-gnueabihf-*); \
            do \
                ln -sf $a /usr/bin; \
            done' \
        || true) && \
    rm ${ROOTFS}/tmp/* wheezy.conf jessie.conf raspbian.conf && \
    proot-helper dpkg-reconfigure ccache
