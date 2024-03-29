ARG FEDORA_VERSION=latest

FROM quay.io/fedora/fedora-coreos:stable as kernel-query
#We can't use the `uname -r` as it will pick up the host kernel version
RUN rpm -qa kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' > /kernel-version.txt

FROM quay.io/fedora/fedora:${FEDORA_VERSION} as builder
COPY --from=kernel-query /kernel-version.txt /kernel-version.txt
WORKDIR /etc/yum.repos.d
RUN curl -L -O https://src.fedoraproject.org/rpms/fedora-repos/raw/f$(rpm -E %fedora)/f/fedora-updates-archive.repo && \
    sed -i 's/enabled=AUTO_VALUE/enabled=true/' fedora-updates-archive.repo
RUN dnf install -y gcc git make kernel-$(cat /kernel-version.txt) kernel-modules-$(cat /kernel-version.txt) kernel-devel-$(cat /kernel-version.txt)
WORKDIR /
RUN git clone https://github.com/google/gasket-driver.git
WORKDIR /gasket-driver/src
RUN KVERSION="$(cat /kernel-version.txt)" make -e

FROM quay.io/fedora/fedora-coreos:stable
COPY --from=builder /gasket-driver/src/*.ko /
RUN mkdir -p /lib/modules/$(rpm -qa kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')/extra/gasket
RUN mv /*.ko /lib/modules/$(rpm -qa kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')/extra/gasket
RUN depmod $(rpm -qa kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')
RUN ostree container commit
