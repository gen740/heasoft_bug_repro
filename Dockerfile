# Dockerfile for HEASoft bug reproduction (based on official HEASoft Dockerfile)

FROM ubuntu:22.04

ARG version=6.36
ENV HEASOFT_VERSION=${version}

LABEL version="${version}" \
      description="HEASoft ${version} https://heasarc.gsfc.nasa.gov/lheasoft/" \
      maintainer="NASA/GSFC/HEASARC https://heasarc.gsfc.nasa.gov/cgi-bin/ftoolshelp"

# Install HEASoft prerequisites
# (xvfb and gdb added on top of the official list)
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get -y upgrade \
 && apt-get -y install \
    gcc \
    gfortran \
    g++ \
    curl \
    libcurl4 \
    libcurl4-gnutls-dev \
    libncurses5-dev \
    libreadline6-dev \
    libfile-which-perl \
    libdevel-checklib-perl \
    make \
    ncurses-dev \
    perl-modules \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-astropy python3-numpy python3-scipy python3-matplotlib \
    python-is-python3 \
    python3-astroquery \
    python3-pandas \
    python3-pyvo \
    ipython3 \
    saods9 \
    tcsh \
    vim \
    wget \
    lynx \
    xorg-dev \
    xvfb \
    gdb \
 && pip install --upgrade pip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd heasoft && useradd -r -m -g heasoft heasoft \
 && mkdir -p /opt/heasoft/caldb \
 && chown -R heasoft:heasoft /opt/heasoft

# Use the local tarball (the original Dockerfile downloads it with wget)
COPY --chown=heasoft:heasoft heasoft-6.36src.tar.gz /home/heasoft/

USER heasoft
WORKDIR /home/heasoft

# Unpack in a separate layer to make better use of the build cache
RUN echo "Unpacking heasoft-${HEASOFT_VERSION}src.tar.gz..." \
 && tar xzf heasoft-${HEASOFT_VERSION}src.tar.gz \
 && rm -f heasoft-${HEASOFT_VERSION}src.tar.gz

# configure: -D_GLIBCXX_ASSERTIONS enables STL bounds checking, -g adds debug symbols
RUN cd ${HOME}/heasoft-${HEASOFT_VERSION}/BUILD_DIR/ \
 && echo "Configuring heasoft..." \
 && CFLAGS="-g -D_GLIBCXX_ASSERTIONS" \
    CXXFLAGS="-g -D_GLIBCXX_ASSERTIONS" \
    FFLAGS="-g" \
    ./configure --prefix=/opt/heasoft 2>&1 | tee ${HOME}/configure.log

# Keep make in its own layer: it stays cached as long as nothing above changes
RUN cd ${HOME}/heasoft-${HEASOFT_VERSION}/BUILD_DIR/ \
 && echo "Building heasoft..." \
 && make 2>&1 | tee ${HOME}/build.log

