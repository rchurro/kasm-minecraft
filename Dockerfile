# Kasm workspace: Minecraft Java Edition via Prism Launcher.
# Stock kasmweb images drop sudo, so this adds it back (passwordless) to allow
# installing extras in a live session. Sessions are throwaway; persistence comes
# from the workspace's persistent profile path, not the image.
# No Minecraft game files (safe to publish). Dockerfile.baked adds them for private use.
FROM kasmweb/core-ubuntu-noble:1.19.0
USER root

ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
WORKDIR $HOME

ARG PRISM_VERSION=11.1.1

# Java 21 covers 1.20.5–1.21.x, Java 25 covers 26.x; Prism downloads others on demand.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      sudo openjdk-21-jre openjdk-25-jre curl ca-certificates python3 \
      libgl1 libegl1 libglx-mesa0 mesa-utils libopenal1 libpulse0 \
      libxcursor1 libxrandr2 libxi6 libxxf86vm1 \
 && echo 'kasm-user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/kasm-user \
 && chmod 0440 /etc/sudoers.d/kasm-user \
 && rm -rf /var/lib/apt/lists/*

# VirtualGL >= 3.1.5: its EGL back end fixed default-framebuffer handling that
# left Minecraft Java black under vglrun (base image ships 3.1.3).
ARG VGL_VERSION=3.1.5
RUN curl -fsSL -o /tmp/vgl.deb \
      "https://github.com/VirtualGL/virtualgl/releases/download/${VGL_VERSION}/virtualgl_${VGL_VERSION}_amd64.deb" \
 && dpkg -i /tmp/vgl.deb \
 && rm /tmp/vgl.deb

# AppImage extracted so it runs without FUSE inside the container.
RUN cd /opt \
 && curl -fsSL -o prism.AppImage \
      "https://github.com/PrismLauncher/PrismLauncher/releases/download/${PRISM_VERSION}/PrismLauncher-Linux-x86_64.AppImage" \
 && chmod +x prism.AppImage \
 && ./prism.AppImage --appimage-extract >/dev/null \
 && mv squashfs-root prismlauncher \
 && rm prism.AppImage \
 && chmod -R a+rX prismlauncher \
 && ln -s /opt/prismlauncher/AppRun /usr/local/bin/prismlauncher

# Prism config: skip the setup wizard (language, Java, theme) and start the game
# through mc-gpu so it renders on the GPU when Kasm assigns one.
ARG JAVA_PATH=/usr/lib/jvm/java-25-openjdk-amd64/bin/java
COPY mc-gpu /usr/local/bin/mc-gpu
RUN P=$HOME/.local/share/PrismLauncher \
 && mkdir -p $P \
 && printf '[General]\nConfigVersion=1.3\nLanguage=en_US\nApplicationTheme=system\nIconTheme=pe_colored\nJavaPath=%s\nAutomaticJavaSwitch=true\nAutomaticJavaDownload=true\nWrapperCommand=/usr/local/bin/mc-gpu\n' "$JAVA_PATH" > $P/prismlauncher.cfg

COPY custom_startup.sh $STARTUPDIR/custom_startup.sh
COPY prismlauncher.desktop /usr/share/applications/prismlauncher.desktop
RUN chmod 755 $STARTUPDIR/custom_startup.sh

# Single-application mode, as in the stock kasmweb app images: no panel or
# desktop, just the launcher (and the game it starts) full-screen.
RUN cp $HOME/.config/xfce4/xfconf/single-application-xfce-perchannel-xml/* \
       $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/ \
 && cp /usr/share/backgrounds/bg_kasm.png /usr/share/backgrounds/bg_default.png \
 && apt-get remove -y xfce4-panel \
 && rm -rf /var/lib/apt/lists/*

# Standard Kasm image tail: hand the default profile to kasm-user.
RUN chown 1000:0 $HOME \
 && $STARTUPDIR/set_user_permission.sh $HOME \
 && rm -Rf ${INST_DIR:-/dockerstartup/install}

ENV HOME=/home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000
