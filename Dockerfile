FROM jlesage/baseimage-gui:ubuntu-18.04

ENV URL_PICARD_REPO="https://github.com/metabrainz/picard.git" \
    URL_CHROMAPRINT_REPO="https://github.com/acoustid/chromaprint.git" \
    URL_GOOGLETEST_REPO="https://github.com/google/googletest.git"
    
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x && \
    # Define package arrays
    # TEMP_PACKAGES are packages that will only be present in the image during container build
    # KEPT_PACKAGES will remain in the image
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    # Install software-properties-common so we can use add-apt-repository
    TEMP_PACKAGES+=(software-properties-common) && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} \
        && \
    # Install pip to allow install of Picard dependencies
    TEMP_PACKAGES+=(python3-pip) && \
    TEMP_PACKAGES+=(python3-setuptools) && \
    TEMP_PACKAGES+=(python3-wheel) && \
    # Install git to allow clones of git repos
    TEMP_PACKAGES+=(git) && \
    # Install build tools to allow building
    TEMP_PACKAGES+=(build-essential) && \
    TEMP_PACKAGES+=(cmake) && \
    # Install Chromaprint dependencies
    KEPT_PACKAGES+=(ffmpeg) && \
    TEMP_PACKAGES+=(libswresample-dev) && \
    KEPT_PACKAGES+=(libswresample2) && \
    TEMP_PACKAGES+=(libfftw3-dev) && \
    KEPT_PACKAGES+=(libfftw3-3) && \
    TEMP_PACKAGES+=(libavcodec-dev) && \
    KEPT_PACKAGES+=(libavcodec57) && \
    TEMP_PACKAGES+=(libavformat-dev) && \
    KEPT_PACKAGES+=(libavformat57) && \
    # Install Picard dependencies
    TEMP_PACKAGES+=(python3-dev) && \
    TEMP_PACKAGES+=(libdiscid-dev) && \
    KEPT_PACKAGES+=(libdiscid0) && \
    KEPT_PACKAGES+=(libxcb-icccm4) && \
    KEPT_PACKAGES+=(libxcb-keysyms1) && \
    KEPT_PACKAGES+=(libxcb-randr0) && \
    KEPT_PACKAGES+=(libxcb-render-util0) && \
    KEPT_PACKAGES+=(libxcb-xinerama0) && \
    KEPT_PACKAGES+=(libxcb-image0) && \
    KEPT_PACKAGES+=(libxcb-xkb1) && \
    KEPT_PACKAGES+=(libxkbcommon-x11-0) && \
    KEPT_PACKAGES+=(gettext) && \
    KEPT_PACKAGES+=(locales) && \
    KEPT_PACKAGES+=(chromium-browser) && \
    KEPT_PACKAGES+=(fonts-takao) && \
    KEPT_PACKAGES+=(fonts-takao-mincho) && \
    KEPT_PACKAGES+=(wget) && \
    KEPT_PACKAGES+=(ca-certificates) && \
    # Install Picard Media Player dependencies
    KEPT_PACKAGES+=(gstreamer1.0-plugins-good) && \
    KEPT_PACKAGES+=(gstreamer1.0-libav) && \
    KEPT_PACKAGES+=(libpulse-mainloop-glib0) && \
    KEPT_PACKAGES+=(libqt5multimedia5-plugins) && \
    KEPT_PACKATES+=(libavcodec57) && \
    # Install Picard plugin dependencies
    KEPT_PACKAGES+=(python3-aubio) && \
    KEPT_PACKAGES+=(python-aubio) && \
    KEPT_PACKAGES+=(aubio-tools) && \
    KEPT_PACKAGES+=(flac) && \
    KEPT_PACKAGES+=(vorbisgain) && \
    KEPT_PACKAGES+=(wavpack) && \
    add-apt-repository -y ppa:flexiondotorg/audio && \
    KEPT_PACKAGES+=(mp3gain) && \
    # Install packages
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} \
        && \
    git config --global advice.detachedHead false && \
    # Clone googletest (required for build of Chromaprint)
    git clone "$URL_GOOGLETEST_REPO" /src/googletest && \
    pushd /src/googletest && \
    BRANCH_GOOGLETEST=$(git tag --sort="-creatordate" | grep 'release-' | head -1) && \
    git checkout "tags/${BRANCH_GOOGLETEST}" && \
    echo "$BRANCH_GOOGLETEST" >> /VERSIONS && \
    popd && \
    # Clone Chromaprint repo & checkout latest version
    git clone "$URL_CHROMAPRINT_REPO" /src/chromaprint && \
    pushd /src/chromaprint && \
    BRANCH_CHROMAPRINT=$(git tag --sort="-creatordate" | head -1) && \
    git checkout "tags/${BRANCH_CHROMAPRINT}" && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TOOLS=ON \
        -DBUILD_TESTS=ON \
        -DGTEST_SOURCE_DIR=/src/googletest/googletest \
        -DGTEST_INCLUDE_DIR=/src/googletest/googletest/include . \
        && \
    make && \
    make check && \
    make install && \
    echo "$BRANCH_CHROMAPRINT" >> /VERSIONS && \
    popd && \
    # Clone Picard repo & checkout latest version
    git clone "$URL_PICARD_REPO" /src/picard && \
    pushd /src/picard && \
    BRANCH_PICARD=$(git tag --sort="-creatordate" | head -1) && \
    git checkout "tags/${BRANCH_PICARD}" && \
    # Fix for: https://stackoverflow.com/questions/59768179/pip-raise-filenotfounderror-errno-2-no-such-file-or-directory-tmp-pip-inst?noredirect=1&lq=1
    sed -i 's/PyQt5>=5.7.1/PyQt5>=5.11/g' ./requirements.txt && \
    # Install Picard requirements
    pip3 install --upgrade pip && \
    pip3 install -r requirements.txt && \
    pip3 install discid python-libdiscid && \
    locale-gen en_US.UTF-8 && \
    export LC_ALL=C.UTF-8 && \
    # Build & install Picard
    python3 setup.py build && \
    python3 setup.py build_ext -i && \
    python3 setup.py build_locales -i && \
    python3 setup.py test && \
    python3 setup.py install && \
    mkdir -p /tmp/run/user/app && \
    chmod 0700 /tmp/run/user/app && \
    if picard -v 2>&1 | grep -c error; then exit 1; fi && \
    picard -v | cut -d ' ' -f 2- >> /VERSIONS && \
    popd && \
    # Update OpenBox config
    sed -i 's/<application type="normal">/<application type="normal" title="MusicBrainz Picard">/' /etc/xdg/openbox/rc.xml && \
    sed -i '/<decor>no<\/decor>/d' /etc/xdg/openbox/rc.xml && \
    # Update chromium-browser config
    sed -i 's/Exec=chromium-browser/Exec=chromium-browser --no-sandbox/g' /usr/share/applications/chromium-browser.desktop && \
    # Clean-up
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -y && \
    rm -rf /src/* /tmp/* /var/lib/apt/lists/*

COPY startapp.sh /startapp.sh

ENV APP_NAME="MusicBrainz Picard" \
    LC_ALL="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8"
