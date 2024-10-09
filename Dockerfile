FROM ubuntu:oracular

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y \
    gpg debmake debhelper devscripts equivs \
    distro-info-data distro-info software-properties-common git-buildpackage

COPY entrypoint.sh /entrypoint.sh
COPY build.sh /build.sh

ENTRYPOINT ["/entrypoint.sh"]