RUN cd ${HOME}/heasoft-${HEASOFT_VERSION}/BUILD_DIR/ \
 && echo "Installing heasoft..." \
 && make install 2>&1 | tee ${HOME}/install.log \
 && /bin/bash -c 'cd /opt/heasoft/; for loop in *64*/*; do ln -sf $loop; done' \
 && cd ${HOME}/heasoft-${HEASOFT_VERSION} \
 && cp -p Xspec/BUILD_DIR/hmakerc /opt/heasoft/bin/ \
 && cp -p Xspec/BUILD_DIR/Makefile-std /opt/heasoft/bin/ \
 && cd \
 && gzip -9 ${HOME}/*.log \
 && cp -p ${HOME}/heasoft-${HEASOFT_VERSION}/Release_Notes* /opt/heasoft/ \
 && rm -rf ${HOME}/heasoft-${HEASOFT_VERSION}*

# Configure shells...
RUN /bin/echo >> /home/heasoft/.bashrc \
 && /bin/echo '# Initialize HEASoft environment' >> /home/heasoft/.bashrc \
 && /bin/echo 'export HEADAS=/opt/heasoft' >> /home/heasoft/.bashrc \
 && /bin/echo '. $HEADAS/headas-init.sh' >> /home/heasoft/.bashrc \
 && /bin/echo >> /home/heasoft/.bashrc \
 && /bin/echo '# Initialize environment for CALDB' >> /home/heasoft/.bashrc \
 && /bin/echo 'export CALDB=https://heasarc.gsfc.nasa.gov/FTP/caldb' >> /home/heasoft/.bashrc \
 && /bin/echo 'export CALDBCONFIG=/opt/heasoft/caldb/caldb.config' >> /home/heasoft/.bashrc \
 && /bin/echo 'export CALDBALIAS=/opt/heasoft/caldb/alias_config.fits' >> /home/heasoft/.bashrc \
 && /bin/echo >> /home/heasoft/.profile \
 && /bin/echo '# Initialize HEASoft environment' >> /home/heasoft/.profile \
 && /bin/echo 'export HEADAS=/opt/heasoft' >> /home/heasoft/.profile \
 && /bin/echo '. $HEADAS/headas-init.sh' >> /home/heasoft/.profile \
 && /bin/echo >> /home/heasoft/.profile \
 && /bin/echo '# Initialize environment for CALDB' >> /home/heasoft/.profile \
 && /bin/echo 'export CALDB=https://heasarc.gsfc.nasa.gov/FTP/caldb' >> /home/heasoft/.profile \
 && /bin/echo 'export CALDBCONFIG=/opt/heasoft/caldb/caldb.config' >> /home/heasoft/.profile \
 && /bin/echo 'export CALDBALIAS=/opt/heasoft/caldb/alias_config.fits' >> /home/heasoft/.profile \
 && /bin/echo '# Initialize HEASoft environment' >> /home/heasoft/.cshrc \
 && /bin/echo 'setenv HEADAS /opt/heasoft' >> /home/heasoft/.cshrc \
 && /bin/echo 'source $HEADAS/headas-init.csh' >> /home/heasoft/.cshrc \
 && /bin/echo >> /home/heasoft/.cshrc \
 && /bin/echo '# Initialize environment for CALDB' >> /home/heasoft/.cshrc \
 && /bin/echo 'setenv CALDB https://heasarc.gsfc.nasa.gov/FTP/caldb' >> /home/heasoft/.cshrc \
 && /bin/echo 'setenv CALDBCONFIG /opt/heasoft/caldb/caldb.config' >> /home/heasoft/.cshrc \
 && /bin/echo 'setenv CALDBALIAS /opt/heasoft/caldb/alias_config.fits' >> /home/heasoft/.cshrc

RUN mkdir -p /home/heasoft/pfiles \
 && cd /opt/heasoft/caldb \
 && wget https://heasarc.gsfc.nasa.gov/FTP/caldb/software/tools/caldb.config \
 && wget https://heasarc.gsfc.nasa.gov/FTP/caldb/software/tools/alias_config.fits

ENV CC=/usr/bin/gcc \
    CXX=/usr/bin/g++ \
    FC=/usr/bin/gfortran \
    PERL=/usr/bin/perl \
    PERLLIB=/opt/heasoft/lib/perl \
    PERL5LIB=/opt/heasoft/lib/perl \
    PYTHON=/usr/bin/python \
    PYTHONPATH=/opt/heasoft/lib/python:/opt/heasoft/lib \
    PATH=/opt/heasoft/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HEADAS=/opt/heasoft \
    LHEASOFT=/opt/heasoft \
    FTOOLS=/opt/heasoft \
    LD_LIBRARY_PATH=/opt/heasoft/lib \
    LHEAPERL=/usr/bin/perl \
    PFCLOBBER=1 \
    PFILES="/home/heasoft/pfiles;/opt/heasoft/syspfiles" \
    FTOOLSINPUT=stdin \
    FTOOLSOUTPUT=stdout \
    LHEA_DATA=/opt/heasoft/refdata \
    LHEA_HELP=/opt/heasoft/help \
    EXT=lnx \
    PGPLOT_FONT=/opt/heasoft/lib/grfont.dat \
    PGPLOT_RGB=/opt/heasoft/lib/rgb.txt \
    PGPLOT_DIR=/opt/heasoft/lib \
    POW_LIBRARY=/opt/heasoft/lib/pow \
    XRDEFAULTS=/opt/heasoft/xrdefaults \
    TCLRL_LIBDIR=/opt/heasoft/lib \
    XANADU=/opt/heasoft \
    XANBIN=/opt/heasoft \
    CALDB=https://heasarc.gsfc.nasa.gov/FTP/caldb \
    CALDBCONFIG=/opt/heasoft/caldb/caldb.config \
    CALDBALIAS=/opt/heasoft/caldb/alias_config.fits

# Bug reproduction scripts (placed last so they don't bust the build cache)
USER root
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh \
 && mkdir -p /work \
 && chown -R heasoft:heasoft /scripts /work
USER heasoft

WORKDIR /work
CMD ["/scripts/run_gdb.sh"]
