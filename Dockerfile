FROM ubuntu:14.04
MAINTAINER Open State Foundation <developers@openstate.eu>

# Use bash as default shell
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Add multiverse to sources
RUN echo 'deb http://archive.ubuntu.com/ubuntu/ trusty multiverse' >> etc/apt/sources.list

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

#Set Timezone
RUN echo "Europe/Amsterdam" > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata

RUN apt-get update \
    && apt-get install -y \
        python-dev \
        python-setuptools \
        python-software-properties \
        openjdk-7-jre-headless \
        wget \
        curl \
        poppler-utils \
        software-properties-common \
        autoconf \
        automake \
        libtool \
        gettext \
        git \
        dnsutils \
        inotify-tools \
        vim

RUN locale-gen nl_NL.UTF-8
RUN update-locale

RUN add-apt-repository ppa:mc3man/trusty-media \
    && apt-get update \
    && apt-get dist-upgrade -y

RUN apt-get install -y \
        make \
        libxml2-dev \
        libxslt1-dev \
        libssl-dev \
        libffi-dev \
        libtiff4-dev \
        libjpeg8-dev \
        liblcms2-dev \
        python-virtualenv \
        supervisor

RUN pip install --upgrade pip

##### Install dependencies for pyav #####
RUN apt-get update \
    && apt-get install -y \
        libfaac-dev \
        libgpac-dev \
        checkinstall \
        libmp3lame-dev \
        libopencore-amrnb-dev \
        libopencore-amrwb-dev \
        librtmp-dev \
        libtheora-dev \
        libvorbis-dev \
        libx264-dev \
        libfdk-aac-dev \
        libvpx-dev \
        libxvidcore-dev \
        pkg-config \
        yasm \
        zlib1g-dev \
        libavformat-dev \
        libavcodec-dev \
        libavdevice-dev \
        libavutil-dev \
        libswscale-dev \
        libavresample-dev \
        libfontconfig1-dev \
        libjpeg-dev \
        libopenjpeg-dev \
        libmagic-dev

# Temporarily use /tmp as workdir for the pyav dependencies
# WORKDIR /tmp

RUN apt-get install -y ffmpeg

##########

WORKDIR /opt/oaa
# Create a virtualenv project
RUN echo 'ok'
RUN virtualenv -q /opt
RUN echo "source /opt/bin/activate; cd /opt/oaa;" >> /etc/profile

# Temporarily add all oaa API files on the host to the container
# as it contains files needed to finish the base installation
ADD . /opt/oaa

# Install Python requirements
COPY ocd_backend/requirements.txt /opt/oaa/requirements.txt
RUN source /opt/bin/activate \
    && pip install pycparser==2.13 \
    && pip install Cython==0.21.2 \
    && pip install -r requirements.txt

# Install poppler for pdfparser
RUN git clone --depth 1 git://git.freedesktop.org/git/poppler/poppler /tmp/poppler
RUN git clone https://github.com/izderadicka/pdfparser.git /tmp/pdfparser
WORKDIR /tmp/poppler/
RUN ./autogen.sh \
  && ./configure --disable-poppler-qt4 --disable-poppler-qt5 --disable-poppler-cpp --disable-gtk-test --disable-splash-output --disable-utils \
  && make \
  && make install

# Install pdfparser
WORKDIR /tmp/pdfparser/
RUN ldconfig /tmp/pdfparser \
  && source /opt/bin/activate \
  && POPPLER_ROOT=/tmp/poppler python setup.py install

RUN apt-get install supervisor


# Install Docsplit dependencies
RUN apt-get install -y ruby ruby-dev tesseract-ocr tesseract-ocr-eng tesseract-ocr-nld graphicsmagick ImageMagick poppler-utils poppler-data ghostscript pdftk

RUN gem install docsplit

# Delete all oaa API files again
RUN find . -delete
RUN rm -rf /tmp/pdfparser /tmp/poppler

# When the container is created or started run start.sh which starts
# all required services and supervisor which starts celery and celerycam
# Setup Celery
RUN adduser --disabled-password celery \
  && mkdir -p /var/run/celery \
  && chown celery:celery /var/run/celery
USER celery
WORKDIR /opt/oaa/
CMD source /opt/bin/activate && /opt/bin/celery --app=ocd_backend:celery_app worker --loglevel=info --concurrency=1
