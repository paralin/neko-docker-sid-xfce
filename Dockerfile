# docker build -t paralin/neko-xfce:latest .
ARG BASE_IMAGE=debian:sid
FROM $BASE_IMAGE AS runtime

#
# set custom user
ARG USERNAME=neko
ARG USER_UID=1000
ARG USER_GID=$USER_UID

#
# install dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        wget ca-certificates python3 supervisor \
        pulseaudio dbus-x11 xserver-xorg-video-dummy \
        libcairo2 libxcb1 libxrandr2 libxv1 libopus0 libvpx-dev libxcvt0 \
        #
        # needed for profile upload preStop hook
        zip curl \
        #
        # file chooser handler, clipboard, drop
        xdotool xclip libgtk-3-0 \
        #
        # gst
        gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
        gstreamer1.0-pulseaudio; \
    groupadd --gid $USER_GID $USERNAME; \
    useradd --uid $USER_UID --gid $USERNAME --shell /bin/bash --create-home $USERNAME; \
    adduser $USERNAME audio; \
    adduser $USERNAME video; \
    adduser $USERNAME pulse; \
    #
    # workaround for an X11 problem: http://blog.tigerteufel.de/?p=476
    mkdir /tmp/.X11-unix; \
    chmod 1777 /tmp/.X11-unix; \
    chown $USERNAME /tmp/.X11-unix/; \
    #
    # make directories for neko
    mkdir -p /etc/neko /var/www /var/log/neko \
        /tmp/runtime-$USERNAME \
        /home/$USERNAME/.config/pulse  \
        /home/$USERNAME/.local/share/xorg; \
    chmod 1777 /var/log/neko; \
    chown $USERNAME /var/log/neko/ /tmp/runtime-$USERNAME; \
    chown -R $USERNAME:$USERNAME /home/$USERNAME; \
    #
    # install fonts
    apt-get install -y --no-install-recommends \
        # Emojis
        fonts-noto-color-emoji \
        # Chinese fonts
        fonts-arphic-ukai fonts-arphic-uming \
        fonts-wqy-zenhei xfonts-intl-chinese xfonts-wqy \
        # Japanese fonts
        fonts-ipafont-mincho fonts-ipafont-gothic \
        fonts-takao-mincho \
        # Korean fonts
        fonts-unfonts-core \
        fonts-wqy-microhei \
        # Indian fonts
        fonts-indic; \
    #
    # clean up
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

#
# copy runtime configs
COPY --chown=neko:neko .Xresources /home/$USERNAME/.Xresources
COPY dbus /usr/bin/dbus
COPY default.pa /etc/pulse/default.pa
COPY supervisord.conf /etc/neko/supervisord.conf
COPY supervisord.dbus.conf /etc/neko/supervisord.dbus.conf
COPY xorg.conf /etc/neko/xorg.conf

#
# copy runtime folders
COPY --chown=neko:neko icon-theme /home/$USERNAME/.icons/default
COPY fontconfig/* /etc/fonts/conf.d/
COPY fonts /usr/local/share/fonts

#
# set default envs
ENV USER=$USERNAME
ENV DISPLAY=:99.0
ENV PULSE_SERVER=unix:/tmp/pulseaudio.socket
ENV XDG_RUNTIME_DIR=/tmp/runtime-$USERNAME
ENV NEKO_SERVER_BIND=:8080
ENV NEKO_PLUGINS_ENABLED=true
ENV NEKO_PLUGINS_DIR=/etc/neko/plugins/

#
# add healthcheck
HEALTHCHECK --interval=10s --timeout=5s --retries=8 \
    CMD wget -O - http://localhost:${NEKO_SERVER_BIND#*:}/health || \
        wget --no-check-certificate -O - https://localhost:${NEKO_SERVER_BIND#*:}/health || \
        exit 1

#
# run neko
CMD ["/usr/bin/supervisord", "-c", "/etc/neko/supervisord.conf"]

#
# install xfce
RUN set -eux; apt-get update; \
    apt-get install -y --no-install-recommends xfce4 xfce4-terminal sudo; \
    #
    # add user to sudoers
    usermod -aG sudo neko; \
    echo "neko:neko" | chpasswd; \
    echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; \
    # clean up
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

#
# copy configuation files
COPY supervisord.conf /etc/neko/supervisord/xfce.conf

