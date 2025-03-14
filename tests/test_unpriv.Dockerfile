FROM docker.io/library/ubuntu:26.04@sha256:f3d28607ddd78734bb7f71f117f3c6706c666b8b76cbff7c9ff6e5718d46ff64 AS base

RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources

RUN apt-get update

RUN apt-get install -y --no-install-recommends build-essential git flatpak-builder

RUN apt-get build-dep -y --no-install-recommends flatpak

RUN dpkg --purge --force-depends flatpak

RUN rm -rf /var/lib/apt/lists/*

FROM base

COPY . /src

WORKDIR /src

RUN git restore --staged . || true
RUN git restore . || true
RUN git reset --hard HEAD || true
RUN git clean -dfqx || true

RUN meson setup \
      --reconfigure \
      -Dgir=disabled \
      -Dgtkdoc=disabled \
      -Ddocbook_docs=disabled \
      -Dman=disabled \
      -Dmalcontent=disabled \
      -Dseccomp=disabled \
      -Dsystem_helper=disabled \
      -Dselinux_module=disabled \
      -Dwayland_security_context=disabled \
      -Dsandboxed_triggers=false \
      -Dinternal_checks=false \
      -Dinternal_tests=false \
      -Dtests=false \
      -Dsystem_dbus_proxy=xdg-dbus-proxy \
      -Dsystem_install_dir=/var/lib/flatpak \
      builddir && \
    meson compile -C builddir

RUN meson install -C builddir

RUN useradd -m -s /bin/bash appuser

USER appuser
ENV HOME=/home/appuser
WORKDIR /home/appuser

ENTRYPOINT ["/bin/bash"]
